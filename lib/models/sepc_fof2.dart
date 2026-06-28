class SepcFof2Station {
  final String code;
  final String name;
  final double longitude;
  final double latitude;

  const SepcFof2Station({
    required this.code,
    required this.name,
    required this.longitude,
    required this.latitude,
  });
}

class SepcFof2Point {
  final DateTime time;
  final double value;

  const SepcFof2Point({
    required this.time,
    required this.value,
  });
}

class SepcFof2KpPoint {
  final DateTime time;
  final int value;

  const SepcFof2KpPoint({
    required this.time,
    required this.value,
  });
}

class SepcFof2Report {
  final String sourceName;
  final String sourceUrl;
  final SepcFof2Station station;
  final String startTime;
  final String endTime;
  final List<SepcFof2Point> points;
  final List<SepcFof2KpPoint> kpPoints;

  const SepcFof2Report({
    required this.sourceName,
    required this.sourceUrl,
    required this.station,
    required this.startTime,
    required this.endTime,
    required this.points,
    required this.kpPoints,
  });

  SepcFof2Point? get latestPoint {
    if (points.isEmpty) return null;
    return points.last;
  }
}
