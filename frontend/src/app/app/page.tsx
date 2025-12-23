"use client";

import { useState, useEffect } from "react";
import { PerformanceCharts } from "./charts";
import { ErrorBoundary, ChartErrorBoundary } from "./error-boundary";

// Properly typed summary interface
interface WorkoutSummary {
  activity_name?: string;
  sport?: string;
  total_distance?: string;
  total_duration?: string;
  avg_hr?: number;
  max_hr?: number;
  overall_pace?: string;
  avg_power?: number;
  normalized_power?: number;
  avg_cadence?: number;
  max_cadence?: number;
  avg_stride?: number;
  calories?: number;
  elevation_gain?: number;
  training_effect?: number;
  vo2_max?: number;
  left_balance?: number;
  avg_gct?: number;
  timestamp?: string;
}

interface IntervalData {
  planned: Record<string, unknown>;
  combined?: Record<string, unknown>;
}

interface AnalysisResult {
  success: boolean;
  sport: string;
  summary: WorkoutSummary;
  grouped_data: IntervalData[];
  markdown_report: string;
  error?: string;
}

interface HistoryItem {
  id: string;
  timestamp: string;
  fileName: string;
  sport: string;
  summary: WorkoutSummary;
}


const HISTORY_KEY = "interval-matcher-history";
const MAX_HISTORY = 10;

export default function Home() {
  const [plan, setPlan] = useState<string>(`Warm up 5m 80-89% Pace (6:01-6:41)
4x
Hard 8m 90-92% Pace (5:49-5:57)
Easy 2m 80-89% Pace (6:01-6:41)
Cool Down 5m 80-89% Pace`);
  const [file, setFile] = useState<File | null>(null);
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<AnalysisResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [history, setHistory] = useState<HistoryItem[]>([]);
  const [showHistory, setShowHistory] = useState(false);

  const API_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8001";

  // Load history from localStorage on mount
  useEffect(() => {
    const saved = localStorage.getItem(HISTORY_KEY);
    if (saved) {
      try {
        setHistory(JSON.parse(saved));
      } catch {
        console.error("Failed to parse history");
      }
    }
  }, []);

  // Save to history
  const saveToHistory = (result: AnalysisResult, fileName: string) => {
    const item: HistoryItem = {
      id: Date.now().toString(),
      timestamp: new Date().toISOString(),
      fileName,
      sport: result.sport,
      summary: result.summary,
    };

    const updated = [item, ...history].slice(0, MAX_HISTORY);
    setHistory(updated);
    localStorage.setItem(HISTORY_KEY, JSON.stringify(updated));
  };

  // Download as Markdown
  const downloadMarkdown = () => {
    if (!result) return;
    const blob = new Blob([result.markdown_report], { type: "text/markdown" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `workout-${new Date().toISOString().split("T")[0]}.md`;
    a.click();
    URL.revokeObjectURL(url);
  };

  // Download as PDF (using browser print)
  const downloadPDF = () => {
    if (!result) return;
    const printWindow = window.open("", "_blank");
    if (!printWindow) return;

    printWindow.document.write(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>Workout Report</title>
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 40px; max-width: 800px; margin: 0 auto; }
          h1, h2, h3 { color: #0891b2; }
          table { width: 100%; border-collapse: collapse; margin: 20px 0; }
          th, td { padding: 8px 12px; border: 1px solid #e5e5e5; text-align: left; }
          th { background: #f5f5f5; }
          pre { background: #f5f5f5; padding: 16px; border-radius: 8px; overflow: auto; }
          .header { border-bottom: 3px solid #0891b2; padding-bottom: 20px; margin-bottom: 20px; }
          .stat { display: inline-block; margin-right: 30px; }
          .stat-value { font-size: 24px; font-weight: bold; color: #0891b2; }
          .stat-label { font-size: 12px; color: #666; text-transform: uppercase; }
        </style>
      </head>
      <body>
        <div class="header">
          <h1>⚡ Interval Matcher Report</h1>
          <p>${new Date().toLocaleDateString()} • ${result.sport.toUpperCase()}</p>
        </div>
        <div style="margin-bottom: 30px;">
          <div class="stat">
            <div class="stat-value">${result.summary.total_distance || "—"}</div>
            <div class="stat-label">Distance</div>
          </div>
          <div class="stat">
            <div class="stat-value">${result.summary.total_duration || "—"}</div>
            <div class="stat-label">Duration</div>
          </div>
          <div class="stat">
            <div class="stat-value">${result.summary.avg_hr || "—"}</div>
            <div class="stat-label">Avg HR</div>
          </div>
        </div>
        <pre>${result.markdown_report}</pre>
      </body>
      </html>
    `);
    printWindow.document.close();
    printWindow.print();
  };

  const handleAnalyze = async () => {
    if (!file) {
      setError("Please select a FIT file");
      return;
    }

    setLoading(true);
    setError(null);
    setResult(null);

    try {
      const formData = new FormData();
      formData.append("file", file);
      // Only send plan if user entered something
      if (plan.trim()) {
        formData.append("plan", plan);
      }

      const response = await fetch(`${API_URL}/analyze`, {
        method: "POST",
        body: formData,
      });

      if (!response.ok) {
        throw new Error(`API error: ${response.status}`);
      }

      const data: AnalysisResult = await response.json();

      if (!data.success) {
        throw new Error(data.error || "Analysis failed");
      }

      setResult(data);
      saveToHistory(data, file.name);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unknown error");
    } finally {
      setLoading(false);
    }
  };

  const clearHistory = () => {
    setHistory([]);
    localStorage.removeItem(HISTORY_KEY);
  };

  return (
    <div className="min-h-screen bg-black text-white">
      {/* Header */}
      <header className="border-b border-zinc-800 px-6 py-4">
        <div className="max-w-6xl mx-auto flex items-center justify-between">
          <h1 className="text-2xl font-bold tracking-tight">
            <span className="text-cyan-400">⚡</span> Interval Matcher
          </h1>
          <div className="flex items-center gap-4">
            <button
              onClick={() => setShowHistory(!showHistory)}
              className="text-sm text-zinc-400 hover:text-cyan-400 transition-colors"
            >
              📜 History ({history.length})
            </button>
            <span className="text-xs text-zinc-500 uppercase tracking-widest hidden sm:block">
              Ephemeral • Zero Data Stored
            </span>
          </div>
        </div>
      </header>

      {/* History Panel */}
      {showHistory && (
        <div className="border-b border-zinc-800 bg-zinc-900/50 px-6 py-4">
          <div className="max-w-6xl mx-auto">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-sm font-medium text-zinc-400">Recent Sessions (stored locally)</h3>
              {history.length > 0 && (
                <button
                  onClick={clearHistory}
                  className="text-xs text-red-400 hover:text-red-300"
                >
                  Clear All
                </button>
              )}
            </div>
            {history.length === 0 ? (
              <p className="text-sm text-zinc-600">No sessions yet</p>
            ) : (
              <div className="grid gap-2">
                {history.map((item) => (
                  <div
                    key={item.id}
                    className="flex items-center justify-between p-3 bg-zinc-800/50 rounded-lg"
                  >
                    <div className="flex items-center gap-3">
                      <span className="text-lg">
                        {item.sport === "running" ? "🏃" : item.sport === "cycling" ? "🚴" : "🏊"}
                      </span>
                      <div>
                        <div className="text-sm font-medium">{item.fileName}</div>
                        <div className="text-xs text-zinc-500">
                          {new Date(item.timestamp).toLocaleString()}
                        </div>
                      </div>
                    </div>
                    <div className="text-sm text-zinc-400">
                      {String(item.summary.total_distance || "")} • {String(item.summary.total_duration || "")}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      <main className="max-w-6xl mx-auto px-6 py-12">
        <div className="grid md:grid-cols-2 gap-8">
          {/* Left: Inputs */}
          <div className="space-y-6">
            <div>
              <label className="block text-sm font-medium text-zinc-400 mb-2">
                📝 Workout Plan (Optional)
                <span className="block text-xs text-zinc-500 font-normal mt-1">
                  Paste intervals.icu plan to compare, or leave empty for lap-only analysis
                </span>
              </label>
              <textarea
                value={plan}
                onChange={(e) => setPlan(e.target.value)}
                className="w-full h-48 bg-zinc-900 border border-zinc-700 rounded-lg px-4 py-3 font-mono text-sm text-cyan-300 focus:border-cyan-500 focus:outline-none resize-none"
                placeholder="Paste your workout plan... (optional)"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-zinc-400 mb-2">
                📁 Workout File
                <span className="block text-xs text-zinc-500 font-normal mt-1">
                  Supports FIT files and FORM goggles CSV exports
                </span>
              </label>
              <div className="relative">
                <input
                  type="file"
                  accept=".fit,.csv"
                  onChange={(e) => setFile(e.target.files?.[0] || null)}
                  className="w-full bg-zinc-900 border border-zinc-700 rounded-lg px-4 py-3 text-sm file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-cyan-500 file:text-black hover:file:bg-cyan-400 cursor-pointer"
                />
              </div>
              {file && (
                <p className="mt-2 text-sm text-zinc-500">
                  ✓ {file.name} ({(file.size / 1024).toFixed(1)} KB)
                </p>
              )}
            </div>

            <button
              onClick={handleAnalyze}
              disabled={loading || !file}
              className="w-full py-4 bg-gradient-to-r from-cyan-500 to-blue-600 text-black font-bold rounded-lg uppercase tracking-widest hover:from-cyan-400 hover:to-blue-500 disabled:opacity-50 disabled:cursor-not-allowed transition-all"
            >
              {loading ? (
                <span className="flex items-center justify-center gap-2">
                  <svg className="animate-spin h-5 w-5" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" fill="none" />
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                  </svg>
                  Analyzing...
                </span>
              ) : (
                "🚀 Analyze Workout"
              )}
            </button>

            {error && (
              <div className="p-4 bg-red-900/30 border border-red-500 rounded-lg text-red-300 flex items-start gap-3">
                <span>⚠️</span>
                <span>{error}</span>
              </div>
            )}
          </div>

          {/* Right: Results */}
          <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-6 min-h-[400px]">
            {!result && !loading && (
              <div className="flex flex-col items-center justify-center h-full text-zinc-600 gap-2">
                <span className="text-4xl">📊</span>
                <p>Results will appear here</p>
              </div>
            )}

            {loading && (
              <div className="flex flex-col items-center justify-center h-full gap-4">
                <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-cyan-500"></div>
                <p className="text-sm text-zinc-500 animate-pulse">Processing FIT file...</p>
              </div>
            )}

            {result && (
              <div className="space-y-6">
                {/* Activity Header */}
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-4">
                    <span className="text-4xl">
                      {result.sport === "running" ? "🏃" : result.sport === "cycling" ? "🚴" : "🏊"}
                    </span>
                    <div>
                      <h2 className="text-xl font-bold text-cyan-400">
                        {String(result.summary.activity_name || "Workout")}
                      </h2>
                      <p className="text-sm text-zinc-500">
                        {String(result.summary.total_distance || "")} • {String(result.summary.total_duration || "")}
                      </p>
                    </div>
                  </div>
                </div>

                {/* Quick Stats - Row 1: Primary Metrics */}
                <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                  {result.summary.avg_hr && (
                    <div className="bg-black rounded-lg p-4 border-t-2 border-cyan-500">
                      <div className="text-2xl font-bold text-white">{result.summary.avg_hr}</div>
                      <div className="text-xs text-zinc-500 uppercase">Avg HR</div>
                    </div>
                  )}
                  {result.summary.max_hr && (
                    <div className="bg-black rounded-lg p-4 border-t-2 border-red-500">
                      <div className="text-2xl font-bold text-white">{result.summary.max_hr}</div>
                      <div className="text-xs text-zinc-500 uppercase">Max HR</div>
                    </div>
                  )}
                  {result.summary.overall_pace && (
                    <div className="bg-black rounded-lg p-4 border-t-2 border-green-500">
                      <div className="text-2xl font-bold text-white">{result.summary.overall_pace}</div>
                      <div className="text-xs text-zinc-500 uppercase">Pace</div>
                    </div>
                  )}
                  {result.summary.avg_power && (
                    <div className="bg-black rounded-lg p-4 border-t-2 border-yellow-500">
                      <div className="text-2xl font-bold text-white">{result.summary.avg_power}W</div>
                      <div className="text-xs text-zinc-500 uppercase">Avg Power</div>
                    </div>
                  )}
                </div>

                {/* Quick Stats - Row 2: Secondary Metrics */}
                <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                  {result.summary.avg_cadence && (
                    <div className="bg-black rounded-lg p-4 border-t-2 border-purple-500">
                      <div className="text-2xl font-bold text-white">{result.summary.avg_cadence}</div>
                      <div className="text-xs text-zinc-500 uppercase">Cadence</div>
                    </div>
                  )}
                  {result.summary.calories && (
                    <div className="bg-black rounded-lg p-4 border-t-2 border-orange-500">
                      <div className="text-2xl font-bold text-white">{result.summary.calories}</div>
                      <div className="text-xs text-zinc-500 uppercase">Calories</div>
                    </div>
                  )}
                  {result.summary.elevation_gain && (
                    <div className="bg-black rounded-lg p-4 border-t-2 border-teal-500">
                      <div className="text-2xl font-bold text-white">{result.summary.elevation_gain}m</div>
                      <div className="text-xs text-zinc-500 uppercase">Elevation</div>
                    </div>
                  )}
                  {result.summary.normalized_power && (
                    <div className="bg-black rounded-lg p-4 border-t-2 border-amber-500">
                      <div className="text-2xl font-bold text-white">{result.summary.normalized_power}W</div>
                      <div className="text-xs text-zinc-500 uppercase">NP</div>
                    </div>
                  )}
                </div>

                {/* Quick Stats - Row 3: Advanced Metrics */}
                <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                  {result.summary.vo2_max && (
                    <div className="bg-black rounded-lg p-4 border-t-2 border-blue-500">
                      <div className="text-2xl font-bold text-white">{result.summary.vo2_max}</div>
                      <div className="text-xs text-zinc-500 uppercase">VO2 Max</div>
                    </div>
                  )}
                  {result.summary.training_effect && (
                    <div className="bg-black rounded-lg p-4 border-t-2 border-pink-500">
                      <div className="text-2xl font-bold text-white">{result.summary.training_effect}</div>
                      <div className="text-xs text-zinc-500 uppercase">Training Effect</div>
                    </div>
                  )}
                  {result.summary.avg_stride && (
                    <div className="bg-black rounded-lg p-4 border-t-2 border-indigo-500">
                      <div className="text-2xl font-bold text-white">{result.summary.avg_stride}m</div>
                      <div className="text-xs text-zinc-500 uppercase">Stride</div>
                    </div>
                  )}
                  {result.summary.avg_gct && (
                    <div className="bg-black rounded-lg p-4 border-t-2 border-rose-500">
                      <div className="text-2xl font-bold text-white">{result.summary.avg_gct}ms</div>
                      <div className="text-xs text-zinc-500 uppercase">GCT</div>
                    </div>
                  )}
                  {result.summary.left_balance && (
                    <div className="bg-black rounded-lg p-4 border-t-2 border-lime-500">
                      <div className="text-2xl font-bold text-white">{result.summary.left_balance}%</div>
                      <div className="text-xs text-zinc-500 uppercase">L/R Balance</div>
                    </div>
                  )}
                </div>

                {/* Performance Charts */}
                {result.grouped_data && result.grouped_data.length > 0 && (
                  <div className="pt-4 border-t border-zinc-800">
                    <h3 className="text-sm font-medium text-zinc-400 mb-4">📈 Performance Charts</h3>
                    <ChartErrorBoundary>
                      <PerformanceCharts
                        groupedData={result.grouped_data}
                        sport={result.sport}
                      />
                    </ChartErrorBoundary>
                  </div>
                )}


                {/* Download Buttons */}

                <div className="flex gap-3 pt-4 border-t border-zinc-800">
                  <button
                    onClick={downloadMarkdown}
                    className="flex-1 py-2 px-4 bg-zinc-800 hover:bg-zinc-700 rounded-lg text-sm font-medium transition-colors"
                  >
                    📥 Download MD
                  </button>
                  <button
                    onClick={downloadPDF}
                    className="flex-1 py-2 px-4 bg-zinc-800 hover:bg-zinc-700 rounded-lg text-sm font-medium transition-colors"
                  >
                    📄 Print/PDF
                  </button>
                </div>

                {/* Full Report */}
                <div className="pt-4 border-t border-zinc-800">
                  <details>
                    <summary className="cursor-pointer text-sm text-zinc-400 hover:text-cyan-400 font-medium">
                      📋 View Full Report
                    </summary>
                    <pre className="mt-4 p-4 bg-black rounded-lg overflow-auto text-xs text-zinc-300 whitespace-pre-wrap max-h-96">
                      {result.markdown_report}
                    </pre>
                  </details>
                </div>
              </div>
            )}
          </div>
        </div>
      </main>

      {/* Footer */}
      <footer className="border-t border-zinc-800 px-6 py-4 text-center text-zinc-600 text-sm">
        Privacy-first • No data stored on server • History saved locally in your browser
      </footer>
    </div>
  );
}
