class MirrorFrequencyResult {
  final double signalFrequencyMHz;
  final double intermediateFrequencyMHz;
  final bool highSideInjection;
  final double localOscillatorMHz;
  final double imageFrequencyMHz;

  const MirrorFrequencyResult({
    required this.signalFrequencyMHz,
    required this.intermediateFrequencyMHz,
    required this.highSideInjection,
    required this.localOscillatorMHz,
    required this.imageFrequencyMHz,
  });
}

class MirrorFrequencyService {
  const MirrorFrequencyService();

  MirrorFrequencyResult calculate({
    required double signalFrequencyMHz,
    required double intermediateFrequencyMHz,
    required bool highSideInjection,
  }) {
    final localOscillatorMHz = highSideInjection
        ? signalFrequencyMHz + intermediateFrequencyMHz
        : signalFrequencyMHz - intermediateFrequencyMHz;
    final imageFrequencyMHz = highSideInjection
        ? signalFrequencyMHz + 2 * intermediateFrequencyMHz
        : signalFrequencyMHz - 2 * intermediateFrequencyMHz;

    return MirrorFrequencyResult(
      signalFrequencyMHz: signalFrequencyMHz,
      intermediateFrequencyMHz: intermediateFrequencyMHz,
      highSideInjection: highSideInjection,
      localOscillatorMHz: localOscillatorMHz,
      imageFrequencyMHz: imageFrequencyMHz,
    );
  }
}
