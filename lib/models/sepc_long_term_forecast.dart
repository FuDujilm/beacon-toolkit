enum SepcForecastKind {
  f107,
  ap,
}

class SepcForecastPoint {
  final String dateLabel;
  final double? observed;
  final double? predicted;

  const SepcForecastPoint({
    required this.dateLabel,
    required this.observed,
    required this.predicted,
  });
}

class SepcLongTermForecast {
  final SepcForecastKind kind;
  final String sourceName;
  final String sourceUrl;
  final double? minY;
  final double? maxY;
  final List<SepcForecastPoint> points;

  const SepcLongTermForecast({
    required this.kind,
    required this.sourceName,
    required this.sourceUrl,
    required this.minY,
    required this.maxY,
    required this.points,
  });

  SepcForecastPoint? get latestPredictedPoint {
    for (final point in points.reversed) {
      if (point.predicted != null) return point;
    }
    return null;
  }
}
