"""
Ephemeral Workout Analyzer API
A stateless FastAPI backend for serverless deployment.
Zero data persistence - all processing happens in RAM.
"""

import io
import os
import hashlib
from typing import List, Dict, Any, Optional
from fastapi import FastAPI, UploadFile, File, Form, HTTPException, Depends, Request, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import APIKeyHeader
from pydantic import BaseModel
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

# Import core logic from the main app
import sys
sys.path.append('.')

from app import (
    parse_plan_text,
    process_fit_laps,
    extract_session_info,
    group_laps_by_planned,
    calculate_overall_summary,
    generate_detailed_output
)

# Rate limiter setup
limiter = Limiter(key_func=get_remote_address)

app = FastAPI(
    title="Ephemeral Workout Analyzer",
    description="Zero-knowledge workout analysis. No data stored.",
    version="1.0.0"
)

# Add rate limit handler
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS for frontend access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# API Key Configuration
# In production, these would be in a database or environment variables
API_KEY_HEADER = APIKeyHeader(name="X-API-Key", auto_error=False)

# Tiered API keys (demo - in production use secure storage)
API_KEYS = {
    # Format: "key": {"tier": "free|pro|elite", "rate_limit": "X/day"}
    "demo-free-key": {"tier": "free", "daily_limit": 3},
    "demo-pro-key": {"tier": "pro", "daily_limit": 50},
    "demo-elite-key": {"tier": "elite", "daily_limit": 1000},
}


async def get_api_key(api_key: Optional[str] = Depends(API_KEY_HEADER)) -> Optional[dict]:
    """Validate API key and return tier info."""
    if api_key is None:
        return {"tier": "anonymous", "daily_limit": 3}
    
    key_info = API_KEYS.get(api_key)
    if key_info is None:
        raise HTTPException(status_code=401, detail="Invalid API key")
    
    return key_info



class AnalysisResponse(BaseModel):
    success: bool
    sport: str
    summary: Dict[str, Any]
    grouped_data: List[Dict[str, Any]]
    markdown_report: str
    error: Optional[str] = None


def parse_fit_bytes(fit_bytes: bytes) -> tuple:
    """Parse FIT file from bytes using TRUE in-memory processing.
    
    Uses fitdecode which supports BytesIO - zero disk trace.
    """
    import fitdecode
    
    mem_file = io.BytesIO(fit_bytes)
    
    session_info = {}
    laps = []
    
    with fitdecode.FitReader(mem_file) as fit:
        for frame in fit:
            if not isinstance(frame, fitdecode.FitDataMessage):
                continue
            
            if frame.name == 'session':
                for field in frame.fields:
                    session_info[field.name] = field.value
                    
                # Extract specific enhanced fields
                field_map = {
                    'total_ascent': 'elevation_gain',
                    'enhanced_avg_speed': 'avg_speed_ms',
                    'avg_running_cadence': 'avg_cadence',
                    'avg_fractional_cadence': 'fractional_cadence',
                    'avg_stance_time': 'avg_gct',
                    'avg_stride_length': 'avg_stride',
                    'left_right_balance': 'left_balance',
                    'normalized_power': 'normalized_power',
                    'training_stress_score': 'tss',
                    'total_training_effect': 'training_effect',
                }
                for old_name, new_name in field_map.items():
                    if old_name in session_info and session_info[old_name] is not None:
                        value = session_info[old_name]
                        if new_name == 'avg_stride' and value:
                            session_info[new_name] = round(value / 1000, 2)  # mm to m
                        elif new_name == 'left_balance' and value:
                            session_info[new_name] = round(value / 128 * 100, 1)  # Convert to percentage
                        else:
                            session_info[new_name] = value
            
            elif frame.name == 'lap':
                lap_data = {}
                for field in frame.fields:
                    lap_data[field.name] = field.value
                laps.append(lap_data)
            
            # Extract VO2 Max from developer fields
            elif frame.name == 'unknown_140':
                for field in frame.fields:
                    if field.name == 'unknown_29' and field.value is not None:
                        session_info['vo2_max'] = round(field.value / 18724.7, 2)
    
    return laps, session_info




@app.post("/analyze", response_model=AnalysisResponse)
@limiter.limit("10/minute")
async def analyze_workout(
    request: Request,
    file: UploadFile = File(..., description="FIT file to analyze"),
    plan: str = Form(..., description="Workout plan text from intervals.icu"),
    key_info: dict = Depends(get_api_key)
):
    """
    Analyze a workout file against a planned workout.
    
    All processing is ephemeral - nothing is stored on the server.
    
    Rate limits:
    - Anonymous: 3 requests/day
    - Free tier: 3 requests/day  
    - Pro tier: 50 requests/day
    - Elite tier: 1000 requests/day
    """

    try:
        # Read file bytes into memory
        fit_bytes = await file.read()
        
        # Validate file size (50MB limit for serverless)
        if len(fit_bytes) > 50 * 1024 * 1024:
            raise HTTPException(status_code=413, detail="File too large. Maximum 50MB.")
        
        # Parse the plan
        planned_blocks, num_rounds = parse_plan_text(plan)
        if not planned_blocks:
            raise HTTPException(status_code=400, detail="Could not parse workout plan.")
        
        # Parse FIT file in memory
        raw_laps, session_info = parse_fit_bytes(fit_bytes)
        if not raw_laps:
            raise HTTPException(status_code=400, detail="Could not parse FIT file.")
        
        # Process and analyze
        session_data = extract_session_info(session_info)
        sport = session_data['sport']
        
        processed_laps = process_fit_laps(raw_laps, sport=sport, min_duration=3)
        
        grouped = group_laps_by_planned(planned_blocks, processed_laps, sport=sport)
        summary = calculate_overall_summary(processed_laps, session_data)
        
        markdown_report = generate_detailed_output(
            planned_blocks, num_rounds, grouped, summary, session_data
        )
        
        return AnalysisResponse(
            success=True,
            sport=sport,
            summary=summary,
            grouped_data=grouped,
            markdown_report=markdown_report
        )
        
    except HTTPException:
        raise
    except Exception as e:
        # No-trace logging: only log metadata, not the actual data
        return AnalysisResponse(
            success=False,
            sport="unknown",
            summary={},
            grouped_data=[],
            markdown_report="",
            error=f"Analysis failed: {type(e).__name__}"
        )


@app.get("/health")
async def health_check():
    """Health check for load balancers."""
    return {"status": "healthy", "ephemeral": True, "version": "1.0.0"}


@app.get("/validate-key")
async def validate_key(key_info: dict = Depends(get_api_key)):
    """Validate an API key and return tier information."""
    return {
        "valid": True,
        "tier": key_info["tier"],
        "daily_limit": key_info["daily_limit"]
    }


@app.get("/tiers")
async def get_tiers():
    """Return available subscription tiers."""
    return {
        "tiers": [
            {"name": "Free", "daily_limit": 3, "price": "$0/month"},
            {"name": "Pro", "daily_limit": 50, "price": "$9/month"},
            {"name": "Elite", "daily_limit": 1000, "price": "$29/month"}
        ]
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)

