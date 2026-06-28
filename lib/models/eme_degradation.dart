class EmeDegradationReport {
  final String sourceName;
  final DateTime calculatedAt;
  final double moonDistanceKm;
  final double referenceDistanceKm;
  final double rangeDegradationDb;
  final double? skyNoiseDegradationDb;
  final double? skyTemperatureK;
  final double? skyNoiseMinK;
  final double? systemNoiseTemperatureK;
  final double? frequencyMhz;
  final double? galacticLongitudeDeg;
  final double? galacticLatitudeDeg;
  final String skyNoiseModel;

  const EmeDegradationReport({
    required this.sourceName,
    required this.calculatedAt,
    required this.moonDistanceKm,
    required this.referenceDistanceKm,
    required this.rangeDegradationDb,
    this.skyNoiseDegradationDb,
    this.skyTemperatureK,
    this.skyNoiseMinK,
    this.systemNoiseTemperatureK,
    this.frequencyMhz,
    this.galacticLongitudeDeg,
    this.galacticLatitudeDeg,
    this.skyNoiseModel = '',
  });

  double get totalDegradationDb {
    return rangeDegradationDb + (skyNoiseDegradationDb ?? 0);
  }

  EmeDegradationLevel get level {
    final value = totalDegradationDb;
    if (value < 1.5) return EmeDegradationLevel.good;
    if (value < 2.5) return EmeDegradationLevel.fair;
    if (value < 4.0) return EmeDegradationLevel.poor;
    return EmeDegradationLevel.veryPoor;
  }

  bool get isPartialEstimate => skyNoiseDegradationDb == null;
}

enum EmeDegradationLevel {
  good,
  fair,
  poor,
  veryPoor,
}
