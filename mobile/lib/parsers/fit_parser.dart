import 'dart:typed_data';
import 'package:fit_tool/fit_tool.dart';
import '../models/workout.dart';

/// Parse FIT files from Garmin/Wahoo devices
class FitParser {
  /// Parse a FIT file from bytes
  Future<WorkoutAnalysis?> parseBytes(List<int> bytes) async {
    try {
      final fitFile = FitFile.fromBytes(Uint8List.fromList(bytes));

      // Extract session data
      WorkoutSession? session;
      final laps = <WorkoutLap>[];
      final records = <RecordPoint>[];

      int lapIndex = 0;
      DateTime? startTime;

      for (final record in fitFile.records) {
        final message = record.message;

        // Session message
        if (message is SessionMessage) {
          session = _extractSession(message);
          if (message.startTime != null) {
            startTime = DateTime.fromMillisecondsSinceEpoch(
              message.startTime! * 1000,
            );
          }
        }

        // Lap message
        if (message is LapMessage) {
          final lap = _extractLap(message, lapIndex);
          if (lap != null) {
            laps.add(lap);
            lapIndex++;
          }
        }

        // Record message (per-second data for charts and maps)
        if (message is RecordMessage) {
          // Use first record timestamp as startTime if session not yet found
          if (startTime == null && message.timestamp != null) {
            startTime = DateTime.fromMillisecondsSinceEpoch(
              message.timestamp! * 1000,
            );
          }
          final recordPoint = _extractRecordPoint(message, startTime);
          if (recordPoint != null) {
            records.add(recordPoint);
          }
        }
      }

      if (session == null) {
        // Create a basic session from laps if not found
        session = _createSessionFromLaps(laps);
      }

      // Debug: Log record extraction stats
      final hrCount = records.where((r) => r.heartRate != null).length;
      final gpsCount = records.where((r) => r.hasGps).length;
      final powerCount = records
          .where((r) => r.power != null && r.power! > 0)
          .length;
      print(
        'FIT Parser: ${records.length} records, $hrCount with HR, $powerCount with power, $gpsCount with GPS',
      );

      return WorkoutAnalysis(
        session: session,
        laps: laps,
        records: records,
        analyzedAt: DateTime.now(),
        markdownReport: _generateReport(session, laps),
      );
    } catch (e) {
      // Error parsing FIT file
      return null;
    }
  }

  /// Extract per-second record data for charts and maps
  RecordPoint? _extractRecordPoint(RecordMessage msg, DateTime? startTime) {
    // Calculate elapsed time
    Duration elapsed = Duration.zero;
    if (msg.timestamp != null && startTime != null) {
      final recordTime = DateTime.fromMillisecondsSinceEpoch(
        msg.timestamp! * 1000,
      );
      elapsed = recordTime.difference(startTime);
    }

    // Get GPS coordinates
    // Note: fit_tool already converts semicircles to degrees
    double? lat;
    double? lon;
    if (msg.positionLat != null && msg.positionLong != null) {
      lat = msg.positionLat;
      lon = msg.positionLong;
    }

    return RecordPoint(
      elapsed: elapsed,
      heartRate: msg.heartRate?.round(),
      power: msg.power?.toDouble(),
      speed: msg.speed,
      cadence: msg.cadence?.toDouble(),
      altitude: msg.altitude,
      latitude: lat,
      longitude: lon,
      distance: msg.distance,
    );
  }

  WorkoutSession _extractSession(SessionMessage msg) {
    final sport = _parseSport(msg.sport);

    // Convert timestamp to DateTime
    DateTime? startTime;
    if (msg.startTime != null) {
      startTime = DateTime.fromMillisecondsSinceEpoch(msg.startTime! * 1000);
    }

    // Get normalized power - might be in avgPower or a separate field
    int? normPower;
    try {
      normPower = msg.normalizedPower?.round();
    } catch (_) {
      // Try alternative field access if available
    }

    // Get left/right balance - check for available field
    double? lrBalance;
    try {
      final balance = msg.leftRightBalance;
      if (balance != null && balance > 0) {
        // Convert to 0-1 range (left percentage)
        lrBalance = balance / 100.0;
      }
    } catch (_) {}

    // Running dynamics - fit_tool library doesn't expose these on SessionMessage
    // They would need to be calculated from RecordMessage data
    // For now, these will be null
    final double? gct = null;
    final double? vertOsc = null;
    final double? strideLen = null;
    final double? vertRatio = null;

    // Calculate swim pace (per 100m)
    String? swimPace;
    if (sport == SportType.swimming) {
      final distance = msg.totalDistance ?? 0;
      final duration = msg.totalElapsedTime ?? 0;
      if (distance > 0 && duration > 0) {
        final pacePer100 = (duration / (distance / 100));
        final mins = (pacePer100 / 60).floor();
        final secs = (pacePer100 % 60).round();
        swimPace = '$mins:${secs.toString().padLeft(2, '0')}/100m';
      }
    }

    return WorkoutSession(
      activityName: msg.eventType?.toString() ?? 'Workout',
      sport: sport,
      startTime: startTime,
      totalDuration: Duration(
        milliseconds: ((msg.totalElapsedTime ?? 0) * 1000).round(),
      ),
      totalDistanceMeters: msg.totalDistance ?? 0,
      avgHr: msg.avgHeartRate?.round(),
      maxHr: msg.maxHeartRate?.round(),
      avgPower: msg.avgPower?.round(),
      maxPower: msg.maxPower?.round(),
      normalizedPower: normPower,
      calories: msg.totalCalories?.round(),
      avgCadence: msg.avgCadence?.round(),
      maxCadence: msg.maxCadence?.round(),
      leftRightBalance: lrBalance,
      avgSpeed: msg.avgSpeed,
      maxSpeed: msg.maxSpeed,
      elevationGain: msg.totalAscent?.toDouble(),
      avgGroundContactTime: gct,
      avgVerticalOscillation: vertOsc,
      avgStrideLength: strideLen,
      avgVerticalRatio: vertRatio,
      avgSwimPace: swimPace,
      poolLength: msg.poolLength?.round(),
      source: 'FIT',
    );
  }

  WorkoutLap? _extractLap(LapMessage msg, int index) {
    final durationSec = msg.totalElapsedTime ?? 0;
    if (durationSec < 3) return null; // Skip very short laps

    final distance = msg.totalDistance ?? 0;
    final avgSpeed = msg.avgSpeed ?? 0;

    String? pace;
    if (avgSpeed > 0) {
      final paceSecPerKm = 1000 / avgSpeed;
      final mins = (paceSecPerKm / 60).floor();
      final secs = (paceSecPerKm % 60).round();
      pace = '$mins:${secs.toString().padLeft(2, '0')}';
    }

    return WorkoutLap(
      index: index,
      duration: Duration(milliseconds: (durationSec * 1000).round()),
      distanceMeters: distance,
      avgHr: msg.avgHeartRate?.round(),
      maxHr: msg.maxHeartRate?.round(),
      pace: pace,
      totalStrokes: msg.totalStrokes?.round(),
      strokeType: msg.swimStroke?.toString(),
      isRest: distance == 0,
      calories: msg.totalCalories?.round(),
    );
  }

  SportType _parseSport(Sport? sport) {
    if (sport == null) return SportType.unknown;

    switch (sport) {
      case Sport.running:
        return SportType.running;
      case Sport.cycling:
        return SportType.cycling;
      case Sport.swimming:
        return SportType.swimming;
      default:
        return SportType.unknown;
    }
  }

  WorkoutSession _createSessionFromLaps(List<WorkoutLap> laps) {
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
        : null;
    final maxHr = hrValues.isNotEmpty
        ? hrValues.reduce((a, b) => a > b ? a : b)
        : null;

    return WorkoutSession(
      activityName: 'Workout',
      sport: SportType.unknown,
      totalDuration: totalDuration,
      totalDistanceMeters: totalDistance,
      avgHr: avgHr,
      maxHr: maxHr,
      source: 'FIT',
    );
  }

  String _generateReport(WorkoutSession session, List<WorkoutLap> laps) {
    final buffer = StringBuffer();

    // Header
    final emoji = switch (session.sport) {
      SportType.swimming => '🏊',
      SportType.cycling => '🚴',
      SportType.running => '🏃',
      _ => '🏋️',
    };

    buffer.writeln(
      '# $emoji ${session.sport.name.toUpperCase()}: ${session.activityName ?? "Workout"}',
    );
    buffer.writeln();

    if (session.startTime != null) {
      buffer.writeln('**Date:** ${session.startTime}');
      buffer.writeln();
    }

    // Summary
    buffer.writeln('## 📊 Summary');
    buffer.writeln('| Metric | Value |');
    buffer.writeln('|--------|-------|');
    buffer.writeln(
      '| **Duration** | ${_formatDuration(session.totalDuration)} |',
    );
    buffer.writeln(
      '| **Distance** | ${_formatDistance(session.totalDistanceMeters)} |',
    );
    if (session.avgHr != null) {
      buffer.writeln('| **Avg HR** | ${session.avgHr} bpm |');
    }
    if (session.maxHr != null) {
      buffer.writeln('| **Max HR** | ${session.maxHr} bpm |');
    }
    if (session.calories != null) {
      buffer.writeln('| **Calories** | ${session.calories} kcal |');
    }
    buffer.writeln();

    // Power section for cycling
    if (session.sport == SportType.cycling && session.avgPower != null) {
      buffer.writeln('## ⚡ Power');
      buffer.writeln('| Metric | Value |');
      buffer.writeln('|--------|-------|');
      buffer.writeln('| **Avg Power** | ${session.avgPower} W |');
      if (session.maxPower != null) {
        buffer.writeln('| **Max Power** | ${session.maxPower} W |');
      }
      if (session.normalizedPower != null) {
        buffer.writeln(
          '| **Normalized Power** | ${session.normalizedPower} W |',
        );
      }
      if (session.intensityFactor != null) {
        buffer.writeln(
          '| **Intensity Factor** | ${session.intensityFactor!.toStringAsFixed(2)} |',
        );
      }
      if (session.tss != null) {
        buffer.writeln('| **TSS** | ${session.tss} |');
      }
      buffer.writeln();
    }

    // Cadence section
    if (session.avgCadence != null) {
      buffer.writeln('## 🔄 Cadence');
      buffer.writeln('| Metric | Value |');
      buffer.writeln('|--------|-------|');
      final unit = session.sport == SportType.cycling ? 'rpm' : 'spm';
      buffer.writeln('| **Avg Cadence** | ${session.avgCadence} $unit |');
      if (session.maxCadence != null) {
        buffer.writeln('| **Max Cadence** | ${session.maxCadence} $unit |');
      }
      buffer.writeln();
    }

    // L/R Balance (cycling)
    if (session.leftRightBalance != null &&
        session.sport == SportType.cycling) {
      final left = (session.leftRightBalance! * 100).round();
      final right = 100 - left;
      buffer.writeln('## ⚖️ Left/Right Balance');
      buffer.writeln('**$left% L** / **$right% R**');
      buffer.writeln();
    }

    // Speed
    if (session.avgSpeed != null && session.avgSpeed! > 0) {
      buffer.writeln('## 🏎️ Speed');
      buffer.writeln('| Metric | Value |');
      buffer.writeln('|--------|-------|');
      final avgKmh = (session.avgSpeed! * 3.6);
      buffer.writeln('| **Avg Speed** | ${avgKmh.toStringAsFixed(1)} km/h |');
      if (session.maxSpeed != null) {
        final maxKmh = (session.maxSpeed! * 3.6);
        buffer.writeln('| **Max Speed** | ${maxKmh.toStringAsFixed(1)} km/h |');
      }
      buffer.writeln();
    }

    // Elevation
    if (session.elevationGain != null && session.elevationGain! > 0) {
      buffer.writeln('## ⛰️ Elevation');
      buffer.writeln(
        '**Total Elevation Gain:** ${session.elevationGain!.round()} m',
      );
      buffer.writeln();
    }

    // Laps
    buffer.writeln('## 🔄 Laps');
    buffer.writeln();

    for (final lap in laps) {
      final parts = <String>[];
      parts.add(
        '**${_formatDistance(lap.distanceMeters)}** in ${_formatDuration(lap.duration)}',
      );
      if (lap.pace != null) parts.add('Pace ${lap.pace}/km');
      if (lap.avgHr != null) parts.add('HR ${lap.avgHr} avg');

      buffer.writeln('**Lap ${lap.index + 1}:** ${parts.join(' | ')}  ');
      buffer.writeln();
    }

    buffer.writeln('---');
    buffer.writeln('*Analyzed offline with Workout Analyzer*');

    return buffer.toString();
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
    return '${meters.round()} m';
  }
}
