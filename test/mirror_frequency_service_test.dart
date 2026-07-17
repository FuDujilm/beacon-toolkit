import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/mirror_frequency_service.dart';

void main() {
  const service = MirrorFrequencyService();

  test('high side injection calculates LO and image frequency', () {
    final result = service.calculate(
      signalFrequencyMHz: 145.5,
      intermediateFrequencyMHz: 10.7,
      highSideInjection: true,
    );

    expect(result.localOscillatorMHz, 156.2);
    expect(result.imageFrequencyMHz, 166.9);
  });

  test('low side injection calculates LO and image frequency', () {
    final result = service.calculate(
      signalFrequencyMHz: 145.5,
      intermediateFrequencyMHz: 10.7,
      highSideInjection: false,
    );

    expect(result.localOscillatorMHz, 134.8);
    expect(result.imageFrequencyMHz, 124.1);
  });
}
