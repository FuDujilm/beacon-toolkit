class SepcKIndexReport {
  final String sourceName;
  final String sourceUrl;
  final String startTime;
  final String endTime;
  final List<SepcKIndexSeries> series;

  const SepcKIndexReport({
    required this.sourceName,
    required this.sourceUrl,
    required this.startTime,
    required this.endTime,
    required this.series,
  });

  SepcKIndexPoint? get latestPoint {
    for (final item in series) {
      for (final point in item.points.reversed) {
        if (point.value != null) return point;
      }
    }
    return null;
  }

  int? get latestValue => latestPoint?.value;
}

class SepcKIndexSeries {
  final String name;
  final List<SepcKIndexPoint> points;

  const SepcKIndexSeries({
    required this.name,
    required this.points,
  });
}

class SepcKIndexPoint {
  final String time;
  final int? value;

  const SepcKIndexPoint({
    required this.time,
    required this.value,
  });
}
