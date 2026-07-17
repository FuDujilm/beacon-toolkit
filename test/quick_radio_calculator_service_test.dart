import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/quick_radio_calculator_service.dart';

void main() {
  const service = QuickRadioCalculatorService();

  test('ohms law resolves voltage/current to resistance and power', () {
    final result = service.solveOhmsLaw(voltage: 12, current: 2);
    expect(result.resistance, closeTo(6, 1e-9));
    expect(result.power, closeTo(24, 1e-9));
  });

  test('power db conversion from watts works', () {
    final result = service.fromWatts(10);
    expect(result.dBw, closeTo(10, 1e-9));
    expect(result.dBm, closeTo(40, 1e-9));
  });

  test('swr conversion returns reflection coefficient', () {
    final result = service.fromSwr(2);
    expect(result.reflectionCoefficient, closeTo(1 / 3, 1e-9));
    expect(result.returnLossDb, closeTo(9.542425, 1e-5));
  });
}
