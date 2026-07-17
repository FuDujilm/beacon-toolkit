import 'dart:math';

class CoaxCablePreset {
  final String key;
  final String label;
  final double velocityFactor;
  final List<CoaxLossPoint> lossPoints;

  const CoaxCablePreset({
    required this.key,
    required this.label,
    required this.velocityFactor,
    required this.lossPoints,
  });
}

class CoaxLossPoint {
  final double frequencyMHz;
  final double attenuationDbPer100m;

  const CoaxLossPoint({
    required this.frequencyMHz,
    required this.attenuationDbPer100m,
  });
}

class CoaxLossResult {
  final double matchedLossDb;
  final double totalLossDb;
  final double additionalSwrLossDb;
  final double deliveredPowerPercent;
  final double attenuationDbPer100m;

  const CoaxLossResult({
    required this.matchedLossDb,
    required this.totalLossDb,
    required this.additionalSwrLossDb,
    required this.deliveredPowerPercent,
    required this.attenuationDbPer100m,
  });
}

class SwrMetricsResult {
  final double swr;
  final double returnLossDb;
  final double reflectionCoefficient;
  final double reflectedPowerPercent;
  final double mismatchLossDb;

  const SwrMetricsResult({
    required this.swr,
    required this.returnLossDb,
    required this.reflectionCoefficient,
    required this.reflectedPowerPercent,
    required this.mismatchLossDb,
  });
}

class PhysicalToElectricalLengthResult {
  final double wavelengthMeters;
  final double electricalDegrees;
  final double wavelengths;

  const PhysicalToElectricalLengthResult({
    required this.wavelengthMeters,
    required this.electricalDegrees,
    required this.wavelengths,
  });
}

class ElectricalToPhysicalLengthResult {
  final double wavelengthMeters;
  final double physicalLengthMeters;
  final double wavelengths;

  const ElectricalToPhysicalLengthResult({
    required this.wavelengthMeters,
    required this.physicalLengthMeters,
    required this.wavelengths,
  });
}

class QuarterWaveTransformerResult {
  final double requiredCharacteristicImpedanceOhms;
  final double physicalLengthMeters;
  final double electricalLengthDegrees;

  const QuarterWaveTransformerResult({
    required this.requiredCharacteristicImpedanceOhms,
    required this.physicalLengthMeters,
    required this.electricalLengthDegrees,
  });
}

class FerriteCorePreset {
  final String key;
  final String label;
  final double alNanohenriesPerTurnSquared;
  final String recommendedRange;

  const FerriteCorePreset({
    required this.key,
    required this.label,
    required this.alNanohenriesPerTurnSquared,
    required this.recommendedRange,
  });
}

class ChokeTurnsResult {
  final double exactTurns;
  final int minimumWholeTurns;
  final double inductanceMicrohenries;
  final double resultingReactanceOhms;

  const ChokeTurnsResult({
    required this.exactTurns,
    required this.minimumWholeTurns,
    required this.inductanceMicrohenries,
    required this.resultingReactanceOhms,
  });
}

class TransmissionLineCalculatorService {
  static const double _speedOfLightMetersPerSecond = 299792458;

  const TransmissionLineCalculatorService();

  List<CoaxCablePreset> presets() {
    return const [
      CoaxCablePreset(
        key: 'rg58',
        label: 'RG-58',
        velocityFactor: 0.66,
        lossPoints: [
          CoaxLossPoint(frequencyMHz: 10, attenuationDbPer100m: 4.2),
          CoaxLossPoint(frequencyMHz: 50, attenuationDbPer100m: 10.5),
          CoaxLossPoint(frequencyMHz: 145, attenuationDbPer100m: 18.9),
          CoaxLossPoint(frequencyMHz: 435, attenuationDbPer100m: 34.0),
        ],
      ),
      CoaxCablePreset(
        key: 'rg8x',
        label: 'RG-8X',
        velocityFactor: 0.78,
        lossPoints: [
          CoaxLossPoint(frequencyMHz: 10, attenuationDbPer100m: 3.1),
          CoaxLossPoint(frequencyMHz: 50, attenuationDbPer100m: 7.1),
          CoaxLossPoint(frequencyMHz: 145, attenuationDbPer100m: 12.6),
          CoaxLossPoint(frequencyMHz: 435, attenuationDbPer100m: 22.2),
        ],
      ),
      CoaxCablePreset(
        key: 'rg213',
        label: 'RG-213',
        velocityFactor: 0.66,
        lossPoints: [
          CoaxLossPoint(frequencyMHz: 10, attenuationDbPer100m: 2.1),
          CoaxLossPoint(frequencyMHz: 50, attenuationDbPer100m: 4.9),
          CoaxLossPoint(frequencyMHz: 145, attenuationDbPer100m: 8.2),
          CoaxLossPoint(frequencyMHz: 435, attenuationDbPer100m: 14.8),
        ],
      ),
      CoaxCablePreset(
        key: 'lmr240',
        label: 'LMR-240',
        velocityFactor: 0.84,
        lossPoints: [
          CoaxLossPoint(frequencyMHz: 10, attenuationDbPer100m: 2.4),
          CoaxLossPoint(frequencyMHz: 50, attenuationDbPer100m: 5.3),
          CoaxLossPoint(frequencyMHz: 145, attenuationDbPer100m: 8.8),
          CoaxLossPoint(frequencyMHz: 435, attenuationDbPer100m: 16.1),
        ],
      ),
      CoaxCablePreset(
        key: 'lmr400',
        label: 'LMR-400',
        velocityFactor: 0.85,
        lossPoints: [
          CoaxLossPoint(frequencyMHz: 10, attenuationDbPer100m: 1.3),
          CoaxLossPoint(frequencyMHz: 50, attenuationDbPer100m: 2.9),
          CoaxLossPoint(frequencyMHz: 145, attenuationDbPer100m: 4.8),
          CoaxLossPoint(frequencyMHz: 435, attenuationDbPer100m: 8.8),
        ],
      ),
    ];
  }

  List<FerriteCorePreset> ferriteCorePresets() {
    return const [
      FerriteCorePreset(
        key: 'ft140-31',
        label: 'FT-140-31',
        alNanohenriesPerTurnSquared: 1400,
        recommendedRange: '1-30 MHz',
      ),
      FerriteCorePreset(
        key: 'ft240-31',
        label: 'FT-240-31',
        alNanohenriesPerTurnSquared: 1760,
        recommendedRange: '1-30 MHz',
      ),
      FerriteCorePreset(
        key: 'ft140-43',
        label: 'FT-140-43',
        alNanohenriesPerTurnSquared: 990,
        recommendedRange: '10-200 MHz',
      ),
      FerriteCorePreset(
        key: 'ft240-43',
        label: 'FT-240-43',
        alNanohenriesPerTurnSquared: 1240,
        recommendedRange: '10-200 MHz',
      ),
      FerriteCorePreset(
        key: 'ft240-61',
        label: 'FT-240-61',
        alNanohenriesPerTurnSquared: 290,
        recommendedRange: '50-500 MHz',
      ),
    ];
  }

  CoaxLossResult calculateCoaxLoss({
    required CoaxCablePreset preset,
    required double frequencyMHz,
    required double lengthMeters,
    double swr = 1.0,
  }) {
    if (frequencyMHz <= 0) throw ArgumentError('Frequency must be > 0');
    if (lengthMeters < 0) throw ArgumentError('Length must be >= 0');
    if (swr < 1) throw ArgumentError('SWR must be >= 1');

    final attenuationPer100m = _interpolateLoss(
      preset.lossPoints,
      frequencyMHz,
    );
    final matchedLossDb = attenuationPer100m * (lengthMeters / 100);
    final additionalSwrLossDb = swr == 1
        ? 0.0
        : _additionalLossDueToSwr(matchedLossDb: matchedLossDb, swr: swr);
    final totalLossDb = matchedLossDb + additionalSwrLossDb;
    final deliveredPowerPercent = pow(10, -totalLossDb / 10).toDouble() * 100;

    return CoaxLossResult(
      matchedLossDb: matchedLossDb,
      totalLossDb: totalLossDb,
      additionalSwrLossDb: additionalSwrLossDb,
      deliveredPowerPercent: deliveredPowerPercent,
      attenuationDbPer100m: attenuationPer100m,
    );
  }

  SwrMetricsResult fromSwr(double swr) {
    if (swr < 1) throw ArgumentError('SWR must be >= 1');
    final gamma = (swr - 1) / (swr + 1);
    final returnLossDb = gamma == 0 ? double.infinity : -20 * log(gamma) / ln10;
    final reflectedPowerPercent = gamma * gamma * 100;
    final mismatchLossDb = -10 * log(1 - gamma * gamma) / ln10;
    return SwrMetricsResult(
      swr: swr,
      returnLossDb: returnLossDb,
      reflectionCoefficient: gamma,
      reflectedPowerPercent: reflectedPowerPercent,
      mismatchLossDb: mismatchLossDb,
    );
  }

  SwrMetricsResult fromReturnLoss(double returnLossDb) {
    if (returnLossDb < 0) {
      throw ArgumentError('Return loss must be >= 0');
    }
    final gamma = pow(10, -returnLossDb / 20).toDouble();
    final swr = gamma >= 1 ? double.infinity : (1 + gamma) / (1 - gamma);
    final reflectedPowerPercent = gamma * gamma * 100;
    final mismatchLossDb = -10 * log(1 - gamma * gamma) / ln10;
    return SwrMetricsResult(
      swr: swr,
      returnLossDb: returnLossDb,
      reflectionCoefficient: gamma,
      reflectedPowerPercent: reflectedPowerPercent,
      mismatchLossDb: mismatchLossDb,
    );
  }

  PhysicalToElectricalLengthResult physicalToElectricalLength({
    required double frequencyMHz,
    required double physicalLengthMeters,
    required double velocityFactor,
  }) {
    _validateVelocityFactor(velocityFactor);
    if (frequencyMHz <= 0) throw ArgumentError('Frequency must be > 0');
    if (physicalLengthMeters < 0) throw ArgumentError('Length must be >= 0');
    final wavelengthMeters =
        _speedOfLightMetersPerSecond * velocityFactor / (frequencyMHz * 1e6);
    final wavelengths = physicalLengthMeters / wavelengthMeters;
    final electricalDegrees = wavelengths * 360;
    return PhysicalToElectricalLengthResult(
      wavelengthMeters: wavelengthMeters,
      electricalDegrees: electricalDegrees,
      wavelengths: wavelengths,
    );
  }

  ElectricalToPhysicalLengthResult electricalToPhysicalLength({
    required double frequencyMHz,
    required double electricalDegrees,
    required double velocityFactor,
  }) {
    _validateVelocityFactor(velocityFactor);
    if (frequencyMHz <= 0) throw ArgumentError('Frequency must be > 0');
    if (electricalDegrees < 0) {
      throw ArgumentError('Electrical degrees must be >= 0');
    }
    final wavelengthMeters =
        _speedOfLightMetersPerSecond * velocityFactor / (frequencyMHz * 1e6);
    final wavelengths = electricalDegrees / 360;
    final physicalLengthMeters = wavelengths * wavelengthMeters;
    return ElectricalToPhysicalLengthResult(
      wavelengthMeters: wavelengthMeters,
      physicalLengthMeters: physicalLengthMeters,
      wavelengths: wavelengths,
    );
  }

  QuarterWaveTransformerResult quarterWaveTransformer({
    required double sourceImpedanceOhms,
    required double loadImpedanceOhms,
    required double frequencyMHz,
    required double velocityFactor,
  }) {
    _validateVelocityFactor(velocityFactor);
    if (sourceImpedanceOhms <= 0 || loadImpedanceOhms <= 0) {
      throw ArgumentError('Impedance must be > 0');
    }
    if (frequencyMHz <= 0) throw ArgumentError('Frequency must be > 0');
    final requiredZ0 = sqrt(sourceImpedanceOhms * loadImpedanceOhms);
    final wavelengthMeters =
        _speedOfLightMetersPerSecond * velocityFactor / (frequencyMHz * 1e6);
    return QuarterWaveTransformerResult(
      requiredCharacteristicImpedanceOhms: requiredZ0,
      physicalLengthMeters: wavelengthMeters / 4,
      electricalLengthDegrees: 90,
    );
  }

  ChokeTurnsResult chokeMinimumTurns({
    required FerriteCorePreset core,
    required double frequencyMHz,
    required double targetChokingImpedanceOhms,
  }) {
    if (frequencyMHz <= 0) throw ArgumentError('Frequency must be > 0');
    if (targetChokingImpedanceOhms <= 0) {
      throw ArgumentError('Target choking impedance must be > 0');
    }

    final exactTurns = sqrt(
      targetChokingImpedanceOhms /
          (2 * pi * frequencyMHz * core.alNanohenriesPerTurnSquared * 1e-3),
    );
    final minimumWholeTurns = exactTurns.ceil();
    final inductanceHenries = core.alNanohenriesPerTurnSquared *
        minimumWholeTurns *
        minimumWholeTurns *
        1e-9;
    final resultingReactanceOhms =
        2 * pi * frequencyMHz * 1e6 * inductanceHenries;

    return ChokeTurnsResult(
      exactTurns: exactTurns,
      minimumWholeTurns: minimumWholeTurns,
      inductanceMicrohenries: inductanceHenries * 1e6,
      resultingReactanceOhms: resultingReactanceOhms,
    );
  }

  double _interpolateLoss(List<CoaxLossPoint> points, double frequencyMHz) {
    final sorted = [...points]
      ..sort((a, b) => a.frequencyMHz.compareTo(b.frequencyMHz));
    if (frequencyMHz <= sorted.first.frequencyMHz) {
      return _scaleLoss(
        knownFrequencyMHz: sorted.first.frequencyMHz,
        knownLossDbPer100m: sorted.first.attenuationDbPer100m,
        targetFrequencyMHz: frequencyMHz,
      );
    }
    if (frequencyMHz >= sorted.last.frequencyMHz) {
      return _scaleLoss(
        knownFrequencyMHz: sorted.last.frequencyMHz,
        knownLossDbPer100m: sorted.last.attenuationDbPer100m,
        targetFrequencyMHz: frequencyMHz,
      );
    }
    for (var i = 0; i < sorted.length - 1; i++) {
      final lower = sorted[i];
      final upper = sorted[i + 1];
      if (frequencyMHz >= lower.frequencyMHz &&
          frequencyMHz <= upper.frequencyMHz) {
        final ratio = (frequencyMHz - lower.frequencyMHz) /
            (upper.frequencyMHz - lower.frequencyMHz);
        return lower.attenuationDbPer100m +
            (upper.attenuationDbPer100m - lower.attenuationDbPer100m) * ratio;
      }
    }
    throw StateError('Interpolation failed');
  }

  double _scaleLoss({
    required double knownFrequencyMHz,
    required double knownLossDbPer100m,
    required double targetFrequencyMHz,
  }) {
    final scale = sqrt(targetFrequencyMHz / knownFrequencyMHz);
    return knownLossDbPer100m * scale;
  }

  double _additionalLossDueToSwr({
    required double matchedLossDb,
    required double swr,
  }) {
    final linePowerRatio = pow(10, -matchedLossDb / 10).toDouble();
    final gamma = (swr - 1) / (swr + 1);
    final numerator = 1 - gamma * gamma;
    final denominator = 1 - gamma * gamma * linePowerRatio * linePowerRatio;
    return -10 * log(numerator / denominator) / ln10;
  }

  void _validateVelocityFactor(double velocityFactor) {
    if (velocityFactor <= 0 || velocityFactor > 1) {
      throw ArgumentError('Velocity factor must be between 0 and 1');
    }
  }
}
