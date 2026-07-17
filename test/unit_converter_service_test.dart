import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/unit_converter_service.dart';

void main() {
  const service = UnitConverterService();

  test('frequency conversion supports MHz as source unit', () {
    final results = service.convertFrequency(
      sourceUnitKey: 'mhz',
      inputValue: 145.5,
    );

    expect(
      results.values.firstWhere((item) => item.unit.key == 'hz').value,
      '145500000.00',
    );
    expect(
      results.values.firstWhere((item) => item.unit.key == 'ghz').value,
      '0.145500',
    );
  });

  test('wavelength conversion supports meters as source unit', () {
    final results = service.convertWavelength(
      sourceUnitKey: 'm',
      inputValue: 2,
    );

    expect(
      results.values.firstWhere((item) => item.unit.key == 'lambda_mhz').value,
      '149.8962',
    );
    expect(
      results.values.firstWhere((item) => item.unit.key == 'cm').value,
      '200.0000',
    );
  });

  test('50 ohm voltage converts to power units', () {
    final results = service.convertPowerVoltage(
      sourceUnitKey: 'v',
      inputValue: 10,
      impedanceOhms: 50,
    );

    expect(
      results.powerValues.firstWhere((item) => item.unit.key == 'w').value,
      '2.0000',
    );
    expect(
      results.powerValues.firstWhere((item) => item.unit.key == 'dbw').value,
      '3.0103',
    );
  });

  test('dBW converts back to voltage at 50 ohm', () {
    final results = service.convertPowerVoltage(
      sourceUnitKey: 'dbw',
      inputValue: 0,
      impedanceOhms: 50,
    );

    expect(
      results.voltageValues.firstWhere((item) => item.unit.key == 'v').value,
      '7.0711',
    );
  });

  test('field strength converts to flux density', () {
    final results = service.convertFieldStrengthFluxDensity(
      sourceUnitKey: 'vpm',
      inputValue: 1,
      frequencyMHz: 50,
      impedanceOhms: 50,
    );

    expect(
      results.fluxDensityValues
          .firstWhere((item) => item.unit.key == 'wpm2')
          .value,
      '0.002654',
    );
    expect(
      results.fieldStrengthValues
          .firstWhere((item) => item.unit.key == 'dbuvp_m')
          .value,
      '120.0000',
    );
  });

  test('received power converts to field strength using frequency', () {
    final results = service.convertFieldStrengthFluxDensity(
      sourceUnitKey: 'w',
      inputValue: 1,
      frequencyMHz: 50,
      impedanceOhms: 50,
    );

    expect(
      results.fieldStrengthValues
          .firstWhere((item) => item.unit.key == 'vpm')
          .value,
      '11.4754',
    );
    expect(
      results.fluxDensityValues
          .firstWhere((item) => item.unit.key == 'uwp_m2')
          .value,
      '349549.324',
    );
  });
}
