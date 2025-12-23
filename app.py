"""
Interval Matcher (Local Version) v3
A Streamlit app that uses a deterministic regex parser to match 
planned workout intervals with actual workout data from FIT files.

Supports:
- Running workouts (pace, GCT, stride, cadence)
- Cycling workouts (power, cadence, speed)
- Swimming workouts (pace per 100m, strokes, stroke type)
- intervals.icu format for planned workouts
"""

import re
import streamlit as st
import pandas as pd
from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime, timedelta, timezone
from fitparse import FitFile

# Muscat timezone (UTC+4)
MUSCAT_TZ = timezone(timedelta(hours=4))

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

def format_pace(speed_ms: float) -> str:
    """Convert speed (m/s) to pace (min:sec/km) for running."""
    if speed_ms <= 0:
        return "--:--"
    pace_sec_per_km = 1000 / speed_ms
    minutes = int(pace_sec_per_km // 60)
    seconds = int(pace_sec_per_km % 60)
    return f"{minutes}:{seconds:02d}"


def format_swim_pace(speed_ms: float) -> str:
    """Convert speed (m/s) to swim pace (min:sec/100m)."""
    if speed_ms <= 0:
        return "--:--"
    pace_sec_per_100m = 100 / speed_ms
    minutes = int(pace_sec_per_100m // 60)
    seconds = int(pace_sec_per_100m % 60)
    return f"{minutes}:{seconds:02d}"


def format_speed(speed_ms: float) -> str:
    """Convert speed (m/s) to km/h for cycling."""
    if speed_ms <= 0:
        return "--.-"
    return f"{speed_ms * 3.6:.1f}"


def format_duration(seconds: int) -> str:
    """Format duration in seconds to M:SS or H:MM:SS."""
    if seconds < 0:
        seconds = 0
    if seconds < 3600:
        return f"{seconds // 60}:{seconds % 60:02d}"
    else:
        hours = seconds // 3600
        mins = (seconds % 3600) // 60
        secs = seconds % 60
        return f"{hours}:{mins:02d}:{secs:02d}"


def convert_to_local_time(dt, tz=MUSCAT_TZ) -> datetime:
    """Convert FIT file UTC time to local timezone."""
    if dt is None:
        return None
    if isinstance(dt, datetime):
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(tz)
    return dt


def parse_pace_to_speed(pace_str: str) -> float:
    """Convert pace string (e.g., "5:41" min/km) to speed in m/s."""
    try:
        parts = pace_str.strip().split(':')
        if len(parts) == 2:
            minutes, seconds = int(parts[0]), int(parts[1])
            total_seconds = minutes * 60 + seconds
            if total_seconds > 0:
                return 1000 / total_seconds
    except:
        pass
    return 0


def parse_swim_pace_to_speed(pace_str: str) -> float:
    """Convert swim pace string (e.g., "2:40" min/100m) to speed in m/s."""
    try:
        parts = pace_str.strip().split(':')
        if len(parts) == 2:
            minutes, seconds = int(parts[0]), int(parts[1])
            total_seconds = minutes * 60 + seconds
            if total_seconds > 0:
                return 100 / total_seconds
    except:
        pass
    return 0


# =============================================================================
# REGEX PARSER FOR INTERVALS.ICU FORMAT
# =============================================================================

def parse_duration_text(duration_str: str) -> int:
    """Parse duration string to seconds. Supports: MM:SS, Xm, Xs"""
    match = re.match(r'(\d+):(\d+)', duration_str)
    if match:
        return int(match.group(1)) * 60 + int(match.group(2))
    match = re.match(r'(\d+)\s*m', duration_str, re.IGNORECASE)
    if match:
        return int(match.group(1)) * 60
    match = re.match(r'(\d+)\s*s', duration_str, re.IGNORECASE)
    if match:
        return int(match.group(1))
    return 0


def get_interval_type(text: str) -> str:
    """Extract interval type from text based on keywords."""
    text_lower = text.lower()
    # Rest/Recovery
    if any(kw in text_lower for kw in ['rest', 'recovery', 'easy', 'off', 'active']):
        return 'RECOVERY'
    # Warmup
    if any(kw in text_lower for kw in ['warmup', 'warm up', 'warm-up', 'warm down']):
        return 'WARMUP'
    # Cooldown
    if any(kw in text_lower for kw in ['cooldown', 'cool down', 'cool-down', 'cool']):
        return 'COOL'
    # Work
    if any(kw in text_lower for kw in ['work', 'hard', 'harder', 'on', 'interval', 'main set']):
        return 'WORK'
    return 'WORK'


def get_swim_stroke(text: str) -> Optional[str]:
    """Extract swim stroke type from text."""
    text_lower = text.lower()
    stroke_map = {
        'fs': 'Freestyle',
        'freestyle': 'Freestyle',
        'free': 'Freestyle',
        'back': 'Backstroke',
        'backstroke': 'Backstroke',
        'breast': 'Breaststroke',
        'breaststroke': 'Breaststroke',
        'fly': 'Butterfly',
        'butterfly': 'Butterfly',
        'im': 'IM',
        'pull': 'Pull',
        'kick': 'Kick',
        'drill': 'Drill',
        'choice': 'Choice',
    }
    for key, stroke in stroke_map.items():
        if key in text_lower:
            return stroke
    return None


def parse_intervals_icu_line(line: str) -> Optional[Dict[str, Any]]:
    """Parse a single line from intervals.icu format."""
    line = line.strip()
    if not line:
        return None
    
    # Remove labels like "Warm Up:", "Main Set:", "Warm Down:"
    line = re.sub(r'^(Warm Up|Main Set|Warm Down|Cool Down):\s*', '', line, flags=re.IGNORECASE)
    
    if not line:
        return None
    
    interval_type = get_interval_type(line)
    swim_stroke = get_swim_stroke(line)
    
    # Extract distance for swim (e.g., "0.1km" or "0.05km" or "100m")
    target_distance = None
    dist_match = re.search(r'([\d.]+)\s*km(?:\s|$)', line, re.IGNORECASE)
    if dist_match:
        target_distance = float(dist_match.group(1)) * 1000  # Convert to meters
    else:
        dist_match = re.search(r'(\d+)\s*m(?:\s|$)', line, re.IGNORECASE)
        if dist_match:
            target_distance = float(dist_match.group(1))
    
    # Extract duration - priority: Xm (minutes), Xs (seconds), then MM:SS (but not pace in parens)
    duration_seconds = 0
    
    # First check for minutes format (e.g., "5m", "8m") - most explicit
    min_match = re.search(r'(?:^|\s)(\d+)m(?:\s|$)', line, re.IGNORECASE)
    if min_match:
        duration_seconds = int(min_match.group(1)) * 60
    else:
        # Check for seconds format (e.g., "15s", "20s")
        sec_match = re.search(r'(?:^|\s)(\d+)s(?:\s|$)', line, re.IGNORECASE)
        if sec_match:
            duration_seconds = int(sec_match.group(1))
        else:
            # Check for MM:SS duration but NOT inside parentheses (those are pace values)
            # Only match MM:SS at the start or after space, not after ( or -
            time_match = re.search(r'(?:^|\s)(\d+:\d+)(?:\s|$)', line)
            if time_match:
                # Make sure it's not a pace value (check if followed by /km or inside parens)
                match_start = time_match.start()
                if '(' not in line[:match_start] or ')' in line[:match_start]:
                    duration_seconds = parse_duration_text(time_match.group(1))
    
    # Extract pace range for running (e.g., "6:01-6:41") 
    pace_range = None
    target_pace_min_ms = None
    target_pace_max_ms = None
    
    # For swim pace (per 100m), look for pattern like "(2:47-3:03)"
    swim_pace_match = re.search(r'Pace\s*\((\d+:\d+)-(\d+:\d+)\)', line, re.IGNORECASE)
    if swim_pace_match:
        pace_range = f"{swim_pace_match.group(1)}–{swim_pace_match.group(2)}"
        target_pace_min_ms = parse_swim_pace_to_speed(swim_pace_match.group(2))
        target_pace_max_ms = parse_swim_pace_to_speed(swim_pace_match.group(1))
    else:
        # Running pace
        pace_match = re.search(r'\((\d+:\d+)-(\d+:\d+)\)', line)
        if pace_match:
            pace_range = f"{pace_match.group(1)}–{pace_match.group(2)}"
            target_pace_min_ms = parse_pace_to_speed(pace_match.group(2))
            target_pace_max_ms = parse_pace_to_speed(pace_match.group(1))
    
    # Extract power range for cycling (e.g., "115-172w")
    power_range = None
    target_power_min = None
    target_power_max = None
    power_match = re.search(r'\((\d+)-(\d+)\s*w\)', line, re.IGNORECASE)
    if power_match:
        target_power_min = int(power_match.group(1))
        target_power_max = int(power_match.group(2))
        power_range = f"{target_power_min}–{target_power_max}W"
    
    # Extract intensity % (e.g., "80-89%")
    intensity_range = None
    intensity_match = re.search(r'(\d+)-(\d+)%', line)
    if intensity_match:
        intensity_range = f"{intensity_match.group(1)}–{intensity_match.group(2)}%"
    
    return {
        'type': interval_type,
        'duration_seconds': duration_seconds,
        'target_distance_m': target_distance,
        'swim_stroke': swim_stroke,
        'pace_range': pace_range,
        'target_pace_min_ms': target_pace_min_ms,
        'target_pace_max_ms': target_pace_max_ms,
        'power_range': power_range,
        'target_power_min': target_power_min,
        'target_power_max': target_power_max,
        'intensity_range': intensity_range,
        'raw_text': line
    }


def parse_plan_text(text: str) -> Tuple[List[Dict[str, Any]], int]:
    """Parse the entire plan text into a list of planned blocks.
    
    Handles intervals.icu format with blank lines between sets.
    """
    planned_blocks = []
    # Remove excessive blank lines but preserve structure
    lines = text.strip().split('\n')
    num_rounds = 0
    
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        
        # Skip empty lines and comments
        if not line or line.startswith('#'):
            i += 1
            continue
        
        # Check for standalone multiplier (e.g., "4x" or "1x" or "2x")
        standalone_mult = re.match(r'^(\d+)\s*[xX]\s*$', line)
        if standalone_mult:
            repetitions = int(standalone_mult.group(1))
            if repetitions > 1:
                num_rounds = max(num_rounds, repetitions)
            i += 1
            
            # Skip any blank lines after the multiplier
            while i < len(lines) and not lines[i].strip():
                i += 1
            
            # Collect following lines until next multiplier or section header
            sub_intervals = []
            while i < len(lines):
                next_line = lines[i].strip()
                
                # Skip blank lines within the set
                if not next_line:
                    i += 1
                    continue
                
                # Stop at another multiplier (new set)
                if re.match(r'^\d+\s*[xX]\s*$', next_line):
                    break
                # Stop at new warmup (like "Warm up 2") or Cool Down
                if re.match(r'^(Warm up \d|Cool Down)', next_line, re.IGNORECASE):
                    break
                
                interval = parse_intervals_icu_line(next_line)
                if interval and (interval['duration_seconds'] > 0 or interval.get('target_distance_m')):
                    interval['is_main_set'] = True
                    sub_intervals.append(interval)
                i += 1
            
            # Expand the repetitions
            for round_num in range(repetitions):
                for interval in sub_intervals:
                    new_interval = interval.copy()
                    new_interval['round_number'] = round_num + 1 if repetitions > 1 else None
                    planned_blocks.append(new_interval)
            continue
        
        # Check for inline multiplier (e.g., "4x Work 8:00")
        inline_mult = re.match(r'^(\d+)\s*[xX]\s+(.+)', line)
        if inline_mult:
            repetitions = int(inline_mult.group(1))
            if repetitions > 1:
                num_rounds = max(num_rounds, repetitions)
            rest_of_line = inline_mult.group(2)
            
            parts = re.split(r',\s*(?=[A-Za-z])', rest_of_line)
            sub_intervals = []
            for part in parts:
                interval = parse_intervals_icu_line(part)
                if interval and (interval['duration_seconds'] > 0 or interval.get('target_distance_m')):
                    interval['is_main_set'] = True
                    sub_intervals.append(interval)
            
            for round_num in range(repetitions):
                for interval in sub_intervals:
                    new_interval = interval.copy()
                    new_interval['round_number'] = round_num + 1 if repetitions > 1 else None
                    planned_blocks.append(new_interval)
            i += 1
            continue
        
        # Regular line (warmup, cooldown, or standalone interval)
        interval = parse_intervals_icu_line(line)
        if interval and (interval['duration_seconds'] > 0 or interval.get('target_distance_m')):
            interval['is_main_set'] = False
            planned_blocks.append(interval)
        
        i += 1
    
    return planned_blocks, num_rounds


# =============================================================================
# FIT FILE PARSER
# =============================================================================

def load_fit_file(uploaded_file) -> Tuple[Optional[pd.DataFrame], Optional[List[Dict]], Optional[Dict]]:
    """Load and parse a FIT file using TRUE in-memory processing (no disk writes).
    
    Uses fitdecode which supports file-like objects (BytesIO).
    This is the core of the Ephemeral Pipeline - zero disk trace.
    """
    try:
        import io
        import fitdecode
        
        fit_bytes = uploaded_file.read()
        uploaded_file.seek(0)
        
        # True in-memory processing with fitdecode
        mem_file = io.BytesIO(fit_bytes)
        
        session_info = {}
        records = []
        laps = []
        
        with fitdecode.FitReader(mem_file) as fit:
            for frame in fit:
                if not isinstance(frame, fitdecode.FitDataMessage):
                    continue
                
                # Session data
                if frame.name == 'session':
                    for field in frame.fields:
                        session_info[field.name] = field.value
                
                # Record data (for time series)
                elif frame.name == 'record':
                    record_data = {}
                    for field in frame.fields:
                        record_data[field.name] = field.value
                    records.append(record_data)
                
                # Lap data
                elif frame.name == 'lap':
                    lap_data = {}
                    for field in frame.fields:
                        lap_data[field.name] = field.value
                    laps.append(lap_data)
                
                # VO2 max from unknown message type 140
                elif frame.name == 'unknown_140':
                    for field in frame.fields:
                        if field.name == 'unknown_29' and field.value is not None:
                            session_info['vo2_max'] = round(field.value / 18724.7, 2)
        
        df = pd.DataFrame(records) if records else None
        
        return df, laps, session_info
    
    except Exception as e:
        st.error(f"Error parsing FIT file: {str(e)}")
        return None, None, None




def process_fit_laps(laps: List[Dict], sport: str = 'running', min_duration: int = 5) -> List[Dict[str, Any]]:
    """Process raw FIT lap data with sport-specific metrics."""
    processed_laps = []
    
    for i, lap in enumerate(laps):
        total_elapsed_time = lap.get('total_elapsed_time', 0)
        
        # For swimming, include rest laps (distance=0) but skip very short laps
        if sport != 'swimming' and total_elapsed_time < min_duration:
            continue
        if sport == 'swimming' and total_elapsed_time < 3:
            continue
        
        # Basic metrics
        total_distance = lap.get('total_distance', 0)
        avg_speed = lap.get('enhanced_avg_speed') or lap.get('avg_speed', 0)
        max_speed = lap.get('enhanced_max_speed') or lap.get('max_speed', 0)
        
        # Heart rate
        avg_hr = lap.get('avg_heart_rate')
        max_hr = lap.get('max_heart_rate')
        
        # Power (cycling)
        avg_power = lap.get('avg_power')
        max_power = lap.get('max_power')
        normalized_power = lap.get('normalized_power')
        
        # Cadence
        if sport == 'cycling':
            avg_cadence = lap.get('avg_cadence')
            max_cadence = lap.get('max_cadence')
        elif sport == 'swimming':
            avg_cadence = lap.get('avg_cadence')  # Strokes per minute
            max_cadence = None
        else:
            avg_cadence = lap.get('avg_running_cadence') or lap.get('avg_cadence')
            max_cadence = lap.get('max_running_cadence') or lap.get('max_cadence')
        
        # Swim-specific
        swim_stroke = lap.get('swim_stroke')
        total_strokes = lap.get('total_cycles')
        num_lengths = lap.get('num_active_lengths') or lap.get('num_lengths', 0)
        
        # Running-specific
        gct = lap.get('avg_stance_time')
        stride_length = lap.get('avg_step_length')
        
        # Cycling-specific: L/R balance
        lr_balance = lap.get('left_right_balance')
        left_balance = None
        if lr_balance and sport == 'cycling':
            # FIT encodes balance as: (left% * 100) | 0x8000 if right data available
            if isinstance(lr_balance, int):
                left_balance = round((lr_balance & 0x7FFF) / 100, 1)
        
        # Temperature & elevation
        avg_temp = lap.get('avg_temperature')
        total_ascent = lap.get('total_ascent', 0)
        total_descent = lap.get('total_descent', 0)
        
        # Time
        start_time = convert_to_local_time(lap.get('start_time'))
        
        # Calculate SWOLF for swimming
        swolf = None
        if sport == 'swimming' and num_lengths == 1 and total_strokes:
            swolf = int(total_elapsed_time) + total_strokes
        
        processed_lap = {
            'lap_number': len(processed_laps) + 1,
            'original_lap_number': i + 1,
            'start_time': start_time,
            'sport': sport,
            'duration_seconds': total_elapsed_time,
            'distance_m': total_distance,
            'avg_speed_ms': avg_speed,
            'max_speed_ms': max_speed,
            'avg_pace': format_pace(avg_speed),
            'swim_pace': format_swim_pace(avg_speed),
            'avg_speed_kmh': format_speed(avg_speed),
            'avg_hr': avg_hr,
            'max_hr': max_hr,
            'avg_power': int(avg_power) if avg_power else None,
            'max_power': int(max_power) if max_power else None,
            'normalized_power': int(normalized_power) if normalized_power else None,
            'cadence': int(avg_cadence * 2) if avg_cadence and sport == 'running' else (int(avg_cadence) if avg_cadence else None),
            'max_cadence': int(max_cadence * 2) if max_cadence and sport == 'running' else (int(max_cadence) if max_cadence else None),
            'swim_stroke': swim_stroke,
            'total_strokes': total_strokes,
            'num_lengths': num_lengths,
            'swolf': swolf,
            'gct': int(gct) if gct else None,
            'stride_length': round(stride_length / 10, 1) if stride_length else None,
            'temperature': int(avg_temp) if avg_temp else None,
            'total_ascent': total_ascent or 0,
            'total_descent': total_descent or 0,
            'left_balance': left_balance,
            'is_rest': total_distance == 0 or (sport == 'swimming' and num_lengths == 0),
        }
        
        processed_laps.append(processed_lap)
    
    return processed_laps


# =============================================================================
# FORM GOGGLES CSV PARSER
# =============================================================================

def parse_form_time(time_str: str) -> float:
    """Parse FORM time format (M:SS.xx or H:MM:SS.xx) to seconds."""
    if not time_str or time_str == '0:00.00':
        return 0.0
    try:
        parts = time_str.split(':')
        if len(parts) == 2:
            mins, secs = parts
            return float(mins) * 60 + float(secs)
        elif len(parts) == 3:
            hours, mins, secs = parts
            return float(hours) * 3600 + float(mins) * 60 + float(secs)
        return 0.0
    except:
        return 0.0


def parse_form_pace(pace_str: str) -> str:
    """Parse FORM pace format (M:SS.xx) to standard format (M:SS)."""
    if not pace_str or pace_str == '0:00.00':
        return '--:--'
    try:
        parts = pace_str.split(':')
        if len(parts) == 2:
            mins = int(parts[0])
            secs = int(float(parts[1]))
            return f"{mins}:{secs:02d}"
        return pace_str
    except:
        return '--:--'


def load_form_csv(uploaded_file) -> Tuple[Optional[List[Dict]], Optional[Dict]]:
    """Load and parse a FORM goggles CSV file.
    
    Returns:
        - List of length/lap data
        - Session info dictionary
    """
    try:
        import csv
        import io
        
        # Read file content
        content = uploaded_file.read()
        if isinstance(content, bytes):
            content = content.decode('utf-8')
        uploaded_file.seek(0)
        
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
            
            # Extract common session fields
            session_info['sport'] = 'swimming'
            session_info['activity_name'] = session_info.get('Swim Title') or 'FORM Swim'
            session_info['pool_length'] = int(session_info.get('Pool Size', 25))
            session_info['start_time'] = f"{session_info.get('Swim Date', '')} {session_info.get('Swim Start Time', '')}"
        
        # Parse data section (row 4 onwards, row 3 is header)
        lengths = []
        if len(lines) >= 5:
            # Row 4 (index 3) is the data header
            data_header = lines[3].split(',')
            
            # Get column indices
            col_map = {}
            for i, col in enumerate(data_header):
                col_map[col.strip()] = i
            
            # Parse each data row
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
                
                # Parse the length data
                stroke = get_val('Strk', 'REST')
                is_rest = stroke == 'REST' or get_val('Length (m)', '0') == '0'
                
                length_data = {
                    'set_number': int(get_val('Set #', '0') or 0),
                    'set_description': get_val('Set', ''),
                    'interval_m': int(get_val('Interval (m)', '0') or 0),
                    'distance_m': int(get_val('Length (m)', '0') or 0),
                    'stroke_type': stroke,
                    'move_time': parse_form_time(get_val('Move Time', '0:00.00')),
                    'rest_time': parse_form_time(get_val('Rest Time', '0:00.00')),
                    'cumul_time': parse_form_time(get_val('Cumul Time', '0:00.00')),
                    'cumul_dist': int(get_val('Cumul Dist (m)', '0') or 0),
                    'dps': float(get_val('Avg DPS', '0') or 0),
                    'avg_hr': int(get_val('Avg BPM (moving)', '0') or 0) or None,
                    'max_hr': int(get_val('Max BPM', '0') or 0) or None,
                    'min_hr_rest': int(get_val('Min BPM (resting)', '0') or 0) or None,
                    'pace_100': parse_form_pace(get_val('Pace/100', '0:00.00')),
                    'pace_50': parse_form_pace(get_val('Pace/50', '0:00.00')),
                    'swolf': int(get_val('SWOLF', '0') or 0),
                    'stroke_rate': int(get_val('Avg Strk Rate (strk/min)', '0') or 0),
                    'stroke_count': int(get_val('Strk Count', '0') or 0),
                    'calories': int(get_val('Calories', '0') or 0),
                    'is_rest': is_rest,
                }
                
                lengths.append(length_data)
        
        return lengths, session_info
    
    except Exception as e:
        st.error(f"Error parsing FORM CSV: {str(e)}")
        return None, None


def process_form_lengths(lengths: List[Dict], session_info: Dict) -> List[Dict[str, Any]]:
    """Convert FORM length data to our standard lap format.
    
    Groups consecutive lengths with the same set description into combined laps.
    """
    if not lengths:
        return []
    
    processed_laps = []
    pool_length = session_info.get('pool_length', 25)
    
    # Group lengths by set
    current_set = None
    current_laps = []
    
    for length in lengths:
        set_desc = length['set_description']
        
        if set_desc != current_set and current_laps:
            # Combine previous set's laps
            combined = _combine_form_lengths(current_laps, pool_length)
            if combined:
                processed_laps.append(combined)
            current_laps = []
        
        current_set = set_desc
        current_laps.append(length)
    
    # Don't forget last set
    if current_laps:
        combined = _combine_form_lengths(current_laps, pool_length)
        if combined:
            processed_laps.append(combined)
    
    return processed_laps


def _combine_form_lengths(lengths: List[Dict], pool_length: int) -> Optional[Dict]:
    """Combine multiple lengths into a single lap/interval."""
    if not lengths:
        return None
    
    # Filter out pure rest entries for calculations
    active_lengths = [l for l in lengths if not l['is_rest']]
    
    total_distance = sum(l['distance_m'] for l in lengths)
    total_move_time = sum(l['move_time'] for l in lengths)
    total_rest_time = sum(l['rest_time'] for l in lengths)
    total_time = total_move_time + total_rest_time
    
    # Averages from active lengths only
    hr_values = [l['avg_hr'] for l in active_lengths if l['avg_hr']]
    max_hr_values = [l['max_hr'] for l in active_lengths if l['max_hr']]
    swolf_values = [l['swolf'] for l in active_lengths if l['swolf']]
    dps_values = [l['dps'] for l in active_lengths if l['dps']]
    stroke_rate_values = [l['stroke_rate'] for l in active_lengths if l['stroke_rate']]
    
    avg_hr = int(sum(hr_values) / len(hr_values)) if hr_values else None
    max_hr = max(max_hr_values) if max_hr_values else None
    avg_swolf = int(sum(swolf_values) / len(swolf_values)) if swolf_values else None
    avg_dps = round(sum(dps_values) / len(dps_values), 2) if dps_values else None
    avg_stroke_rate = int(sum(stroke_rate_values) / len(stroke_rate_values)) if stroke_rate_values else None
    
    total_strokes = sum(l['stroke_count'] for l in active_lengths)
    total_calories = sum(l['calories'] for l in lengths)
    
    # Calculate pace
    avg_speed = total_distance / total_move_time if total_move_time > 0 else 0
    swim_pace = format_swim_pace(avg_speed)
    
    # Get set info from first length
    first = lengths[0]
    
    return {
        'lap_number': first['set_number'],
        'set_description': first['set_description'],
        'duration_seconds': total_time,
        'move_time': total_move_time,
        'rest_time': total_rest_time,
        'distance_m': total_distance,
        'avg_speed_ms': avg_speed,
        'avg_pace': None,
        'swim_pace': swim_pace,
        'avg_hr': avg_hr,
        'max_hr': max_hr,
        'swolf': avg_swolf,
        'dps': avg_dps,
        'stroke_rate': avg_stroke_rate,
        'total_strokes': total_strokes,
        'swim_stroke': first.get('stroke_type', 'FR'),
        'num_lengths': len(active_lengths),
        'calories': total_calories,
        'is_rest': total_distance == 0,
        'source': 'FORM',
    }



def extract_session_info(session: Dict) -> Dict[str, Any]:
    """Extract relevant session-level information."""
    activity_name = session.get('unknown_110') or session.get('sport', 'Activity')
    sport = str(session.get('sport', 'unknown')).lower()
    start_time = convert_to_local_time(session.get('start_time'))
    
    # Decode L/R balance
    lr_balance_raw = session.get('left_right_balance')
    left_balance = None
    if lr_balance_raw and isinstance(lr_balance_raw, int):
        left_balance = round((lr_balance_raw & 0x7FFF) / 100, 1)
    
    return {
        'activity_name': str(activity_name).title() if activity_name else 'Activity',
        'sport': sport,
        'start_time': start_time,
        'pool_length': session.get('pool_length'),
        'total_distance': session.get('total_distance'),
        'total_time': session.get('total_elapsed_time'),
        'avg_hr': session.get('avg_heart_rate'),
        'max_hr': session.get('max_heart_rate'),
        'avg_cadence': session.get('avg_running_cadence') or session.get('avg_cadence'),
        'avg_gct': session.get('avg_stance_time'),
        'avg_stride': session.get('avg_step_length'),
        'avg_power': session.get('avg_power'),
        'normalized_power': session.get('normalized_power'),
        'threshold_power': session.get('threshold_power'),
        'intensity_factor': session.get('intensity_factor'),
        'tss': session.get('training_stress_score'),
        'avg_temp': session.get('avg_temperature'),
        'total_ascent': session.get('total_ascent'),
        'total_descent': session.get('total_descent'),
        'total_calories': session.get('total_calories'),
        'training_effect': session.get('total_training_effect'),
        'num_active_lengths': session.get('num_active_lengths'),
        'left_balance': left_balance,
        'vo2_max': session.get('vo2_max'),
    }


# =============================================================================
# LAP GROUPING & COMPARISON
# =============================================================================

def group_laps_by_planned(planned_blocks: List[Dict], actual_laps: List[Dict], sport: str = 'running') -> List[Dict]:
    """Group actual laps to match planned intervals."""
    grouped = []
    lap_index = 0
    
    for planned in planned_blocks:
        planned_duration = planned.get('duration_seconds', 0)
        planned_distance = planned.get('target_distance_m', 0)
        
        combined_laps = []
        accumulated_duration = 0
        accumulated_distance = 0
        
        # For swimming, match by distance; for others by duration
        if sport == 'swimming' and planned_distance:
            tolerance = 15  # meters
            while lap_index < len(actual_laps):
                lap = actual_laps[lap_index]
                
                if accumulated_distance > 0 and accumulated_distance >= planned_distance - tolerance:
                    break
                
                combined_laps.append(lap)
                accumulated_distance += lap['distance_m']
                accumulated_duration += lap['duration_seconds']
                lap_index += 1
                
                if accumulated_distance >= planned_distance - tolerance:
                    break
        elif planned_duration:
            tolerance = max(10, planned_duration * 0.15)
            while lap_index < len(actual_laps):
                lap = actual_laps[lap_index]
                
                if accumulated_duration > 0 and accumulated_duration >= planned_duration - tolerance:
                    break
                
                combined_laps.append(lap)
                accumulated_duration += lap['duration_seconds']
                lap_index += 1
                
                if accumulated_duration >= planned_duration - tolerance:
                    break
        else:
            # Fallback: take one lap
            if lap_index < len(actual_laps):
                combined_laps.append(actual_laps[lap_index])
                lap_index += 1
        
        if combined_laps:
            total_duration = sum(l['duration_seconds'] for l in combined_laps)
            total_distance = sum(l['distance_m'] for l in combined_laps)
            avg_speed = total_distance / total_duration if total_duration > 0 else 0
            
            hr_values = [l['avg_hr'] for l in combined_laps if l.get('avg_hr')]
            cadence_values = [l['cadence'] for l in combined_laps if l.get('cadence')]
            power_values = [l['avg_power'] for l in combined_laps if l.get('avg_power')]
            strokes = sum(l.get('total_strokes', 0) or 0 for l in combined_laps)
            
            grouped.append({
                'planned': planned,
                'actual_laps': combined_laps,
                'combined': {
                    'sport': sport,
                    'duration_seconds': total_duration,
                    'distance_m': total_distance,
                    'avg_speed_ms': avg_speed,
                    'avg_pace': format_pace(avg_speed),
                    'swim_pace': format_swim_pace(avg_speed),
                    'avg_speed_kmh': format_speed(avg_speed),
                    'start_hr': combined_laps[0].get('avg_hr'),
                    'end_hr': combined_laps[-1].get('max_hr'),
                    'avg_hr': sum(hr_values) / len(hr_values) if hr_values else None,
                    'max_hr': max(l.get('max_hr', 0) or 0 for l in combined_laps),
                    'cadence': int(sum(cadence_values) / len(cadence_values)) if cadence_values else None,
                    'avg_power': int(sum(power_values) / len(power_values)) if power_values else None,
                    'total_strokes': strokes,
                    'swim_stroke': combined_laps[0].get('swim_stroke'),
                    'is_rest': all(l.get('is_rest') for l in combined_laps),
                    'num_laps_combined': len(combined_laps)
                }
            })
        else:
            grouped.append({'planned': planned, 'actual_laps': [], 'combined': None})
    
    return grouped


def calculate_overall_summary(actual_laps: List[Dict], session_info: Dict) -> Dict[str, Any]:
    """Calculate overall workout summary."""
    if not actual_laps:
        return {}
    
    sport = session_info.get('sport', 'running')
    is_swimming = sport == 'swimming'
    
    # Exclude rest laps from totals for swimming
    active_laps = [l for l in actual_laps if not l.get('is_rest')] if is_swimming else actual_laps
    
    total_duration = sum(lap['duration_seconds'] for lap in actual_laps)
    total_distance = sum(lap['distance_m'] for lap in active_laps)
    active_time = sum(lap['duration_seconds'] for lap in active_laps)
    
    hr_values = [lap['avg_hr'] for lap in active_laps if lap.get('avg_hr')]
    max_hr_values = [lap['max_hr'] for lap in active_laps if lap.get('max_hr')]
    cadence_values = [lap['cadence'] for lap in active_laps if lap.get('cadence')]
    power_values = [lap['avg_power'] for lap in active_laps if lap.get('avg_power')]
    
    overall_pace = format_pace(total_distance / active_time) if active_time > 0 else "--:--"
    overall_swim_pace = format_swim_pace(total_distance / active_time) if active_time > 0 else "--:--"
    overall_speed = format_speed(total_distance / active_time) if active_time > 0 else "--.-"
    
    total_strokes = sum(l.get('total_strokes', 0) or 0 for l in active_laps)
    
    return {
        'sport': sport,
        'activity_name': session_info.get('activity_name', 'Activity'),
        'start_time': session_info.get('start_time'),
        'pool_length': session_info.get('pool_length'),
        'total_duration': format_duration(int(total_duration)),
        'active_time': format_duration(int(active_time)),
        'total_distance': f"{total_distance/1000:.2f} km" if total_distance >= 1000 else f"{int(total_distance)}m",
        'overall_pace': overall_pace,
        'overall_swim_pace': overall_swim_pace,
        'overall_speed': overall_speed,
        'avg_hr': int(sum(hr_values)/len(hr_values)) if hr_values else None,
        'max_hr': int(max(max_hr_values)) if max_hr_values else None,
        'avg_cadence': int(sum(cadence_values)/len(cadence_values)) if cadence_values else None,
        'avg_power': int(sum(power_values)/len(power_values)) if power_values else None,
        'normalized_power': session_info.get('normalized_power'),
        'intensity_factor': session_info.get('intensity_factor'),
        'tss': session_info.get('tss'),
        'avg_temp': session_info.get('avg_temp'),
        'total_ascent': session_info.get('total_ascent'),
        'total_descent': session_info.get('total_descent'),
        'calories': session_info.get('total_calories'),
        'training_effect': session_info.get('training_effect'),
        'total_laps': len(actual_laps),
        'active_laps': len(active_laps),
        'total_strokes': total_strokes,
        'num_lengths': session_info.get('num_active_lengths'),
        'left_balance': session_info.get('left_balance'),
        'vo2_max': session_info.get('vo2_max'),
    }


# =============================================================================
# FORMATTED OUTPUT GENERATION
# =============================================================================

def generate_detailed_output(
    planned_blocks: List[Dict], 
    num_rounds: int,
    grouped_data: List[Dict],
    summary: Dict,
    session_info: Dict
) -> str:
    """Generate the detailed formatted output."""
    output = []
    sport = summary.get('sport', 'running')
    is_cycling = sport == 'cycling'
    is_swimming = sport == 'swimming'
    
    # Emoji based on sport
    emoji = "🏊" if is_swimming else ("🚴" if is_cycling else "🏃")
    
    # Header
    activity_name = summary.get('activity_name', 'Activity')
    start_time = summary.get('start_time')
    temp = summary.get('avg_temp')
    pool_length = summary.get('pool_length')
    
    output.append(f"# {emoji} {activity_name} Workout Analysis")
    if start_time and isinstance(start_time, datetime):
        output.append(f"**Date:** {start_time.strftime('%A, %B %d, %Y')}")
        output.append(f"**Time:** {start_time.strftime('%H:%M')} (Local)")
    if pool_length:
        output.append(f"**Pool:** {int(pool_length)}m")
    if temp:
        output.append(f"**Temperature:** {temp}°C")
    output.append("")
    
    # Planned section
    output.append("---")
    output.append("## 📋 PLANNED WORKOUT\n")
    
    warmup_planned = [p for p in planned_blocks if p['type'] == 'WARMUP']
    cooldown_planned = [p for p in planned_blocks if p['type'] == 'COOL']
    main_set_planned = [p for p in planned_blocks if p.get('is_main_set', False)]
    
    if warmup_planned:
        output.append("### Warm-Up")
        for p in warmup_planned:
            output.append(format_planned_interval(p, sport))
        output.append("")
    
    if main_set_planned:
        if num_rounds > 1:
            output.append(f"### Main Set — {num_rounds} Rounds")
            intervals_per_round = len(main_set_planned) // num_rounds
            for i in range(intervals_per_round):
                output.append(format_planned_interval(main_set_planned[i], sport))
        else:
            output.append("### Main Set")
            for p in main_set_planned:
                output.append(format_planned_interval(p, sport))
        output.append("")
    
    if cooldown_planned:
        output.append("### Cool Down")
        for p in cooldown_planned:
            output.append(format_planned_interval(p, sport))
        output.append("")
    
    # Actual section
    output.append("---")
    output.append(f"## {emoji} ACTUAL WORKOUT\n")
    
    warmup_data = [g for g in grouped_data if g['planned']['type'] == 'WARMUP']
    if warmup_data:
        output.append("### Warm-Up (Actual)")
        for i, g in enumerate(warmup_data, 1):
            if g['combined']:
                output.append(f"{i}. {format_combined_lap(g['combined'], sport)}")
        output.append("")
    
    main_set_data = [g for g in grouped_data if g['planned'].get('is_main_set', False)]
    if main_set_data:
        output.append("---")
        output.append("")
        output.append("### MAIN SET (Actual)")
        output.append("")
        
        if num_rounds > 1:
            intervals_per_round = len(main_set_data) // num_rounds
            for round_num in range(num_rounds):
                output.append(f"#### ROUND {round_num + 1}")
                start_idx = round_num * intervals_per_round
                for g in main_set_data[start_idx:start_idx + intervals_per_round]:
                    if g['combined']:
                        p = g['planned']
                        label = format_planned_label(p, sport)
                        output.append(f"**{label}:** {format_combined_lap(g['combined'], sport)}  ")
                output.append("")
                output.append("---")
                output.append("")
        else:
            for g in main_set_data:
                if g['combined']:
                    p = g['planned']
                    label = format_planned_label(p, sport)
                    output.append(f"**{label}:** {format_combined_lap(g['combined'], sport)}  ")
            output.append("")
            output.append("---")
            output.append("")
    
    cooldown_data = [g for g in grouped_data if g['planned']['type'] == 'COOL']
    if cooldown_data:
        output.append("### Cool Down (Actual)")
        for g in cooldown_data:
            if g['combined']:
                output.append(f"- {format_combined_lap(g['combined'], sport)}")
        output.append("")
    
    # Summary
    output.append("---")
    output.append("## 📊 WORKOUT SUMMARY")
    output.append("")
    output.append("| Metric | Value |")
    output.append("|--------|-------|")
    output.append(f"| **Distance** | {summary.get('total_distance', '—')} |")
    output.append(f"| **Duration** | {summary.get('total_duration', '—')} |")
    
    if is_swimming:
        output.append(f"| **Active Time** | {summary.get('active_time', '—')} |")
        output.append(f"| **Avg Pace** | {summary.get('overall_swim_pace', '—')}/100m |")
        if summary.get('num_lengths'):
            output.append(f"| **Lengths** | {summary['num_lengths']} |")
        if summary.get('total_strokes'):
            output.append(f"| **Total Strokes** | {summary['total_strokes']} |")
    elif is_cycling:
        output.append(f"| **Avg Speed** | {summary.get('overall_speed', '—')} km/h |")
    else:
        output.append(f"| **Avg Pace** | {summary.get('overall_pace', '—')}/km |")
    
    if summary.get('avg_hr'):
        output.append(f"| **Avg HR** | {summary['avg_hr']} bpm |")
    if summary.get('max_hr'):
        output.append(f"| **Max HR** | {summary['max_hr']} bpm |")
    if summary.get('avg_power'):
        output.append(f"| **Avg Power** | {summary['avg_power']} W |")
    if is_cycling and summary.get('normalized_power'):
        output.append(f"| **Normalized Power** | {summary['normalized_power']} W |")
    if is_cycling and summary.get('intensity_factor'):
        output.append(f"| **Intensity Factor** | {summary['intensity_factor']:.2f} |")
    if is_cycling and summary.get('tss'):
        output.append(f"| **TSS** | {summary['tss']:.1f} |")
    if is_cycling and summary.get('left_balance'):
        left = summary['left_balance']
        right = round(100 - left, 1)
        output.append(f"| **L/R Balance** | L {left}% / R {right}% |")
    if summary.get('avg_cadence'):
        unit = "rpm" if is_cycling else ("spm" if is_swimming else "spm")
        output.append(f"| **Avg Cadence** | {summary['avg_cadence']} {unit} |")

    if summary.get('calories'):
        output.append(f"| **Calories** | {summary['calories']} kcal |")
    if summary.get('training_effect'):
        output.append(f"| **Training Effect** | {summary['training_effect']:.1f} |")
    if summary.get('vo2_max'):
        output.append(f"| **VO2 Max** | {summary['vo2_max']} ml/kg/min |")
    
    return "\n".join(output)


def format_planned_label(p: Dict, sport: str) -> str:
    """Format a short label for planned interval."""
    parts = []
    
    if p.get('target_distance_m'):
        dist = p['target_distance_m']
        if dist >= 1000:
            parts.append(f"{dist/1000:.1f}km")
        else:
            parts.append(f"{int(dist)}m")
    elif p.get('duration_seconds'):
        parts.append(format_planned_duration(p['duration_seconds']))
    
    if p.get('swim_stroke'):
        parts.append(p['swim_stroke'])
    elif p['type'] == 'RECOVERY':
        parts.append("Rest")
    else:
        parts.append("Hard" if p['type'] == 'WORK' else p['type'].title())
    
    return " ".join(parts)


def format_planned_duration(seconds: int) -> str:
    """Format planned duration for display."""
    if seconds < 60:
        return f"{seconds}s"
    elif seconds % 60 == 0:
        return f"{seconds // 60}:00"
    else:
        return f"{seconds // 60}:{seconds % 60:02d}"


def format_planned_interval(p: Dict, sport: str) -> str:
    """Format a planned interval line."""
    parts = []
    
    # Duration or distance
    if p.get('target_distance_m'):
        dist = p['target_distance_m']
        if dist >= 1000:
            parts.append(f"{dist/1000:.2f}km")
        else:
            parts.append(f"{int(dist)}m")
    elif p.get('duration_seconds'):
        parts.append(format_planned_duration(p['duration_seconds']))
    
    # Stroke type for swimming
    if p.get('swim_stroke'):
        parts.append(p['swim_stroke'])
    else:
        interval_type = p['type']
        if interval_type == 'WORK':
            parts.append("Hard")
        elif interval_type == 'RECOVERY':
            parts.append("Rest" if p.get('duration_seconds', 0) < 60 else "Easy")
        else:
            parts.append(interval_type.title())
    
    # Target
    if p.get('intensity_range'):
        parts.append(f"@ {p['intensity_range']}")
    
    if p.get('pace_range'):
        unit = "/100m" if sport == 'swimming' else "/km"
        parts.append(f"({p['pace_range']}{unit})")
    elif p.get('power_range'):
        parts.append(f"({p['power_range']})")
    
    return "- " + " ".join(parts)


def format_combined_lap(combined: Dict, sport: str) -> str:
    """Format a combined lap line with sport-specific metrics."""
    parts = []
    is_rest = combined.get('is_rest', False)
    
    # Duration
    duration = format_duration(int(combined['duration_seconds']))
    
    if is_rest:
        parts.append(f"**{duration}** Rest")
    else:
        # Distance for swimming
        if sport == 'swimming' and combined.get('distance_m'):
            dist = combined['distance_m']
            dist_str = f"{int(dist)}m" if dist < 1000 else f"{dist/1000:.2f}km"
            parts.append(f"**{dist_str}** in {duration}")
            parts.append(f"Pace {combined.get('swim_pace', '--:--')}/100m")
        elif sport == 'cycling':
            parts.append(f"**{duration}** — {combined.get('avg_speed_kmh', '--.-')} km/h")
        else:
            parts.append(f"**{duration}** — {combined.get('avg_pace', '--:--')}/km")
    
    # HR - show differently based on sport
    if not is_rest:
        if sport == 'cycling' and combined.get('avg_hr'):
            parts.append(f"HR {int(combined['avg_hr'])} avg")
        elif combined.get('start_hr') and combined.get('end_hr'):
            parts.append(f"HR {int(combined['start_hr'])}→{int(combined['end_hr'])}")
    
    # Sport-specific
    if sport == 'swimming' and combined.get('total_strokes') and not is_rest:
        parts.append(f"Strokes {combined['total_strokes']}")
        if combined.get('swim_stroke'):
            parts.append(f"({combined['swim_stroke']})")
    elif sport == 'cycling':
        if combined.get('avg_power'):
            parts.append(f"Pwr {combined['avg_power']}W")
        if combined.get('cadence'):
            parts.append(f"Cad {combined['cadence']}rpm")
    elif combined.get('cadence') and not is_rest:
        parts.append(f"Cad {combined['cadence']} spm")
    
    return " | ".join(parts)


# =============================================================================
# STREAMLIT UI
# =============================================================================

def main():
    st.set_page_config(
        page_title="Interval Matcher",
        page_icon="🏃",
        layout="wide"
    )
    
    st.title("🏃🚴🏊 Interval Matcher")
    st.markdown("Match your planned workout from intervals.icu with actual FIT file data.")
    
    with st.expander("📖 Syntax Help"):
        st.markdown("""
        ### Supported Sports
        
        **Running:** `Hard 8m 90-92% Pace (5:49-5:57 for 1.3km)`
        
        **Cycling:** `Hard 15s 76-90% (174-207w)`
        
        **Swimming:** `FS 0.1km 86-94% Pace (2:47-3:03)`
        
        **Strokes:** FS (Freestyle), Back, Breast, Fly, Pull, Kick, Choice
        """)
    
    col1, col2 = st.columns([1, 1])
    
    with col1:
        st.subheader("📝 Planned Workout")
        
        default_plan = """Warm up 5m 80-89% Pace (6:01-6:41 for 0.78km)
4x
Hard 8m 90-92% Pace (5:49-5:57 for 1.3km)
Easy 2m 80-89% Pace (6:01-6:41 for 0.31km)
Cool Down 5m 80-89% Pace"""
        
        plan_text = st.text_area("Paste your workout plan:", value=default_plan, height=220)
        
        if st.button("Parse Plan", type="primary"):
            planned_blocks, num_rounds = parse_plan_text(plan_text)
            st.session_state['planned_blocks'] = planned_blocks
            st.session_state['num_rounds'] = num_rounds
            if planned_blocks:
                st.success(f"✅ Parsed {len(planned_blocks)} intervals")
    
    with col2:
        st.subheader("📁 Workout File")
        
        uploaded_file = st.file_uploader(
            "Upload your workout file:", 
            type=['fit', 'csv'],
            help="Supports Garmin/Wahoo FIT files and FORM goggles CSV exports"
        )
        
        if uploaded_file:
            file_name = uploaded_file.name.lower()
            
            if file_name.endswith('.csv'):
                # FORM goggles CSV
                with st.spinner("Parsing FORM CSV file..."):
                    raw_lengths, session_info = load_form_csv(uploaded_file)
                
                if raw_lengths and session_info:
                    laps = process_form_lengths(raw_lengths, session_info)
                    st.session_state['actual_laps'] = laps
                    st.session_state['session_info'] = session_info
                    st.session_state['file_type'] = 'FORM'
                    
                    pool_size = session_info.get('pool_length', 25)
                    st.success(f"✅ 🏊 **FORM Swim** — {len(laps)} sets, {pool_size}m pool")
                    
            else:
                # FIT file
                with st.spinner("Parsing FIT file..."):
                    df, raw_laps, session_info = load_fit_file(uploaded_file)
                
                if raw_laps and session_info:
                    session_data = extract_session_info(session_info)
                    sport = session_data['sport']
                    laps = process_fit_laps(raw_laps, sport=sport, min_duration=3)
                    st.session_state['actual_laps'] = laps
                    st.session_state['session_info'] = session_data
                    st.session_state['file_type'] = 'FIT'
                    
                    emoji = "🏊" if sport == 'swimming' else ("🚴" if sport == 'cycling' else "🏃")
                    st.success(f"✅ {emoji} **{session_data['activity_name']}** — {len(laps)} laps")
    
    st.markdown("---")
    
    if st.button("🔄 Generate Report", type="primary"):
        if 'actual_laps' not in st.session_state:
            st.error("Upload a FIT file first!")
        else:
            session_data = st.session_state.get('session_info', {})
            sport = session_data.get('sport', 'running')
            processed_laps = st.session_state['actual_laps']
            
            # Check if plan was provided
            has_plan = 'planned_blocks' in st.session_state and st.session_state['planned_blocks']
            
            if has_plan:
                # Compare against planned workout
                grouped = group_laps_by_planned(
                    st.session_state['planned_blocks'],
                    processed_laps,
                    sport=sport
                )
                
                summary = calculate_overall_summary(processed_laps, session_data)
                
                output = generate_detailed_output(
                    st.session_state['planned_blocks'],
                    st.session_state.get('num_rounds', 0),
                    grouped,
                    summary,
                    session_data
                )
            else:
                # No plan - generate simple lap report
                st.info("ℹ️ No workout plan provided. Generating lap-by-lap summary.")
                
                summary = calculate_overall_summary(processed_laps, session_data)
                
                # Build simple report
                emoji = "🏊" if sport == 'swimming' else ("🚴" if sport == 'cycling' else "🏃")
                activity_name = session_data.get('activity_name', 'Activity')
                
                lines = []
                lines.append(f"# {emoji} {sport.upper()}: {activity_name}")
                lines.append("")
                
                start_time = session_data.get('start_time')
                if start_time:
                    lines.append(f"**Date:** {start_time}")
                lines.append("")
                
                # Summary table
                lines.append("## 📊 Summary")
                lines.append("| Metric | Value |")
                lines.append("|--------|-------|")
                lines.append(f"| **Duration** | {summary.get('total_duration', '—')} |")
                lines.append(f"| **Distance** | {summary.get('total_distance', '—')} |")
                if summary.get('avg_hr'):
                    lines.append(f"| **Avg HR** | {summary['avg_hr']} bpm |")
                if summary.get('max_hr'):
                    lines.append(f"| **Max HR** | {summary['max_hr']} bpm |")
                if summary.get('avg_power'):
                    lines.append(f"| **Avg Power** | {summary['avg_power']} W |")
                if summary.get('calories'):
                    lines.append(f"| **Calories** | {summary['calories']} kcal |")
                lines.append("")
                
                # Laps - use inline format like default workout reports
                lines.append("## 🔄 Sets")
                lines.append("")
                
                for i, lap in enumerate(processed_laps, 1):
                    dur_sec = lap.get('duration_seconds', 0)
                    mins, secs = divmod(int(dur_sec), 60)
                    duration = f"{mins}:{secs:02d}"
                    
                    dist_m = lap.get('distance_m', 0)
                    if dist_m >= 1000:
                        distance = f"{dist_m/1000:.2f}km"
                    else:
                        distance = f"{int(dist_m)}m"
                    
                    # Build inline format like format_combined_lap
                    parts = []
                    
                    if sport == 'swimming':
                        set_desc = lap.get('set_description') or f"Set {i}"
                        pace = lap.get('swim_pace') or '--:--'
                        parts.append(f"**{distance}** in {duration}")
                        parts.append(f"Pace {pace}/100m")
                        
                        # HR
                        if lap.get('avg_hr'):
                            parts.append(f"HR {lap['avg_hr']} avg")
                        
                        # SWOLF
                        if lap.get('swolf'):
                            parts.append(f"SWOLF {lap['swolf']}")
                        
                        # Strokes
                        if lap.get('total_strokes'):
                            parts.append(f"Strokes {lap['total_strokes']}")
                        
                        # DPS
                        if lap.get('dps'):
                            parts.append(f"DPS {lap['dps']:.2f}")
                        
                        # Stroke type
                        if lap.get('swim_stroke') and lap['swim_stroke'] != 'REST':
                            stroke_name = {'FR': 'Free', 'BR': 'Breast', 'BA': 'Back', 'FL': 'Fly'}.get(lap['swim_stroke'], lap['swim_stroke'])
                            parts.append(f"({stroke_name})")
                        
                        lines.append(f"**{set_desc}:** " + " | ".join(parts) + "  ")
                    else:
                        # Non-swimming format
                        hr = lap.get('avg_hr') or '—'
                        pace = lap.get('avg_pace') or '--:--'
                        parts.append(f"**{duration}** — {pace}/km")
                        if lap.get('avg_hr'):
                            parts.append(f"HR {lap['avg_hr']}")
                        if lap.get('cadence'):
                            parts.append(f"Cad {lap['cadence']} spm")
                        lines.append(f"**Lap {i}:** " + " | ".join(parts) + "  ")
                    
                    lines.append("")
                
                lines.append("---")
                lines.append("*Report generated without a workout plan.*")
                
                output = "\n".join(lines)
            
            st.markdown(output)
            st.download_button("📥 Download Report", output, "workout_report.md", "text/markdown")


if __name__ == "__main__":
    main()

