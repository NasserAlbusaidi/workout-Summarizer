// Core data models for workout analysis

/// Represents a per-second data point from a workout (for charts and maps)
class RecordPoint {
  final Duration elapsed; // Time since workout start
  final int? heartRate; // bpm
  final double? power; // watts
  final double? speed; // m/s
  final double? cadence; // rpm or spm
  final double? altitude; // m
  final double? latitude;
  final double? longitude;
  final double? distance; // cumulative distance in meters

  const RecordPoint({
    required this.elapsed,
    this.heartRate,
    this.power,
    this.speed,
    this.cadence,
    this.altitude,
    this.latitude,
    this.longitude,
    this.distance,
  });

  /// Check if this point has GPS coordinates
  bool get hasGps => latitude != null && longitude != null;

  Map<String, dynamic> toJson() => {
    'elapsedMs': elapsed.inMilliseconds,
    'heartRate': heartRate,
    'power': power,
    'speed': speed,
    'cadence': cadence,
    'altitude': altitude,
    'latitude': latitude,
    'longitude': longitude,
    'distance': distance,
  };

  factory RecordPoint.fromJson(Map<String, dynamic> json) => RecordPoint(
    elapsed: Duration(milliseconds: json['elapsedMs'] ?? 0),
    heartRate: json['heartRate'],
    power: json['power']?.toDouble(),
    speed: json['speed']?.toDouble(),
    cadence: json['cadence']?.toDouble(),
    altitude: json['altitude']?.toDouble(),
    latitude: json['latitude']?.toDouble(),
    longitude: json['longitude']?.toDouble(),
    distance: json['distance']?.toDouble(),
  );
}

/// Represents a single lap or set from a workout
class WorkoutLap {
  final int index;
  final String? setDescription;
  final Duration duration;
  final double distanceMeters;
  final int? avgHr;
  final int? maxHr;
  final String? pace; // formatted pace string
  final int? swolf;
  final int? totalStrokes;
  final double? dps;
  final int? strokeRate;
  final String? strokeType;
  final bool isRest;
  final int? calories;

  const WorkoutLap({
    required this.index,
    this.setDescription,
    required this.duration,
    required this.distanceMeters,
    this.avgHr,
    this.maxHr,
    this.pace,
    this.swolf,
    this.totalStrokes,
    this.dps,
    this.strokeRate,
    this.strokeType,
    this.isRest = false,
    this.calories,
  });

  Map<String, dynamic> toJson() => {
    'index': index,
    'setDescription': setDescription,
    'durationSeconds': duration.inSeconds,
    'distanceMeters': distanceMeters,
    'avgHr': avgHr,
    'maxHr': maxHr,
    'pace': pace,
    'swolf': swolf,
    'totalStrokes': totalStrokes,
    'dps': dps,
    'strokeRate': strokeRate,
    'strokeType': strokeType,
    'isRest': isRest,
    'calories': calories,
  };

  factory WorkoutLap.fromJson(Map<String, dynamic> json) => WorkoutLap(
    index: json['index'] ?? 0,
    setDescription: json['setDescription'],
    duration: Duration(seconds: json['durationSeconds'] ?? 0),
    distanceMeters: (json['distanceMeters'] ?? 0).toDouble(),
    avgHr: json['avgHr'],
    maxHr: json['maxHr'],
    pace: json['pace'],
    swolf: json['swolf'],
    totalStrokes: json['totalStrokes'],
    dps: json['dps']?.toDouble(),
    strokeRate: json['strokeRate'],
    strokeType: json['strokeType'],
    isRest: json['isRest'] ?? false,
    calories: json['calories'],
  );
}

/// Sport type enum
enum SportType { running, cycling, swimming, unknown }

/// Session metadata from a workout file
class WorkoutSession {
  final String? activityName;
  final SportType sport;
  final DateTime? startTime;
  final Duration totalDuration;
  final double totalDistanceMeters;
  final int? avgHr;
  final int? maxHr;
  final int? avgPower;
  final int? maxPower;
  final int? normalizedPower;
  final int? calories;
  final int? poolLength;
  final String? source;

  // Cycling-specific
  final int? avgCadence;
  final int? maxCadence;
  final double? leftRightBalance; // 0.0-1.0 for left balance
  final int? tss; // Training Stress Score
  final double? intensityFactor; // IF
  final double? elevationGain;
  final double? avgSpeed; // m/s
  final double? maxSpeed; // m/s

  // Running-specific dynamics
  final double? avgGroundContactTime; // ms
  final double? avgVerticalOscillation; // mm
  final double? avgStrideLength; // m
  final double? avgVerticalRatio; // %

  // Swimming-specific
  final String? avgSwimPace; // formatted pace per 100m

  const WorkoutSession({
    this.activityName,
    required this.sport,
    this.startTime,
    required this.totalDuration,
    required this.totalDistanceMeters,
    this.avgHr,
    this.maxHr,
    this.avgPower,
    this.maxPower,
    this.normalizedPower,
    this.calories,
    this.poolLength,
    this.source,
    this.avgCadence,
    this.maxCadence,
    this.leftRightBalance,
    this.tss,
    this.intensityFactor,
    this.elevationGain,
    this.avgSpeed,
    this.maxSpeed,
    this.avgGroundContactTime,
    this.avgVerticalOscillation,
    this.avgStrideLength,
    this.avgVerticalRatio,
    this.avgSwimPace,
  });

  Map<String, dynamic> toJson() => {
    'activityName': activityName,
    'sport': sport.name,
    'startTime': startTime?.toIso8601String(),
    'totalDurationSeconds': totalDuration.inSeconds,
    'totalDistanceMeters': totalDistanceMeters,
    'avgHr': avgHr,
    'maxHr': maxHr,
    'avgPower': avgPower,
    'maxPower': maxPower,
    'normalizedPower': normalizedPower,
    'calories': calories,
    'poolLength': poolLength,
    'source': source,
    'avgCadence': avgCadence,
    'maxCadence': maxCadence,
    'leftRightBalance': leftRightBalance,
    'tss': tss,
    'intensityFactor': intensityFactor,
    'elevationGain': elevationGain,
    'avgSpeed': avgSpeed,
    'maxSpeed': maxSpeed,
    'avgGroundContactTime': avgGroundContactTime,
    'avgVerticalOscillation': avgVerticalOscillation,
    'avgStrideLength': avgStrideLength,
    'avgVerticalRatio': avgVerticalRatio,
    'avgSwimPace': avgSwimPace,
  };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
    activityName: json['activityName'],
    sport: SportType.values.firstWhere(
      (e) => e.name == json['sport'],
      orElse: () => SportType.unknown,
    ),
    startTime: json['startTime'] != null
        ? DateTime.parse(json['startTime'])
        : null,
    totalDuration: Duration(seconds: json['totalDurationSeconds'] ?? 0),
    totalDistanceMeters: (json['totalDistanceMeters'] ?? 0).toDouble(),
    avgHr: json['avgHr'],
    maxHr: json['maxHr'],
    avgPower: json['avgPower'],
    maxPower: json['maxPower'],
    normalizedPower: json['normalizedPower'],
    calories: json['calories'],
    poolLength: json['poolLength'],
    source: json['source'],
    avgCadence: json['avgCadence'],
    maxCadence: json['maxCadence'],
    leftRightBalance: json['leftRightBalance']?.toDouble(),
    tss: json['tss'],
    intensityFactor: json['intensityFactor']?.toDouble(),
    elevationGain: json['elevationGain']?.toDouble(),
    avgSpeed: json['avgSpeed']?.toDouble(),
    maxSpeed: json['maxSpeed']?.toDouble(),
    avgGroundContactTime: json['avgGroundContactTime']?.toDouble(),
    avgVerticalOscillation: json['avgVerticalOscillation']?.toDouble(),
    avgStrideLength: json['avgStrideLength']?.toDouble(),
    avgVerticalRatio: json['avgVerticalRatio']?.toDouble(),
    avgSwimPace: json['avgSwimPace'],
  );
}

/// Complete workout analysis result
class WorkoutAnalysis {
  final WorkoutSession session;
  final List<WorkoutLap> laps;
  final List<RecordPoint> records; // Per-second data for charts and maps
  final DateTime analyzedAt;
  final String? markdownReport;

  const WorkoutAnalysis({
    required this.session,
    required this.laps,
    this.records = const [],
    required this.analyzedAt,
    this.markdownReport,
  });

  /// Check if workout has GPS data for map display
  bool get hasGpsData => records.any((r) => r.hasGps);

  Map<String, dynamic> toJson() => {
    'session': session.toJson(),
    'laps': laps.map((l) => l.toJson()).toList(),
    'records': records.map((r) => r.toJson()).toList(),
    'analyzedAt': analyzedAt.toIso8601String(),
    'markdownReport': markdownReport,
  };

  factory WorkoutAnalysis.fromJson(
    Map<String, dynamic> json,
  ) => WorkoutAnalysis(
    session: WorkoutSession.fromJson(json['session']),
    laps: (json['laps'] as List).map((l) => WorkoutLap.fromJson(l)).toList(),
    records: json['records'] != null
        ? (json['records'] as List).map((r) => RecordPoint.fromJson(r)).toList()
        : [],
    analyzedAt: DateTime.parse(json['analyzedAt']),
    markdownReport: json['markdownReport'],
  );
}
