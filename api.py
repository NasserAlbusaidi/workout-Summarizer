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


def parse_form_csv_bytes(csv_bytes: bytes) -> tuple:
    """Parse FORM goggles CSV from bytes.
    
    Returns processed laps and session data ready for use.
    """
    try:
        content = csv_bytes.decode('utf-8')
        lines = content.strip().split('\n')
        
        # Parse header section (first 2 rows)
        session_info = {}
        if len(lines) >= 2:
            header_keys = lines[0].split(',')
            header_values = lines[1].split(',')
            
            for key, value in zip(header_keys, header_values):
                key = key.strip()
                value = value.strip()
                if key and value:
                    session_info[key] = value
            
            session_info['sport'] = 'swimming'
            session_info['activity_name'] = session_info.get('Swim Title') or 'FORM Swim'
            session_info['pool_length'] = int(session_info.get('Pool Size', 25))
            session_info['start_time'] = f"{session_info.get('Swim Date', '')} {session_info.get('Swim Start Time', '')}"
        
        # Parse data section (row 4 onwards)
        lengths = []
        if len(lines) >= 5:
            data_header = lines[3].split(',')
            col_map = {col.strip(): i for i, col in enumerate(data_header)}
            
            for row_idx in range(4, len(lines)):
                row = lines[row_idx].strip()
                if not row:
                    continue
                
                values = row.split(',')
                if len(values) < len(data_header):
                    continue
                
                def get_val(col_name, default=''):
                    idx = col_map.get(col_name)
                    if idx is not None and idx < len(values):
                        return values[idx].strip()
                    return default
                
                def parse_time(time_str):
                    if not time_str or time_str == '0:00.00':
                        return 0.0
                    parts = time_str.split(':')
                    if len(parts) == 2:
                        return float(parts[0]) * 60 + float(parts[1])
                    return 0.0
                
                stroke = get_val('Strk', 'REST')
                is_rest = stroke == 'REST' or get_val('Length (m)', '0') == '0'
                
                lengths.append({
                    'set_number': int(get_val('Set #', '0') or 0),
                    'set_description': get_val('Set', ''),
                    'distance_m': int(get_val('Length (m)', '0') or 0),
                    'stroke_type': stroke,
                    'move_time': parse_time(get_val('Move Time', '0:00.00')),
                    'rest_time': parse_time(get_val('Rest Time', '0:00.00')),
                    'avg_hr': int(get_val('Avg BPM (moving)', '0') or 0) or None,
                    'max_hr': int(get_val('Max BPM', '0') or 0) or None,
                    'swolf': int(get_val('SWOLF', '0') or 0),
                    'stroke_rate': int(get_val('Avg Strk Rate (strk/min)', '0') or 0),
                    'stroke_count': int(get_val('Strk Count', '0') or 0),
                    'dps': float(get_val('Avg DPS', '0') or 0),
                    'calories': int(get_val('Calories', '0') or 0),
                    'is_rest': is_rest,
                })
        
        # Group lengths by set and combine
        processed_laps = []
        current_set = None
        current_laps = []
        pool_length = session_info.get('pool_length', 25)
        
        for length in lengths:
            set_desc = length['set_description']
            if set_desc != current_set and current_laps:
                combined = _combine_form_laps(current_laps, pool_length)
                if combined:
                    processed_laps.append(combined)
                current_laps = []
            current_set = set_desc
            current_laps.append(length)
        
        if current_laps:
            combined = _combine_form_laps(current_laps, pool_length)
            if combined:
                processed_laps.append(combined)
        
        return processed_laps, session_info
    
    except Exception:
        return None, None


def _combine_form_laps(lengths: list, pool_length: int) -> dict:
    """Combine multiple FORM lengths into a single lap."""
    if not lengths:
        return None
    
    active = [l for l in lengths if not l['is_rest']]
    
    total_dist = sum(l['distance_m'] for l in lengths)
    total_move = sum(l['move_time'] for l in lengths)
    total_rest = sum(l['rest_time'] for l in lengths)
    
    hr_vals = [l['avg_hr'] for l in active if l['avg_hr']]
    max_hr_vals = [l['max_hr'] for l in active if l['max_hr']]
    swolf_vals = [l['swolf'] for l in active if l['swolf']]
    
    avg_speed = total_dist / total_move if total_move > 0 else 0
    pace_sec = 100 / avg_speed if avg_speed > 0 else 0
    
    return {
        'lap_number': lengths[0]['set_number'],
        'set_description': lengths[0]['set_description'],
        'duration_seconds': total_move + total_rest,
        'distance_m': total_dist,
        'avg_speed_ms': avg_speed,
        'swim_pace': f"{int(pace_sec // 60)}:{int(pace_sec % 60):02d}" if pace_sec else '--:--',
        'avg_hr': int(sum(hr_vals) / len(hr_vals)) if hr_vals else None,
        'max_hr': max(max_hr_vals) if max_hr_vals else None,
        'swolf': int(sum(swolf_vals) / len(swolf_vals)) if swolf_vals else None,
        'total_strokes': sum(l['stroke_count'] for l in active),
        'swim_stroke': lengths[0].get('stroke_type', 'FR'),
        'num_lengths': len(active),
        'calories': sum(l['calories'] for l in lengths),
        'is_rest': total_dist == 0,
        'source': 'FORM',
    }


@app.post("/analyze", response_model=AnalysisResponse)
@limiter.limit("10/minute")
async def analyze_workout(
    request: Request,
    file: UploadFile = File(..., description="FIT or FORM CSV file to analyze"),
    plan: Optional[str] = Form(None, description="Workout plan text from intervals.icu (optional)"),
    key_info: dict = Depends(get_api_key)
):
    """
    Analyze a workout file, optionally comparing against a planned workout.
    
    Supports:
    - Garmin/Wahoo FIT files
    - FORM goggles CSV exports
    
    All processing is ephemeral - nothing is stored on the server.
    
    Rate limits:
    - Anonymous: 3 requests/day
    - Free tier: 3 requests/day  
    - Pro tier: 50 requests/day
    - Elite tier: 1000 requests/day
    """

    try:
        # Read file bytes into memory
        file_bytes = await file.read()
        file_name = file.filename.lower() if file.filename else ''
        
        # Validate file size (50MB limit for serverless)
        if len(file_bytes) > 50 * 1024 * 1024:
            raise HTTPException(status_code=413, detail="File too large. Maximum 50MB.")
        
        # Detect file type and parse accordingly
        if file_name.endswith('.csv'):
            # FORM goggles CSV
            raw_laps, session_data = parse_form_csv_bytes(file_bytes)
            if not raw_laps:
                raise HTTPException(status_code=400, detail="Could not parse FORM CSV file.")
            sport = 'swimming'
            processed_laps = raw_laps  # Already processed by parse_form_csv_bytes
        else:
            # FIT file
            raw_laps, session_info = parse_fit_bytes(file_bytes)
            if not raw_laps:
                raise HTTPException(status_code=400, detail="Could not parse FIT file.")
            
            session_data = extract_session_info(session_info)
            sport = session_data['sport']
            processed_laps = process_fit_laps(raw_laps, sport=sport, min_duration=3)
        
        summary = calculate_overall_summary(processed_laps, session_data)
        
        # Check if plan was provided and is valid
        has_plan = False
        planned_blocks = []
        num_rounds = 0
        
        if plan and plan.strip():
            planned_blocks, num_rounds = parse_plan_text(plan)
            has_plan = bool(planned_blocks)
        
        if has_plan:
            # Compare against planned workout
            grouped = group_laps_by_planned(planned_blocks, processed_laps, sport=sport)
            markdown_report = generate_detailed_output(
                planned_blocks, num_rounds, grouped, summary, session_data
            )
        else:
            # No plan - just report actual laps
            grouped = []
            for i, lap in enumerate(processed_laps):
                grouped.append({
                    'planned': {
                        'type': 'LAP',
                        'duration_seconds': 0,
                        'target_distance_m': 0,
                        'label': lap.get('set_description') or f"Lap {i+1}"
                    },
                    'combined': lap,
                    'actual_laps': [lap]
                })
            
            # Generate simple lap-based report
            markdown_report = _generate_simple_report(summary, grouped, session_data)
        
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


def _generate_simple_report(summary: Dict, grouped_data: List[Dict], session_data: Dict) -> str:
    """Generate a markdown report for workouts without a plan."""
    output = []
    
    sport = session_data.get('sport', 'unknown').upper()
    activity_name = session_data.get('activity_name', 'Activity')
    emoji = "🏊" if sport.lower() == 'swimming' else ("🚴" if sport.lower() == 'cycling' else "🏃")
    
    output.append(f"# {emoji} {sport}: {activity_name}")
    output.append("")
    
    start_time = session_data.get('start_time')
    if start_time:
        output.append(f"**Date:** {start_time}")
    output.append("")

    # Summary Table
    output.append("## 📊 Summary")
    output.append("| Metric | Value |")
    output.append("|--------|-------|")
    output.append(f"| **Duration** | {summary.get('total_duration', '—')} |")
    output.append(f"| **Distance** | {summary.get('total_distance', '—')} |")
    if summary.get('avg_hr'):
        output.append(f"| **Avg HR** | {summary['avg_hr']} bpm |")
    if summary.get('max_hr'):
        output.append(f"| **Max HR** | {summary['max_hr']} bpm |")
    if summary.get('avg_power'):
        output.append(f"| **Avg Power** | {summary['avg_power']} W |")
    if summary.get('calories'):
        output.append(f"| **Calories** | {summary['calories']} kcal |")
    output.append("")

    # Laps/Sets section
    sport = session_data.get('sport', 'running')
    
    if sport == 'swimming':
        output.append("## 🔄 Sets")
    else:
        output.append("## 🔄 Laps")
    output.append("")
    
    if grouped_data:
        for i, g in enumerate(grouped_data, 1):
            lap = g.get('combined')
            if not lap:
                continue
            
            # Format duration
            dur_sec = lap.get('duration_seconds', 0)
            mins, secs = divmod(int(dur_sec), 60)
            duration = f"{mins}:{secs:02d}"
            
            # Format distance
            dist_m = lap.get('distance_m', 0)
            if dist_m >= 1000:
                distance = f"{dist_m/1000:.2f}km"
            else:
                distance = f"{int(dist_m)}m"
            
            # Build inline format
            parts = []
            
            if sport == 'swimming':
                set_desc = lap.get('set_description') or f"Set {i}"
                pace = lap.get('swim_pace') or '--:--'
                parts.append(f"**{distance}** in {duration}")
                parts.append(f"Pace {pace}/100m")
                
                if lap.get('avg_hr'):
                    parts.append(f"HR {lap['avg_hr']} avg")
                if lap.get('swolf'):
                    parts.append(f"SWOLF {lap['swolf']}")
                if lap.get('total_strokes'):
                    parts.append(f"Strokes {lap['total_strokes']}")
                if lap.get('dps'):
                    parts.append(f"DPS {lap['dps']:.2f}")
                if lap.get('swim_stroke') and lap['swim_stroke'] != 'REST':
                    stroke_name = {'FR': 'Free', 'BR': 'Breast', 'BA': 'Back', 'FL': 'Fly'}.get(lap['swim_stroke'], lap['swim_stroke'])
                    parts.append(f"({stroke_name})")
                
                output.append(f"**{set_desc}:** " + " | ".join(parts) + "  ")
            else:
                pace = lap.get('avg_pace') or '--:--'
                parts.append(f"**{duration}** — {pace}/km")
                if lap.get('avg_hr'):
                    parts.append(f"HR {lap['avg_hr']}")
                if lap.get('cadence'):
                    parts.append(f"Cad {lap['cadence']} spm")
                output.append(f"**Lap {i}:** " + " | ".join(parts) + "  ")
            
            output.append("")
    
    output.append("---")
    output.append("*Report generated without a workout plan - lap data only.*")
            
    return "\n".join(output)



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

