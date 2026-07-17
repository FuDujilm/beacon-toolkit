class IntermodulationProduct {
  final String label;
  final double frequencyMHz;
  final int order;
  final double frequencyA;
  final double frequencyB;

  const IntermodulationProduct({
    required this.label,
    required this.frequencyMHz,
    required this.order,
    required this.frequencyA,
    required this.frequencyB,
  });
}

class IntermodulationResult {
  final List<double> inputFrequenciesMHz;
  final List<IntermodulationProduct> products;

  const IntermodulationResult({
    required this.inputFrequenciesMHz,
    required this.products,
  });
}

class IntermodulationFocusRange {
  final double lowerMHz;
  final double upperMHz;

  const IntermodulationFocusRange({
    required this.lowerMHz,
    required this.upperMHz,
  });
}

class IntermodulationService {
  const IntermodulationService();

  IntermodulationResult calculate({
    required List<double> inputFrequenciesMHz,
    required bool includeThirdOrder,
    required bool includeFifthOrder,
    IntermodulationFocusRange? focusRange,
  }) {
    final sorted = [...inputFrequenciesMHz]..sort();
    final products = <IntermodulationProduct>[];

    for (var i = 0; i < sorted.length; i++) {
      for (var j = i + 1; j < sorted.length; j++) {
        final low = sorted[i];
        final high = sorted[j];

        if (includeThirdOrder) {
          products.addAll([
            IntermodulationProduct(
              label: '2f1 - f2',
              frequencyMHz: 2 * low - high,
              order: 3,
              frequencyA: low,
              frequencyB: high,
            ),
            IntermodulationProduct(
              label: '2f2 - f1',
              frequencyMHz: 2 * high - low,
              order: 3,
              frequencyA: low,
              frequencyB: high,
            ),
            IntermodulationProduct(
              label: '2f1 + f2',
              frequencyMHz: 2 * low + high,
              order: 3,
              frequencyA: low,
              frequencyB: high,
            ),
            IntermodulationProduct(
              label: '2f2 + f1',
              frequencyMHz: 2 * high + low,
              order: 3,
              frequencyA: low,
              frequencyB: high,
            ),
          ]);
        }

        if (includeFifthOrder) {
          products.addAll([
            IntermodulationProduct(
              label: '3f1 - 2f2',
              frequencyMHz: 3 * low - 2 * high,
              order: 5,
              frequencyA: low,
              frequencyB: high,
            ),
            IntermodulationProduct(
              label: '3f2 - 2f1',
              frequencyMHz: 3 * high - 2 * low,
              order: 5,
              frequencyA: low,
              frequencyB: high,
            ),
            IntermodulationProduct(
              label: '3f1 + 2f2',
              frequencyMHz: 3 * low + 2 * high,
              order: 5,
              frequencyA: low,
              frequencyB: high,
            ),
            IntermodulationProduct(
              label: '3f2 + 2f1',
              frequencyMHz: 3 * high + 2 * low,
              order: 5,
              frequencyA: low,
              frequencyB: high,
            ),
          ]);
        }
      }
    }

    final filteredProducts = focusRange == null
        ? products
        : products.where((product) {
            return product.frequencyMHz >= focusRange.lowerMHz &&
                product.frequencyMHz <= focusRange.upperMHz;
          }).toList(growable: false);

    return IntermodulationResult(
      inputFrequenciesMHz: sorted,
      products: filteredProducts,
    );
  }
}
