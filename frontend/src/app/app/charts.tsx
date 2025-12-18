"use client";

import {
    BarChart,
    Bar,
    XAxis,
    YAxis,
    Tooltip,
    ResponsiveContainer,
    LineChart,
    Line,
    ReferenceLine,
    Cell,
} from "recharts";

interface IntervalData {
    planned: Record<string, unknown>;
    combined?: Record<string, unknown>;
}

interface ChartProps {
    groupedData: IntervalData[];
    sport: string;
}

// Color scheme
const COLORS = {
    cyan: "#00d4ff",
    green: "#22c55e",
    red: "#ef4444",
    yellow: "#eab308",
    purple: "#a855f7",
    zinc: "#71717a",
};

export function HeartRateChart({ groupedData, sport }: ChartProps) {
    const data = groupedData
        .filter((g) => g.combined)
        .map((g, i) => ({
            name: `Int ${i + 1}`,
            avgHR: g.combined?.avg_hr || 0,
            maxHR: g.combined?.max_hr || 0,
            isRest: g.combined?.is_rest || false,
        }));

    if (data.length === 0 || !data.some((d) => Number(d.avgHR) > 0)) return null;

    return (
        <div className="bg-zinc-900 rounded-xl p-4 border border-zinc-800">
            <h3 className="text-sm font-medium text-zinc-400 mb-4">❤️ Heart Rate by Interval</h3>
            <ResponsiveContainer width="100%" height={200}>
                <BarChart data={data}>
                    <XAxis dataKey="name" tick={{ fill: "#71717a", fontSize: 12 }} />
                    <YAxis tick={{ fill: "#71717a", fontSize: 12 }} domain={[60, "auto"]} />
                    <Tooltip
                        contentStyle={{ backgroundColor: "#18181b", border: "1px solid #3f3f46", borderRadius: 8 }}
                        labelStyle={{ color: "#fff" }}
                    />
                    <Bar dataKey="avgHR" name="Avg HR" radius={[4, 4, 0, 0]}>
                        {data.map((entry, index) => (
                            <Cell key={index} fill={entry.isRest ? COLORS.zinc : COLORS.cyan} />
                        ))}
                    </Bar>
                    <Bar dataKey="maxHR" name="Max HR" fill={COLORS.red} radius={[4, 4, 0, 0]} opacity={0.5} />
                </BarChart>
            </ResponsiveContainer>
        </div>
    );
}

export function PaceChart({ groupedData, sport }: ChartProps) {
    if (sport !== "running") return null;

    const data = groupedData
        .filter((g) => g.combined && g.combined.avg_pace)
        .map((g, i) => {
            const paceStr = String(g.combined?.avg_pace || "0:00");
            const [min, sec] = paceStr.split(":").map(Number);
            const paceSeconds = min * 60 + (sec || 0);

            // Get target pace from planned
            const targetMin = g.planned?.target_pace_min_ms;
            const targetMax = g.planned?.target_pace_max_ms;

            return {
                name: `Int ${i + 1}`,
                pace: paceSeconds,
                paceLabel: paceStr,
                targetMin: targetMin ? 1000 / Number(targetMin) : null,
                targetMax: targetMax ? 1000 / Number(targetMax) : null,
                isRest: g.combined?.is_rest || false,
            };
        });

    if (data.length === 0) return null;

    return (
        <div className="bg-zinc-900 rounded-xl p-4 border border-zinc-800">
            <h3 className="text-sm font-medium text-zinc-400 mb-4">🏃 Pace by Interval (min/km)</h3>
            <ResponsiveContainer width="100%" height={200}>
                <BarChart data={data}>
                    <XAxis dataKey="name" tick={{ fill: "#71717a", fontSize: 12 }} />
                    <YAxis
                        tick={{ fill: "#71717a", fontSize: 12 }}
                        tickFormatter={(v) => `${Math.floor(v / 60)}:${String(v % 60).padStart(2, "0")}`}
                        domain={["auto", "auto"]}
                        reversed
                    />
                    <Tooltip
                        contentStyle={{ backgroundColor: "#18181b", border: "1px solid #3f3f46", borderRadius: 8 }}
                        labelStyle={{ color: "#fff" }}
                        formatter={(value) => {
                            const v = Number(value) || 0;
                            return `${Math.floor(v / 60)}:${String(Math.round(v % 60)).padStart(2, "0")}`;
                        }}
                    />
                    <Bar dataKey="pace" name="Pace" radius={[4, 4, 0, 0]}>
                        {data.map((entry, index) => (
                            <Cell key={index} fill={entry.isRest ? COLORS.zinc : COLORS.green} />
                        ))}
                    </Bar>
                </BarChart>
            </ResponsiveContainer>
        </div>
    );
}

export function PowerChart({ groupedData, sport }: ChartProps) {
    if (sport !== "cycling") return null;

    const data = groupedData
        .filter((g) => g.combined && g.combined.avg_power)
        .map((g, i) => ({
            name: `Int ${i + 1}`,
            power: Number(g.combined?.avg_power) || 0,
            targetMin: g.planned?.target_power_min || null,
            targetMax: g.planned?.target_power_max || null,
            isRest: g.combined?.is_rest || false,
        }));

    if (data.length === 0) return null;

    return (
        <div className="bg-zinc-900 rounded-xl p-4 border border-zinc-800">
            <h3 className="text-sm font-medium text-zinc-400 mb-4">⚡ Power by Interval (W)</h3>
            <ResponsiveContainer width="100%" height={200}>
                <BarChart data={data}>
                    <XAxis dataKey="name" tick={{ fill: "#71717a", fontSize: 12 }} />
                    <YAxis tick={{ fill: "#71717a", fontSize: 12 }} />
                    <Tooltip
                        contentStyle={{ backgroundColor: "#18181b", border: "1px solid #3f3f46", borderRadius: 8 }}
                        labelStyle={{ color: "#fff" }}
                    />
                    <Bar dataKey="power" name="Avg Power" radius={[4, 4, 0, 0]}>
                        {data.map((entry, index) => (
                            <Cell key={index} fill={entry.isRest ? COLORS.zinc : COLORS.yellow} />
                        ))}
                    </Bar>
                </BarChart>
            </ResponsiveContainer>
        </div>
    );
}

export function DurationComparisonChart({ groupedData, sport }: ChartProps) {
    const data = groupedData
        .filter((g) => g.combined)
        .map((g, i) => {
            const plannedDuration = Number(g.planned?.duration_seconds) || 0;
            const actualDuration = Number(g.combined?.duration_seconds) || 0;
            const diff = actualDuration - plannedDuration;
            const diffPercent = plannedDuration > 0 ? ((diff / plannedDuration) * 100).toFixed(1) : 0;

            return {
                name: `Int ${i + 1}`,
                planned: Math.round(plannedDuration),
                actual: Math.round(actualDuration),
                diff,
                diffPercent,
                onTarget: Math.abs(Number(diffPercent)) < 10,
            };
        });

    if (data.length === 0) return null;

    return (
        <div className="bg-zinc-900 rounded-xl p-4 border border-zinc-800">
            <h3 className="text-sm font-medium text-zinc-400 mb-4">⏱️ Duration: Planned vs Actual</h3>
            <ResponsiveContainer width="100%" height={200}>
                <BarChart data={data} barGap={0}>
                    <XAxis dataKey="name" tick={{ fill: "#71717a", fontSize: 12 }} />
                    <YAxis
                        tick={{ fill: "#71717a", fontSize: 12 }}
                        tickFormatter={(v) => `${Math.floor(v / 60)}:${String(v % 60).padStart(2, "0")}`}
                    />
                    <Tooltip
                        contentStyle={{ backgroundColor: "#18181b", border: "1px solid #3f3f46", borderRadius: 8 }}
                        labelStyle={{ color: "#fff" }}
                        formatter={(value, name) => {
                            const v = Number(value) || 0;
                            return [
                                `${Math.floor(v / 60)}:${String(Math.round(v % 60)).padStart(2, "0")}`,
                                String(name),
                            ];
                        }}
                    />
                    <Bar dataKey="planned" name="Planned" fill={COLORS.zinc} radius={[4, 4, 0, 0]} />
                    <Bar dataKey="actual" name="Actual" radius={[4, 4, 0, 0]}>
                        {data.map((entry, index) => (
                            <Cell key={index} fill={entry.onTarget ? COLORS.green : COLORS.red} />
                        ))}
                    </Bar>
                </BarChart>
            </ResponsiveContainer>
        </div>
    );
}

export function CadenceChart({ groupedData, sport }: ChartProps) {
    const data = groupedData
        .filter((g) => g.combined && g.combined.cadence)
        .map((g, i) => ({
            name: `Int ${i + 1}`,
            cadence: Number(g.combined?.cadence) || 0,
            isRest: g.combined?.is_rest || false,
        }));

    if (data.length === 0) return null;

    const cadenceUnit = sport === "running" ? "spm" : sport === "cycling" ? "rpm" : "spm";

    return (
        <div className="bg-zinc-900 rounded-xl p-4 border border-zinc-800">
            <h3 className="text-sm font-medium text-zinc-400 mb-4">🦿 Cadence by Interval ({cadenceUnit})</h3>
            <ResponsiveContainer width="100%" height={200}>
                <BarChart data={data}>
                    <XAxis dataKey="name" tick={{ fill: "#71717a", fontSize: 12 }} />
                    <YAxis tick={{ fill: "#71717a", fontSize: 12 }} />
                    <Tooltip
                        contentStyle={{ backgroundColor: "#18181b", border: "1px solid #3f3f46", borderRadius: 8 }}
                        labelStyle={{ color: "#fff" }}
                    />
                    <Bar dataKey="cadence" name="Cadence" radius={[4, 4, 0, 0]}>
                        {data.map((entry, index) => (
                            <Cell key={index} fill={entry.isRest ? COLORS.zinc : COLORS.purple} />
                        ))}
                    </Bar>
                </BarChart>
            </ResponsiveContainer>
        </div>
    );
}

export function DistanceComparisonChart({ groupedData, sport }: ChartProps) {
    const data = groupedData
        .filter((g) => g.combined && g.planned?.target_distance_m)
        .map((g, i) => {
            const plannedDist = Number(g.planned?.target_distance_m) || 0;
            const actualDist = Number(g.combined?.distance_m) || 0;
            const diff = actualDist - plannedDist;
            const diffPercent = plannedDist > 0 ? ((diff / plannedDist) * 100).toFixed(1) : 0;

            return {
                name: `Int ${i + 1}`,
                planned: Math.round(plannedDist),
                actual: Math.round(actualDist),
                onTarget: Math.abs(Number(diffPercent)) < 10,
            };
        });

    if (data.length === 0) return null;

    return (
        <div className="bg-zinc-900 rounded-xl p-4 border border-zinc-800">
            <h3 className="text-sm font-medium text-zinc-400 mb-4">📏 Distance: Planned vs Actual (m)</h3>
            <ResponsiveContainer width="100%" height={200}>
                <BarChart data={data} barGap={0}>
                    <XAxis dataKey="name" tick={{ fill: "#71717a", fontSize: 12 }} />
                    <YAxis tick={{ fill: "#71717a", fontSize: 12 }} />
                    <Tooltip
                        contentStyle={{ backgroundColor: "#18181b", border: "1px solid #3f3f46", borderRadius: 8 }}
                        labelStyle={{ color: "#fff" }}
                    />
                    <Bar dataKey="planned" name="Planned" fill={COLORS.zinc} radius={[4, 4, 0, 0]} />
                    <Bar dataKey="actual" name="Actual" radius={[4, 4, 0, 0]}>
                        {data.map((entry, index) => (
                            <Cell key={index} fill={entry.onTarget ? COLORS.green : COLORS.red} />
                        ))}
                    </Bar>
                </BarChart>
            </ResponsiveContainer>
        </div>
    );
}

export function PerformanceCharts({ groupedData, sport }: ChartProps) {
    return (
        <div className="space-y-4">
            <HeartRateChart groupedData={groupedData} sport={sport} />
            <PaceChart groupedData={groupedData} sport={sport} />
            <PowerChart groupedData={groupedData} sport={sport} />
            <CadenceChart groupedData={groupedData} sport={sport} />
            <DurationComparisonChart groupedData={groupedData} sport={sport} />
            <DistanceComparisonChart groupedData={groupedData} sport={sport} />
        </div>
    );
}
