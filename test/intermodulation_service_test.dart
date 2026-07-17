import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/intermodulation_service.dart';

void main() {
  const service = IntermodulationService();

  test('calculates common IM3 and IM5 products', () {
    final result = service.calculate(
      inputFrequenciesMHz: const [145.5, 146.1],
      includeThirdOrder: true,
      includeFifthOrder: true,
    );

    expect(
        result.products
            .firstWhere((item) => item.label == '2f1 - f2')
            .frequencyMHz,
        closeTo(144.9, 1e-9));
    expect(
        result.products
            .firstWhere((item) => item.label == '2f2 - f1')
            .frequencyMHz,
        closeTo(146.7, 1e-9));
    expect(
        result.products
            .firstWhere((item) => item.label == '3f1 - 2f2')
            .frequencyMHz,
        closeTo(144.3, 1e-9));
    expect(
        result.products
            .firstWhere((item) => item.label == '3f2 - 2f1')
            .frequencyMHz,
        closeTo(147.3, 1e-9));
  });

  test('can limit output to third order only', () {
    final result = service.calculate(
      inputFrequenciesMHz: const [145.5, 146.1, 147.8],
      includeThirdOrder: true,
      includeFifthOrder: false,
    );

    expect(result.products.every((item) => item.order == 3), isTrue);
  });
}
