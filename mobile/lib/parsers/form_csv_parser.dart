import '../models/workout.dart';

/// Parse FORM goggles CSV exports
class FormCsvParser {
  /// Parse FORM CSV from string content
  WorkoutAnalysis? parseString(String csvContent) {
    try {
      final lines = csvContent.split('\n');
      if (lines.length < 5) return null;

      // Parse header section (rows 1-2)
      final session = _parseSessionInfo(lines);

      // Parse data section (row 4 onwards, row 3 is header)
      final laps = _parseLengths(lines, session.poolLength ?? 25);

      return WorkoutAnalysis(
        session: session,
        laps: laps,
        analyzedAt: DateTime.now(),
        markdownReport: _generateReport(session, laps),
      );
    } catch (e) {
      // Error parsing FORM CSV
      return null;
    }
  }

  WorkoutSession _parseSessionInfo(List<String> lines) {
    final headerKeys = lines[0].split(',');
    final headerValues = lines.length > 1 ? lines[1].split(',') : [];

    final info = <String, String>{};
    for (var i = 0; i < headerKeys.length && i < headerValues.length; i++) {
      final key = headerKeys[i].trim();
      final value = headerValues[i].trim();
      if (key.isNotEmpty && value.isNotEmpty) {
        info[key] = value;
      }
    }

    final poolSize = int.tryParse(info['Pool Size'] ?? '25') ?? 25;
    final startTimeStr =
        '${info['Swim Date'] ?? ''} ${info['Swim Start Time'] ?? ''}';

    return WorkoutSession(
      activityName: info['Swim Title']?.isNotEmpty == true
          ? info['Swim Title']
          : 'FORM Swim',
      sport: SportType.swimming,
      startTime: _parseDateTime(startTimeStr),
      totalDuration: Duration.zero, // Will calculate from laps
      totalDistanceMeters: 0, // Will calculate from laps
      poolLength: poolSize,
      source: 'FORM',
    );
  }

  DateTime? _parseDateTime(String str) {
    try {
      // Format: MM/DD/YYYY HH:MM:SSAM/PM
      final parts = str.trim().split(' ');
      if (parts.length < 2) return null;

      final dateParts = parts[0].split('/');
      if (dateParts.length != 3) return null;

      final month = int.parse(dateParts[0]);
      final day = int.parse(dateParts[1]);
      final year = int.parse(dateParts[2]);

      final timeStr = parts[1];
      final isPM = timeStr.toUpperCase().contains('PM');
      final timeParts = timeStr.replaceAll(RegExp(r'[APMapm]'), '').split(':');

      var hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final second = timeParts.length > 2 ? int.parse(timeParts[2]) : 0;

      if (isPM && hour != 12) hour += 12;
      if (!isPM && hour == 12) hour = 0;

      return DateTime(year, month, day, hour, minute, second);
    } catch (e) {
      return null;
    }
  }

  List<WorkoutLap> _parseLengths(List<String> lines, int poolLength) {
    if (lines.length < 5) return [];

    // Row 4 (index 3) is the data header
    final dataHeader = lines[3].split(',');
    final colMap = <String, int>{};
    for (var i = 0; i < dataHeader.length; i++) {
      colMap[dataHeader[i].trim()] = i;
    }

    // Parse data and group by set
    final allLengths = <Map<String, dynamic>>[];

    for (var i = 4; i < lines.length; i++) {
      final row = lines[i].trim();
      if (row.isEmpty) continue;

      final values = row.split(',');
      if (values.length < dataHeader.length) continue;

      String getVal(String col, [String def = '']) {
        final idx = colMap[col];
        if (idx != null && idx < values.length) {
          return values[idx].trim();
        }
        return def;
      }

      final stroke = getVal('Strk', 'REST');
      final lengthM = int.tryParse(getVal('Length (m)', '0')) ?? 0;
      final isRest = stroke == 'REST' || lengthM == 0;

      allLengths.add({
        'setNumber': int.tryParse(getVal('Set #', '0')) ?? 0,
        'setDescription': getVal('Set'),
        'distanceM': lengthM,
        'strokeType': stroke,
        'moveTime': _parseTime(getVal('Move Time', '0:00.00')),
        'restTime': _parseTime(getVal('Rest Time', '0:00.00')),
        'avgHr': int.tryParse(getVal('Avg BPM (moving)', '0')),
        'maxHr': int.tryParse(getVal('Max BPM', '0')),
        'swolf': int.tryParse(getVal('SWOLF', '0')),
        'strokeRate': int.tryParse(getVal('Avg Strk Rate (strk/min)', '0')),
        'strokeCount': int.tryParse(getVal('Strk Count', '0')),
        'dps': double.tryParse(getVal('Avg DPS', '0')),
        'calories': int.tryParse(getVal('Calories', '0')),
        'isRest': isRest,
      });
    }

    // Group lengths by set description
    return _groupLengthsIntoLaps(allLengths);
  }

  double _parseTime(String timeStr) {
    if (timeStr.isEmpty || timeStr == '0:00.00') return 0.0;
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        final mins = double.parse(parts[0]);
        final secs = double.parse(parts[1]);
        return mins * 60 + secs;
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  List<WorkoutLap> _groupLengthsIntoLaps(List<Map<String, dynamic>> lengths) {
    final laps = <WorkoutLap>[];
    String? currentSet;
    var currentLengths = <Map<String, dynamic>>[];
    var lapIndex = 0;

    for (final length in lengths) {
      final setDesc = length['setDescription'] as String?;

      if (setDesc != currentSet && currentLengths.isNotEmpty) {
        final lap = _combineLengths(currentLengths, lapIndex);
        if (lap != null) {
          laps.add(lap);
          lapIndex++;
        }
        currentLengths = [];
      }

      currentSet = setDesc;
      currentLengths.add(length);
    }

    // Don't forget last set
    if (currentLengths.isNotEmpty) {
      final lap = _combineLengths(currentLengths, lapIndex);
      if (lap != null) {
        laps.add(lap);
      }
    }

    return laps;
  }

  WorkoutLap? _combineLengths(List<Map<String, dynamic>> lengths, int index) {
    if (lengths.isEmpty) return null;

    final active = lengths.where((l) => l['isRest'] != true).toList();

    final totalDist = lengths.fold<int>(
      0,
      (sum, l) => sum + (l['distanceM'] as int? ?? 0),
    );
    final totalMove = lengths.fold<double>(
      0,
      (sum, l) => sum + (l['moveTime'] as double? ?? 0),
    );
    final totalRest = lengths.fold<double>(
      0,
      (sum, l) => sum + (l['restTime'] as double? ?? 0),
    );

    final hrValues = active
        .where((l) => (l['avgHr'] as int?) != null && l['avgHr'] > 0)
        .map((l) => l['avgHr'] as int)
        .toList();
    final maxHrValues = active
        .where((l) => (l['maxHr'] as int?) != null && l['maxHr'] > 0)
        .map((l) => l['maxHr'] as int)
        .toList();
    final swolfValues = active
        .where((l) => (l['swolf'] as int?) != null && l['swolf'] > 0)
        .map((l) => l['swolf'] as int)
        .toList();
    final dpsValues = active
        .where((l) => (l['dps'] as double?) != null && l['dps'] > 0)
        .map((l) => l['dps'] as double)
        .toList();

    final avgHr = hrValues.isNotEmpty
        ? (hrValues.reduce((a, b) => a + b) / hrValues.length).round()
        : null;
    final maxHr = maxHrValues.isNotEmpty
        ? maxHrValues.reduce((a, b) => a > b ? a : b)
        : null;
    final avgSwolf = swolfValues.isNotEmpty
        ? (swolfValues.reduce((a, b) => a + b) / swolfValues.length).round()
        : null;
    final avgDps = dpsValues.isNotEmpty
        ? dpsValues.reduce((a, b) => a + b) / dpsValues.length
        : null;

    final totalStrokes = active.fold<int>(
      0,
      (sum, l) => sum + (l['strokeCount'] as int? ?? 0),
    );
    final totalCalories = lengths.fold<int>(
      0,
      (sum, l) => sum + (l['calories'] as int? ?? 0),
    );

    // Calculate pace per 100m
    final avgSpeed = totalMove > 0 ? totalDist / totalMove : 0.0;
    final paceSec = avgSpeed > 0 ? 100 / avgSpeed : 0.0;
    final paceStr = paceSec > 0
        ? '${(paceSec ~/ 60)}:${(paceSec % 60).round().toString().padLeft(2, '0')}'
        : null;

    final first = lengths.first;

    return WorkoutLap(
      index: index,
      setDescription: first['setDescription'],
      duration: Duration(seconds: (totalMove + totalRest).round()),
      distanceMeters: totalDist.toDouble(),
      avgHr: avgHr,
      maxHr: maxHr,
      pace: paceStr,
      swolf: avgSwolf,
      totalStrokes: totalStrokes > 0 ? totalStrokes : null,
      dps: avgDps,
      strokeType: first['strokeType'],
      isRest: totalDist == 0,
      calories: totalCalories > 0 ? totalCalories : null,
    );
  }

  String _generateReport(WorkoutSession session, List<WorkoutLap> laps) {
    final buffer = StringBuffer();

    // Calculate totals
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
    final maxHr = laps
        .where((l) => l.maxHr != null)
        .map((l) => l.maxHr!)
        .fold<int?>(null, (max, hr) => max == null || hr > max ? hr : max);

    // Header
    buffer.writeln('# 🏊 SWIMMING: ${session.activityName ?? "FORM Swim"}');
    buffer.writeln();

    if (session.startTime != null) {
      buffer.writeln('**Date:** ${session.startTime}');
      buffer.writeln();
    }

    // Summary
    buffer.writeln('## 📊 Summary');
    buffer.writeln('| Metric | Value |');
    buffer.writeln('|--------|-------|');
    buffer.writeln('| **Duration** | ${_formatDuration(totalDuration)} |');
    buffer.writeln('| **Distance** | ${_formatDistance(totalDistance)} |');
    if (avgHr != null) {
      buffer.writeln('| **Avg HR** | $avgHr bpm |');
    }
    if (maxHr != null) {
      buffer.writeln('| **Max HR** | $maxHr bpm |');
    }
    buffer.writeln();

    // Sets
    buffer.writeln('## 🔄 Sets');
    buffer.writeln();

    for (final lap in laps) {
      final parts = <String>[];
      parts.add(
        '**${_formatDistance(lap.distanceMeters)}** in ${_formatDuration(lap.duration)}',
      );
      if (lap.pace != null) parts.add('Pace ${lap.pace}/100m');
      if (lap.avgHr != null) parts.add('HR ${lap.avgHr} avg');
      if (lap.swolf != null) parts.add('SWOLF ${lap.swolf}');
      if (lap.totalStrokes != null) parts.add('Strokes ${lap.totalStrokes}');
      if (lap.dps != null) parts.add('DPS ${lap.dps!.toStringAsFixed(2)}');
      if (lap.strokeType != null && lap.strokeType != 'REST') {
        final strokeName = _strokeName(lap.strokeType!);
        parts.add('($strokeName)');
      }

      buffer.writeln(
        '**${lap.setDescription ?? "Set ${lap.index + 1}"}:** ${parts.join(' | ')}  ',
      );
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
    return '${meters.round()}m';
  }

  String _strokeName(String code) {
    return switch (code) {
      'FR' => 'Free',
      'BR' => 'Breast',
      'BA' => 'Back',
      'FL' => 'Fly',
      _ => code,
    };
  }
}
