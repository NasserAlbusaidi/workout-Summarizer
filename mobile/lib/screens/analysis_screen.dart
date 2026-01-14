import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../models/workout.dart';
import '../widgets/workout_charts.dart';
import '../widgets/route_map.dart';

class AnalysisScreen extends StatelessWidget {
  final WorkoutAnalysis analysis;

  const AnalysisScreen({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    final session = analysis.session;

    final emoji = switch (session.sport) {
      SportType.swimming => '🏊',
      SportType.cycling => '🚴',
      SportType.running => '🏃',
      _ => '🏋️',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text('$emoji ${session.activityName ?? "Workout"}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareReport(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            32,
          ), // Extra bottom padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary cards
              _SummarySection(session: session, laps: analysis.laps),

              const SizedBox(height: 24),

              // Laps section
              Text(
                '🔄 ${session.sport == SportType.swimming ? "Sets" : "Laps"}',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              ...analysis.laps.asMap().entries.map((entry) {
                final idx = entry.key;
                final lap = entry.value;
                return _LapCard(lap: lap, index: idx, sport: session.sport);
              }),

              // Charts section
              WorkoutChartsSection(analysis: analysis),

              // Map section
              WorkoutMapSection(analysis: analysis),

              const SizedBox(height: 24),

              // Full report
              Card(
                child: ExpansionTile(
                  title: Text(
                    '📄 Full Report',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  children: [
                    if (analysis.markdownReport != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: MarkdownBody(
                          data: analysis.markdownReport!,
                          styleSheet: MarkdownStyleSheet(
                            p: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey[300],
                            ),
                            h1: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            h2: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                            tableHead: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Extra bottom spacing for navigation bar
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  void _shareReport(BuildContext context) {
    if (analysis.markdownReport != null) {
      Share.share(
        analysis.markdownReport!,
        subject: '${analysis.session.activityName ?? "Workout"} Analysis',
      );
    }
  }
}

class _SummarySection extends StatelessWidget {
  final WorkoutSession session;
  final List<WorkoutLap> laps;

  const _SummarySection({required this.session, required this.laps});

  @override
  Widget build(BuildContext context) {
    // Calculate totals from laps
    final totalDuration = laps.fold<Duration>(
      Duration.zero,
      (sum, lap) => sum + lap.duration,
    );
    final totalDistance = laps.fold<double>(
      0,
      (sum, lap) => sum + lap.distanceMeters,
    );
    final hrValues = laps
        .where((l) => l.avgHr != null)
        .map((l) => l.avgHr!)
        .toList();
    final avgHr = hrValues.isNotEmpty
        ? (hrValues.reduce((a, b) => a + b) / hrValues.length).round()
        : session.avgHr;
    final maxHr = laps
        .where((l) => l.maxHr != null)
        .map((l) => l.maxHr!)
        .fold<int?>(
          session.maxHr,
          (max, hr) => max == null || hr > max ? hr : max,
        );

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        // Common metrics for all sports
        _MetricCard(
          icon: Icons.timer,
          label: 'Duration',
          value: _formatDuration(totalDuration),
          color: const Color(0xFF00D4FF),
        ),
        _MetricCard(
          icon: Icons.straighten,
          label: 'Distance',
          value: _formatDistance(totalDistance),
          color: const Color(0xFF22C55E),
        ),
        if (avgHr != null)
          _MetricCard(
            icon: Icons.favorite,
            label: 'Avg HR',
            value: '$avgHr bpm',
            color: const Color(0xFFF97316),
          ),
        if (maxHr != null)
          _MetricCard(
            icon: Icons.favorite_border,
            label: 'Max HR',
            value: '$maxHr bpm',
            color: const Color(0xFFEF4444),
          ),
        if (session.calories != null)
          _MetricCard(
            icon: Icons.local_fire_department,
            label: 'Calories',
            value: '${session.calories} kcal',
            color: const Color(0xFFEC4899),
          ),

        // CYCLING-specific metrics
        ..._buildCyclingMetrics(),

        // RUNNING-specific metrics
        ..._buildRunningMetrics(totalDistance, totalDuration),

        // SWIMMING-specific metrics
        ..._buildSwimmingMetrics(),
      ],
    );
  }

  List<Widget> _buildCyclingMetrics() {
    if (session.sport != SportType.cycling) return [];

    return [
      if (session.avgPower != null)
        _MetricCard(
          icon: Icons.bolt,
          label: 'Avg Power',
          value: '${session.avgPower} W',
          color: const Color(0xFFEAB308),
        ),
      if (session.maxPower != null)
        _MetricCard(
          icon: Icons.flash_on,
          label: 'Max Power',
          value: '${session.maxPower} W',
          color: const Color(0xFFEAB308),
        ),
      if (session.normalizedPower != null)
        _MetricCard(
          icon: Icons.trending_up,
          label: 'NP',
          value: '${session.normalizedPower} W',
          color: const Color(0xFFA855F7),
        ),
      if (session.avgCadence != null)
        _MetricCard(
          icon: Icons.rotate_right,
          label: 'Cadence',
          value: '${session.avgCadence} rpm',
          color: const Color(0xFF06B6D4),
        ),
      if (session.leftRightBalance != null)
        _MetricCard(
          icon: Icons.balance,
          label: 'L/R Balance',
          value:
              '${(session.leftRightBalance! * 100).round()}/${100 - (session.leftRightBalance! * 100).round()}',
          color: const Color(0xFF10B981),
        ),
      if (session.avgSpeed != null && session.avgSpeed! > 0)
        _MetricCard(
          icon: Icons.speed,
          label: 'Avg Speed',
          value: '${(session.avgSpeed! * 3.6).toStringAsFixed(1)} km/h',
          color: const Color(0xFF8B5CF6),
        ),
      if (session.elevationGain != null && session.elevationGain! > 0)
        _MetricCard(
          icon: Icons.terrain,
          label: 'Elevation',
          value: '${session.elevationGain!.round()} m',
          color: const Color(0xFFD97706),
        ),
    ];
  }

  List<Widget> _buildRunningMetrics(
    double totalDistance,
    Duration totalDuration,
  ) {
    if (session.sport != SportType.running) return [];

    // Calculate pace for running
    String? pace;
    if (totalDistance > 0 && totalDuration.inSeconds > 0) {
      final paceSecPerKm = totalDuration.inSeconds / (totalDistance / 1000);
      final mins = (paceSecPerKm / 60).floor();
      final secs = (paceSecPerKm % 60).round();
      pace = '$mins:${secs.toString().padLeft(2, '0')}/km';
    }

    return [
      if (pace != null)
        _MetricCard(
          icon: Icons.speed,
          label: 'Avg Pace',
          value: pace,
          color: const Color(0xFF8B5CF6),
        ),
      if (session.avgCadence != null)
        _MetricCard(
          icon: Icons.directions_run,
          label: 'Cadence',
          value: '${session.avgCadence} spm',
          color: const Color(0xFF06B6D4),
        ),
      if (session.elevationGain != null && session.elevationGain! > 0)
        _MetricCard(
          icon: Icons.terrain,
          label: 'Elevation',
          value: '${session.elevationGain!.round()} m',
          color: const Color(0xFFD97706),
        ),
    ];
  }

  List<Widget> _buildSwimmingMetrics() {
    if (session.sport != SportType.swimming) return [];

    // Calculate total strokes and SWOLF from laps
    final totalStrokes = laps
        .where((l) => l.totalStrokes != null)
        .fold<int>(0, (sum, l) => sum + l.totalStrokes!);

    final swolfValues = laps
        .where((l) => l.swolf != null && !l.isRest)
        .map((l) => l.swolf!)
        .toList();
    final avgSwolf = swolfValues.isNotEmpty
        ? (swolfValues.reduce((a, b) => a + b) / swolfValues.length).round()
        : null;

    return [
      if (session.avgSwimPace != null)
        _MetricCard(
          icon: Icons.speed,
          label: 'Avg Pace',
          value: session.avgSwimPace!,
          color: const Color(0xFF8B5CF6),
        ),
      if (session.poolLength != null)
        _MetricCard(
          icon: Icons.pool,
          label: 'Pool',
          value: '${session.poolLength}m',
          color: const Color(0xFF3B82F6),
        ),
      if (avgSwolf != null)
        _MetricCard(
          icon: Icons.waves,
          label: 'Avg SWOLF',
          value: '$avgSwolf',
          color: const Color(0xFF06B6D4),
        ),
      if (totalStrokes > 0)
        _MetricCard(
          icon: Icons.gesture,
          label: 'Total Strokes',
          value: '$totalStrokes',
          color: const Color(0xFF10B981),
        ),
    ];
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      final mins = d.inMinutes % 60;
      final secs = d.inSeconds % 60;
      return '${d.inHours}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
    return '${meters.round()} m';
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (MediaQuery.of(context).size.width - 44) / 2,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF27272A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[400]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _LapCard extends StatelessWidget {
  final WorkoutLap lap;
  final int index;
  final SportType sport;

  const _LapCard({required this.lap, required this.index, required this.sport});

  @override
  Widget build(BuildContext context) {
    final isSwimming = sport == SportType.swimming;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lap.isRest
            ? const Color(0xFF27272A).withOpacity(0.5)
            : const Color(0xFF27272A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: lap.isRest
              ? Colors.grey.withOpacity(0.2)
              : const Color(0xFF00D4FF).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  lap.setDescription ??
                      '${isSwimming ? "Set" : "Lap"} ${index + 1}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF00D4FF),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _formatDuration(lap.duration),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Metrics row
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _LapMetric(
                label: 'Distance',
                value: _formatDistance(lap.distanceMeters),
              ),
              if (lap.pace != null)
                _LapMetric(
                  label: isSwimming ? 'Pace/100m' : 'Pace',
                  value: lap.pace!,
                ),
              if (lap.avgHr != null)
                _LapMetric(label: 'HR', value: '${lap.avgHr}'),
              if (lap.swolf != null)
                _LapMetric(label: 'SWOLF', value: '${lap.swolf}'),
              if (lap.totalStrokes != null)
                _LapMetric(label: 'Strokes', value: '${lap.totalStrokes}'),
              if (lap.dps != null)
                _LapMetric(label: 'DPS', value: lap.dps!.toStringAsFixed(2)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
    return '${meters.round()}m';
  }
}

class _LapMetric extends StatelessWidget {
  final String label;
  final String value;

  const _LapMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
        ),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
