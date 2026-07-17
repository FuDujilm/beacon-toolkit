import 'discovery.dart';

class DopplerPassPoint {
  final String label;
  final double factor;
  final bool isCurrent;

  const DopplerPassPoint({
    required this.label,
    required this.factor,
    this.isCurrent = false,
  });
}

bool isFiniteDopplerFactor(double? value) {
  return value != null && value.isFinite;
}

double? interpolatedDopplerFactor(SatellitePass pass, DateTime target) {
  final samples = pass.lookSamples
      .where((sample) => isFiniteDopplerFactor(sample.dopplerFactor))
      .toList(growable: false);
  if (samples.isEmpty) {
    return isFiniteDopplerFactor(pass.dopplerFactor)
        ? pass.dopplerFactor
        : null;
  }
  if (!target.isAfter(samples.first.time)) return samples.first.dopplerFactor;
  if (!target.isBefore(samples.last.time)) return samples.last.dopplerFactor;

  for (var index = 1; index < samples.length; index++) {
    final previous = samples[index - 1];
    final next = samples[index];
    if (target.isBefore(previous.time) || target.isAfter(next.time)) {
      continue;
    }
    final span = next.time.difference(previous.time).inMilliseconds;
    if (span <= 0) return next.dopplerFactor;
    final elapsed = target.difference(previous.time).inMilliseconds;
    final ratio = (elapsed / span).clamp(0.0, 1.0);
    return previous.dopplerFactor! +
        (next.dopplerFactor! - previous.dopplerFactor!) * ratio;
  }
  return pass.dopplerFactor;
}

DopplerPassPoint? currentDopplerPoint(SatellitePass pass, DateTime now) {
  if (now.isBefore(pass.aos) || now.isAfter(pass.los)) return null;
  final factor = interpolatedDopplerFactor(pass, now);
  if (factor == null) return null;
  return DopplerPassPoint(
    label: '实时',
    factor: factor,
    isCurrent: true,
  );
}

List<DopplerPassPoint> dopplerPassPoints(SatellitePass pass) {
  final fallback = pass.dopplerFactor ?? 1.0;
  final samples = pass.lookSamples
      .where((sample) => isFiniteDopplerFactor(sample.dopplerFactor))
      .toList(growable: false);
  if (samples.isEmpty) {
    if (!isFiniteDopplerFactor(fallback)) return const [];
    return [
      DopplerPassPoint(label: 'AOS', factor: fallback),
      DopplerPassPoint(label: 'TCA', factor: fallback),
      DopplerPassPoint(label: 'LOS', factor: fallback),
    ];
  }

  final tca = samples.reduce((a, b) {
    final aDelta = a.time.difference(pass.maxElevationAt).inSeconds.abs();
    final bDelta = b.time.difference(pass.maxElevationAt).inSeconds.abs();
    return aDelta <= bDelta ? a : b;
  });

  return [
    DopplerPassPoint(label: 'AOS', factor: samples.first.dopplerFactor!),
    DopplerPassPoint(label: 'TCA', factor: tca.dopplerFactor!),
    DopplerPassPoint(label: 'LOS', factor: samples.last.dopplerFactor!),
  ];
}

String shiftedFrequency(int? hz, double factor) {
  if (hz == null || hz <= 0 || !factor.isFinite) return '--';
  return '${(hz * factor / 1000000).toStringAsFixed(3)} MHz';
}

String frequencyOffset(int? hz, double factor) {
  if (hz == null || hz <= 0 || !factor.isFinite) return '--';
  final khz = hz * (factor - 1) / 1000;
  final sign = khz >= 0 ? '+' : '';
  return '$sign${khz.toStringAsFixed(1)} kHz';
}
