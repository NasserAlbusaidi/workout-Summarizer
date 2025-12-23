# Interval Matcher - Features Documentation

> **Privacy-First Workout Analysis Tool**
> Compare your intervals.icu training plans with actual FIT file data.

---

## 🌟 Core Features

### Workout Analysis
- **FIT File Parsing** - Upload FIT files from Garmin, Wahoo, or any ANT+ device
- **FORM Goggles CSV** - Upload swim data exports from FORM smart goggles
- **Plan Matching** - Compare actual performance against planned intervals (optional)
- **Multi-Sport Support** - Running, Cycling, and Swimming workouts
- **In-Memory Processing** - Zero data stored on server (ephemeral architecture)

### Supported Metrics

#### Primary Metrics
| Metric | Running | Cycling | Swimming |
|--------|---------|---------|----------|
| Heart Rate (Avg/Max) | ✅ | ✅ | ✅ |
| Pace | ✅ | — | ✅ |
| Power | ✅ (if available) | ✅ | — |
| Cadence | ✅ (spm) | ✅ (rpm) | ✅ (spm) |
| Distance | ✅ | ✅ | ✅ |
| Duration | ✅ | ✅ | ✅ |
| Calories | ✅ | ✅ | ✅ |

#### Advanced Metrics (when available in FIT file)
| Metric | Description |
|--------|-------------|
| VO2 Max | Estimated maximal oxygen uptake |
| Training Effect | Garmin training load impact |
| Elevation Gain | Total ascent in meters |
| Normalized Power | Intensity-weighted power (cycling) |
| Stride Length | Average stride in meters (running) |
| Ground Contact Time | Time foot spends on ground (running) |
| Left/Right Balance | Power distribution percentage (cycling with dual-sided power) |
| TSS | Training Stress Score |

---

## 📊 Interactive Charts

### Heart Rate Chart
- Bar chart showing average and max HR per interval
- Color-coded: Cyan for work intervals, gray for rest

### Pace Chart (Running)
- Pace per interval in min/km format
- Reversed Y-axis (faster = higher on chart)

### Power Chart (Cycling)
- Average power per interval in watts
- Yellow bars for work, gray for rest

### Cadence Chart
- Cadence per interval (spm for running, rpm for cycling)
- Purple color scheme

### Duration Comparison
- Side-by-side planned vs actual duration
- Green = within 10% of target
- Red = outside target range

### Distance Comparison
- Side-by-side planned vs actual distance
- Same color coding as duration

---

## 🖥️ User Interface

### Landing Page (`/`)
- Hero section with gradient text
- Feature highlights (6 cards)
- Pricing tiers display
- Call-to-action buttons

### Analysis App (`/app`)
- **Workout Plan Input** - Paste intervals.icu format
- **FIT File Upload** - Drag-drop or click to select
- **Real-time Analysis** - Instant results
- **Session History** - Last 10 analyses stored locally

### Results Display
- Activity header with sport icon
- Up to 15 metric tiles (3 rows)
- Interactive charts
- Expandable full report

---

## 📥 Export Options

### Markdown Download
- Full analysis report as `.md` file
- Includes all intervals and metrics
- Perfect for notes or documentation

### PDF Export
- Print-optimized formatting
- Opens browser print dialog
- Save as PDF or send to printer

---

## 📜 Session History

- **Local Storage** - History saved in browser only
- **Up to 10 Sessions** - Oldest automatically removed
- **Quick Stats** - Distance and duration at a glance
- **Clear All** - One-click history deletion
- **Privacy Preserved** - Never sent to server

---

## 🔐 API Features

### Rate Limiting
- 10 requests per minute
- Prevents abuse and ensures availability

### API Key Authentication
| Tier | Daily Limit | Features |
|------|-------------|----------|
| Anonymous | 3 | Basic analysis |
| Free | 3 | Basic analysis |
| Pro | 50 | All features |
| Elite | 1000 | All features + API access |

### API Endpoints
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/analyze` | POST | Main analysis endpoint |
| `/health` | GET | Health check for load balancers |
| `/validate-key` | GET | Validate API key and get tier info |
| `/tiers` | GET | List available subscription tiers |

---

## 🧪 Testing

### Test Suite
- 13 automated tests covering:
  - Health endpoint
  - Tier information
  - API key validation (all tiers)
  - Request validation
  - Rate limiting

### Run Tests
```bash
python3 -m pytest test_api.py -v
```

---

## 🏗️ Technical Architecture

### Ephemeral Pipeline
```
User → FIT bytes → RAM (BytesIO) → Parse → JSON Response → Memory cleared
                         ↑
                   Zero disk writes
```

### Technology Stack

**Backend**
- FastAPI (Python)
- fitdecode (in-memory FIT parsing)
- slowapi (rate limiting)
- Pydantic (validation)

**Frontend**
- Next.js 15
- TypeScript
- Tailwind CSS
- Recharts (visualization)

**Infrastructure**
- Docker-ready
- Serverless compatible (AWS Lambda, Cloud Run)

---

## 🎨 Design System

### Color Palette
| Color | Usage | Hex |
|-------|-------|-----|
| Cyan | Primary accent, Avg HR | `#00d4ff` |
| Green | Pace, On-target | `#22c55e` |
| Red | Max HR, Off-target | `#ef4444` |
| Yellow | Power | `#eab308` |
| Purple | Cadence | `#a855f7` |
| Orange | Calories | `#f97316` |
| Zinc | Rest intervals, secondary | `#71717a` |

### Typography
- System fonts (SF Pro, Segoe UI, Roboto)
- Geist Sans for body text
- Geist Mono for code/plans

### Animations
- Fade-in on load
- Smooth hover transitions
- Loading spinner
- Pulse glow effect

---

## 📱 Responsive Design

- **Desktop** - Full two-column layout
- **Tablet** - Stacked layout, 4-column stats grid
- **Mobile** - Single column, 2-column stats grid

---

## 🔒 Privacy & Security

### Data Handling
- ✅ All processing in RAM
- ✅ No file storage
- ✅ No database persistence
- ✅ No analytics tracking
- ✅ TLS 1.3 in transit
- ✅ Session history stored locally only

### No Data Collected
- No user accounts (optional API key)
- No workout data stored
- No personal information required

---

## 🚀 Deployment Ready

### Docker
```bash
docker build -t interval-matcher .
docker run -p 8001:8001 interval-matcher
```

### Local Development
```bash
# Backend
python3 -m uvicorn api:app --reload --port 8001

# Frontend
cd frontend && npm run dev
```

### Production
- Vercel (frontend)
- Google Cloud Run / AWS Lambda (backend)

---

*Last updated: December 2024*
