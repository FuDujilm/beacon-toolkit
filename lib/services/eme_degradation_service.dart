import 'dart:math' as math;

import '../models/eme_degradation.dart';

class EmeDegradationService {
  static const String sourceName = '本地 EME 退化估算';
  static const double referenceDistanceKm = 356400;
  static const double defaultFrequencyMhz = 144;
  static const double defaultSystemNoiseTemperatureK = 80;
  static const double skyNoiseMinK = 200;
  static const String skyNoiseModel = '低分辨率银河背景近似模型，预留 Haslam 408 MHz 降采样表接口';

  EmeDegradationReport calculate({
    DateTime? time,
    double frequencyMhz = defaultFrequencyMhz,
    double systemNoiseTemperatureK = defaultSystemNoiseTemperatureK,
  }) {
    final calculatedAt = time ?? DateTime.now().toUtc();
    final moon = _moonPosition(calculatedAt);
    final distance = moon.distanceKm;
    final rangeDegradation = 40 * _log10(distance / referenceDistanceKm);
    final galactic =
        _equatorialToGalactic(moon.rightAscensionDeg, moon.declinationDeg);
    final skyTemperature = _estimateSkyTemperatureK(
      galacticLatitudeDeg: galactic.latitudeDeg,
      frequencyMhz: frequencyMhz,
    );
    final skyNoiseDegradation = 10 *
        _log10(
          (skyTemperature + systemNoiseTemperatureK) /
              (skyNoiseMinK + systemNoiseTemperatureK),
        );
    return EmeDegradationReport(
      sourceName: sourceName,
      calculatedAt: calculatedAt,
      moonDistanceKm: distance,
      referenceDistanceKm: referenceDistanceKm,
      rangeDegradationDb: rangeDegradation,
      skyNoiseDegradationDb: skyNoiseDegradation < 0 ? 0 : skyNoiseDegradation,
      skyTemperatureK: skyTemperature,
      skyNoiseMinK: skyNoiseMinK,
      systemNoiseTemperatureK: systemNoiseTemperatureK,
      frequencyMhz: frequencyMhz,
      galacticLongitudeDeg: galactic.longitudeDeg,
      galacticLatitudeDeg: galactic.latitudeDeg,
      skyNoiseModel: skyNoiseModel,
    );
  }

  _MoonPosition _moonPosition(DateTime time) {
    final jd = _julianDay(time);
    final days = jd - 2451543.5;

    final meanAnomaly = _normalizeDegrees(115.3654 + 13.0649929509 * days);
    final meanLongitude = _normalizeDegrees(218.316 + 13.176396 * days);
    const eccentricity = 0.0549;
    final eccentricAnomaly = _solveKepler(
      _degreesToRadians(meanAnomaly),
      eccentricity,
    );
    const semiMajorAxisKm = 384400.0;
    final distanceKm =
        semiMajorAxisKm * (1 - eccentricity * math.cos(eccentricAnomaly));
    final equationOfCenter = 6.289 * math.sin(_degreesToRadians(meanAnomaly));
    final eclipticLongitude =
        _normalizeDegrees(meanLongitude + equationOfCenter);
    const obliquity = 23.4397;
    final longitudeRad = _degreesToRadians(eclipticLongitude);
    final obliquityRad = _degreesToRadians(obliquity);
    final rightAscension = _normalizeDegrees(
      _radiansToDegrees(
        math.atan2(
          math.sin(longitudeRad) * math.cos(obliquityRad),
          math.cos(longitudeRad),
        ),
      ),
    );
    final declination = _radiansToDegrees(
      math.asin(math.sin(longitudeRad) * math.sin(obliquityRad)),
    );
    return _MoonPosition(
      distanceKm: distanceKm,
      rightAscensionDeg: rightAscension,
      declinationDeg: declination,
    );
  }

  _GalacticCoordinate _equatorialToGalactic(
    double rightAscensionDeg,
    double declinationDeg,
  ) {
    const northGalacticPoleRaDeg = 192.85948;
    const northGalacticPoleDecDeg = 27.12825;
    const ascendingNodeDeg = 32.93192;
    final ra = _degreesToRadians(rightAscensionDeg);
    final dec = _degreesToRadians(declinationDeg);
    final poleRa = _degreesToRadians(northGalacticPoleRaDeg);
    final poleDec = _degreesToRadians(northGalacticPoleDecDeg);
    final node = _degreesToRadians(ascendingNodeDeg);

    final latitude = math.asin(
      math.sin(dec) * math.sin(poleDec) +
          math.cos(dec) * math.cos(poleDec) * math.cos(ra - poleRa),
    );
    final y = math.sin(dec) * math.cos(poleDec) -
        math.cos(dec) * math.sin(poleDec) * math.cos(ra - poleRa);
    final x = math.cos(dec) * math.sin(ra - poleRa);
    final longitude = _normalizeDegrees(
      _radiansToDegrees(math.atan2(y, x) + node),
    );
    return _GalacticCoordinate(
      longitudeDeg: longitude,
      latitudeDeg: _radiansToDegrees(latitude),
    );
  }

  double _estimateSkyTemperatureK({
    required double galacticLatitudeDeg,
    required double frequencyMhz,
  }) {
    final latitudeFactor =
        math.exp(-math.pow(galacticLatitudeDeg.abs() / 18, 1.7).toDouble());
    final t408 = 28 + 1050 * latitudeFactor;
    final scaled = t408 * math.pow(frequencyMhz / 408, -2.55);
    return scaled < skyNoiseMinK ? skyNoiseMinK : scaled.toDouble();
  }

  double _julianDay(DateTime value) {
    final utc = value.toUtc();
    var year = utc.year;
    var month = utc.month;
    final day =
        utc.day + (utc.hour + (utc.minute + (utc.second / 60)) / 60) / 24;
    if (month <= 2) {
      year -= 1;
      month += 12;
    }
    final a = year ~/ 100;
    final b = 2 - a + (a ~/ 4);
    return (365.25 * (year + 4716)).floor() +
        (30.6001 * (month + 1)).floor() +
        day +
        b -
        1524.5;
  }

  double _solveKepler(double meanAnomaly, double eccentricity) {
    var eccentricAnomaly = meanAnomaly;
    for (var index = 0; index < 8; index++) {
      eccentricAnomaly = eccentricAnomaly -
          (eccentricAnomaly -
                  eccentricity * math.sin(eccentricAnomaly) -
                  meanAnomaly) /
              (1 - eccentricity * math.cos(eccentricAnomaly));
    }
    return eccentricAnomaly;
  }

  double _normalizeDegrees(double value) {
    final result = value % 360;
    return result < 0 ? result + 360 : result;
  }

  double _degreesToRadians(double value) => value * math.pi / 180;

  double _radiansToDegrees(double value) => value * 180 / math.pi;

  double _log10(double value) => math.log(value) / math.ln10;
}

class _MoonPosition {
  final double distanceKm;
  final double rightAscensionDeg;
  final double declinationDeg;

  const _MoonPosition({
    required this.distanceKm,
    required this.rightAscensionDeg,
    required this.declinationDeg,
  });
}

class _GalacticCoordinate {
  final double longitudeDeg;
  final double latitudeDeg;

  const _GalacticCoordinate({
    required this.longitudeDeg,
    required this.latitudeDeg,
  });
}
