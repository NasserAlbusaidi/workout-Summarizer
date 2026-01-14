import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/workout.dart';

/// Heart rate over time line chart
class HeartRateChart extends StatelessWidget {
  final List<RecordPoint> records;
  final int? maxHr;

  const HeartRateChart({super.key, required this.records, this.maxHr});

  @override
  Widget build(BuildContext context) {
    // Filter records with HR data and sample for performance
    final hrRecords = records.where((r) => r.heartRate != null).toList();
    if (hrRecords.isEmpty) {
      return const Center(child: Text('No heart rate data'));
    }

    // Sample data if too many points (keep max 200 for performance)
    final sampledRecords = _sampleRecords(hrRecords, 200);

    // Calculate bounds
    final minX = 0.0;
    final maxX = sampledRecords.last.elapsed.inSeconds / 60.0;
    final minY = _getMinY(sampledRecords);
    final maxY = _getMaxY(sampledRecords, maxHr);

    // Debug
    print(
      'HR Chart: ${sampledRecords.length} points, X: $minX-$maxX, Y: $minY-$maxY',
    );

    return Container(
      height: 200,
      padding: const EdgeInsets.only(right: 16, top: 16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 20,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: _getTimeInterval(sampledRecords),
                getTitlesWidget: (value, meta) {
                  final mins = value.toInt();
                  if (mins % 5 == 0) {
                    return Text(
                      '${mins}m',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 20,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: sampledRecords.map((r) {
                final mins = r.elapsed.inSeconds / 60.0;
                return FlSpot(mins, r.heartRate!.toDouble());
              }).toList(),
              isCurved: true,
              curveSmoothness: 0.2,
              color: const Color(0xFFEF4444),
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFFEF4444).withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<RecordPoint> _sampleRecords(List<RecordPoint> records, int maxPoints) {
    if (records.length <= maxPoints) return records;
    final step = records.length / maxPoints;
    return List.generate(maxPoints, (i) => records[(i * step).floor()]);
  }

  double _getTimeInterval(List<RecordPoint> records) {
    if (records.isEmpty) return 1;
    final maxMins = records.last.elapsed.inMinutes;
    if (maxMins < 10) return 1;
    if (maxMins < 30) return 5;
    if (maxMins < 60) return 10;
    return 15;
  }

  double _getMinY(List<RecordPoint> records) {
    final minHr = records
        .map((r) => r.heartRate!)
        .reduce((a, b) => a < b ? a : b);
    return (minHr - 10).clamp(0, 200).toDouble();
  }

  double _getMaxY(List<RecordPoint> records, int? maxHr) {
    final dataMax = records
        .map((r) => r.heartRate!)
        .reduce((a, b) => a > b ? a : b);
    final max = maxHr ?? dataMax;
    return (max + 10).clamp(100, 220).toDouble();
  }
}

/// Power over time chart (for cycling)
class PowerChart extends StatelessWidget {
  final List<RecordPoint> records;

  const PowerChart({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    final powerRecords = records
        .where((r) => r.power != null && r.power! > 0)
        .toList();
    if (powerRecords.isEmpty) {
      return const Center(child: Text('No power data'));
    }

    final sampledRecords = _sampleRecords(powerRecords, 200);

    return Container(
      height: 200,
      padding: const EdgeInsets.only(right: 16, top: 16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 50,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final mins = value.toInt();
                  if (mins % 5 == 0) {
                    return Text(
                      '${mins}m',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                interval: 50,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}W',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minY: 0,
          lineBarsData: [
            LineChartBarData(
              spots: sampledRecords.map((r) {
                final mins = r.elapsed.inSeconds / 60.0;
                return FlSpot(mins, r.power!);
              }).toList(),
              isCurved: true,
              curveSmoothness: 0.2,
              color: const Color(0xFFEAB308),
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFFEAB308).withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<RecordPoint> _sampleRecords(List<RecordPoint> records, int maxPoints) {
    if (records.length <= maxPoints) return records;
    final step = records.length / maxPoints;
    return List.generate(maxPoints, (i) => records[(i * step).floor()]);
  }
}

/// Chart section widget for analysis screen
class WorkoutChartsSection extends StatelessWidget {
  final WorkoutAnalysis analysis;

  const WorkoutChartsSection({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    final hasHr = analysis.records.any((r) => r.heartRate != null);
    final hasPower = analysis.records.any(
      (r) => r.power != null && r.power! > 0,
    );

    if (!hasHr && !hasPower) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          '📈 Charts',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        if (hasHr) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.favorite,
                      color: Color(0xFFEF4444),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Heart Rate',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                HeartRateChart(
                  records: analysis.records,
                  maxHr: analysis.session.maxHr,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (hasPower) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt, color: Color(0xFFEAB308), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Power',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                PowerChart(records: analysis.records),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
