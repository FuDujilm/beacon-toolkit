import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/transmission_line_calculator_service.dart';

void main() {
  const service = TransmissionLineCalculatorService();

  test('coax loss returns matched and total loss', () {
    final preset = service.presets().firstWhere((item) => item.key == 'rg58');
    final result = service.calculateCoaxLoss(
      preset: preset,
      frequencyMHz: 145,
      lengthMeters: 20,
      swr: 1.5,
    );

    expect(result.matchedLossDb, closeTo(3.78, 0.05));
    expect(result.totalLossDb, greaterThan(result.matchedLossDb));
  });

  test('swr conversion returns reflected power', () {
    final result = service.fromSwr(2);
    expect(result.reflectionCoefficient, closeTo(1 / 3, 1e-9));
    expect(result.reflectedPowerPercent, closeTo(11.1111, 1e-3));
  });

  test('physical to electrical length converts correctly', () {
    final result = service.physicalToElectricalLength(
      frequencyMHz: 145,
      physicalLengthMeters: 1,
      velocityFactor: 0.66,
    );
    expect(result.electricalDegrees, closeTo(263.82, 0.2));
  });

  test('quarter wave transformer computes target impedance', () {
    final result = service.quarterWaveTransformer(
      sourceImpedanceOhms: 50,
      loadImpedanceOhms: 75,
      frequencyMHz: 145,
      velocityFactor: 0.66,
    );
    expect(result.requiredCharacteristicImpedanceOhms, closeTo(61.237, 1e-3));
    expect(result.physicalLengthMeters, greaterThan(0.3));
  });

  test('coax choke minimum turns computes rounded turn count', () {
    final core = service.ferriteCorePresets().firstWhere(
      (item) => item.key == 'ft240-43',
    );
    final result = service.chokeMinimumTurns(
      core: core,
      frequencyMHz: 14.2,
      targetChokingImpedanceOhms: 1000,
    );

    expect(result.exactTurns, greaterThan(2));
    expect(result.minimumWholeTurns, greaterThanOrEqualTo(3));
    expect(result.resultingReactanceOhms, greaterThanOrEqualTo(1000));
  });
}
