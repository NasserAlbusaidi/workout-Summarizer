import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/workout.dart';

/// GPS route map widget using OpenStreetMap
class RouteMapWidget extends StatelessWidget {
  final List<RecordPoint> records;
  final bool colorByHr; // If true, color route by heart rate

  const RouteMapWidget({
    super.key,
    required this.records,
    this.colorByHr = true,
  });

  @override
  Widget build(BuildContext context) {
    // Get GPS points
    final gpsPoints = records.where((r) => r.hasGps).toList();
    if (gpsPoints.isEmpty) {
      return const Center(child: Text('No GPS data available'));
    }

    // Build route coordinates
    final routeCoords = gpsPoints
        .map((r) => LatLng(r.latitude!, r.longitude!))
        .toList();

    // Calculate bounds
    final bounds = LatLngBounds.fromPoints(routeCoords);
    final center = bounds.center;

    // Debug GPS
    print(
      'Map: ${gpsPoints.length} GPS points, center: ${center.latitude}, ${center.longitude}',
    );
    print(
      'Map: First GPS: ${routeCoords.first.latitude}, ${routeCoords.first.longitude}',
    );

    return FlutterMap(
      options: MapOptions(
        center: center,
        zoom: 14,
        interactiveFlags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
      ),
      children: [
        // OpenStreetMap tiles
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.workout.analyzer',
        ),
        // Route polyline
        PolylineLayer(
          polylines: colorByHr
              ? _buildColoredRoute(gpsPoints)
              : [
                  Polyline(
                    points: routeCoords,
                    color: const Color(0xFF3B82F6),
                    strokeWidth: 4,
                  ),
                ],
        ),
        // Start and end markers
        MarkerLayer(
          markers: [
            // Start marker (green)
            Marker(
              point: routeCoords.first,
              width: 30,
              height: 30,
              builder: (ctx) => Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Center(
                  child: Icon(Icons.play_arrow, color: Colors.white, size: 16),
                ),
              ),
            ),
            // End marker (red)
            Marker(
              point: routeCoords.last,
              width: 30,
              height: 30,
              builder: (ctx) => Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Center(
                  child: Icon(Icons.flag, color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Build route segments colored by heart rate
  List<Polyline> _buildColoredRoute(List<RecordPoint> gpsPoints) {
    final polylines = <Polyline>[];

    // Calculate HR range for coloring
    final hrValues = gpsPoints
        .where((r) => r.heartRate != null)
        .map((r) => r.heartRate!)
        .toList();
    if (hrValues.isEmpty) {
      // No HR data, return single blue line
      return [
        Polyline(
          points: gpsPoints
              .map((r) => LatLng(r.latitude!, r.longitude!))
              .toList(),
          color: const Color(0xFF3B82F6),
          strokeWidth: 4,
        ),
      ];
    }

    final minHr = hrValues.reduce((a, b) => a < b ? a : b);
    final maxHr = hrValues.reduce((a, b) => a > b ? a : b);
    final hrRange = maxHr - minHr;

    // Build segments with color based on HR
    for (int i = 0; i < gpsPoints.length - 1; i++) {
      final start = gpsPoints[i];
      final end = gpsPoints[i + 1];

      final hr = start.heartRate ?? minHr;
      final ratio = hrRange > 0 ? (hr - minHr) / hrRange : 0.5;

      // Color from blue (low) to yellow to red (high)
      final color = Color.lerp(
        const Color(0xFF3B82F6), // Blue
        const Color(0xFFEF4444), // Red
        ratio,
      )!;

      polylines.add(
        Polyline(
          points: [
            LatLng(start.latitude!, start.longitude!),
            LatLng(end.latitude!, end.longitude!),
          ],
          color: color,
          strokeWidth: 4,
        ),
      );
    }

    return polylines;
  }
}

/// Map section widget for analysis screen
class WorkoutMapSection extends StatelessWidget {
  final WorkoutAnalysis analysis;

  const WorkoutMapSection({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    print(
      'WorkoutMapSection: hasGpsData=${analysis.hasGpsData}, records=${analysis.records.length}',
    );

    if (!analysis.hasGpsData) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          '🗺️ Route',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Container(
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: RouteMapWidget(records: analysis.records, colorByHr: true),
        ),
        const SizedBox(height: 8),
        Text(
          'Route colored by heart rate (blue=low, red=high)',
          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
        ),
      ],
    );
  }
}
