import 'dart:math';

enum UnitConverterMode {
  frequency,
  wavelength,
  powerVoltage,
  fieldStrengthFluxDensity,
}

class UnitConverterUnit {
  final String key;
  final String label;
  final String texLabel;

  const UnitConverterUnit({
    required this.key,
    required this.label,
    required this.texLabel,
  });
}

class UnitConverterValue {
  final UnitConverterUnit unit;
  final String value;

  const UnitConverterValue({
    required this.unit,
    required this.value,
  });
}

class PowerVoltageConversionResult {
  final List<UnitConverterValue> voltageValues;
  final List<UnitConverterValue> powerValues;

  const PowerVoltageConversionResult({
    required this.voltageValues,
    required this.powerValues,
  });
}

class FieldFluxConversionResult {
  final List<UnitConverterValue> fieldStrengthValues;
  final List<UnitConverterValue> fluxDensityValues;
  final List<UnitConverterValue> powerValues;

  const FieldFluxConversionResult({
    required this.fieldStrengthValues,
    required this.fluxDensityValues,
    required this.powerValues,
  });
}

class BasicConversionResult {
  final List<UnitConverterValue> values;

  const BasicConversionResult({
    required this.values,
  });
}

class UnitConverterService {
  static const double _speedOfLight = 299792458;
  static const double _freeSpaceImpedance = 376.730313668;

  const UnitConverterService();

  List<UnitConverterUnit> frequencyUnitsFor() {
    return const [
      UnitConverterUnit(key: 'hz', label: 'Hz', texLabel: r'\mathrm{Hz}'),
      UnitConverterUnit(key: 'khz', label: 'kHz', texLabel: r'\mathrm{kHz}'),
      UnitConverterUnit(key: 'mhz', label: 'MHz', texLabel: r'\mathrm{MHz}'),
      UnitConverterUnit(key: 'ghz', label: 'GHz', texLabel: r'\mathrm{GHz}'),
    ];
  }

  List<UnitConverterUnit> wavelengthUnitsFor() {
    return const [
      UnitConverterUnit(key: 'm', label: 'm', texLabel: r'\mathrm{m}'),
      UnitConverterUnit(key: 'cm', label: 'cm', texLabel: r'\mathrm{cm}'),
      UnitConverterUnit(key: 'mm', label: 'mm', texLabel: r'\mathrm{mm}'),
      UnitConverterUnit(
        key: 'lambda_mhz',
        label: 'MHz',
        texLabel: r'\mathrm{MHz}',
      ),
    ];
  }

  List<UnitConverterUnit> voltageUnitsFor() {
    return const [
      UnitConverterUnit(key: 'v', label: 'V', texLabel: r'\mathrm{V}'),
      UnitConverterUnit(key: 'dbv', label: 'dBV', texLabel: r'\mathrm{dBV}'),
      UnitConverterUnit(key: 'mv', label: 'mV', texLabel: r'\mathrm{mV}'),
      UnitConverterUnit(
        key: 'dbmv',
        label: 'dBmV',
        texLabel: r'\mathrm{dBmV}',
      ),
      UnitConverterUnit(key: 'uv', label: 'μV', texLabel: r'\mu\mathrm{V}'),
      UnitConverterUnit(
        key: 'dbuv',
        label: 'dBμV',
        texLabel: r'\mathrm{dB}\mu\mathrm{V}',
      ),
    ];
  }

  List<UnitConverterUnit> powerUnitsFor() {
    return const [
      UnitConverterUnit(key: 'w', label: 'W', texLabel: r'\mathrm{W}'),
      UnitConverterUnit(key: 'dbw', label: 'dBW', texLabel: r'\mathrm{dBW}'),
      UnitConverterUnit(key: 'mw', label: 'mW', texLabel: r'\mathrm{mW}'),
      UnitConverterUnit(
        key: 'dbmw',
        label: 'dBmW',
        texLabel: r'\mathrm{dBmW}',
      ),
      UnitConverterUnit(key: 'uw', label: 'μW', texLabel: r'\mu\mathrm{W}'),
      UnitConverterUnit(
        key: 'dbuw',
        label: 'dBμW',
        texLabel: r'\mathrm{dB}\mu\mathrm{W}',
      ),
    ];
  }

  List<UnitConverterUnit> fieldStrengthUnitsFor() {
    return const [
      UnitConverterUnit(
        key: 'vpm',
        label: 'V/m',
        texLabel: r'\mathrm{V}/\mathrm{m}',
      ),
      UnitConverterUnit(
        key: 'dbmvp_m',
        label: 'dBmV/m',
        texLabel: r'\mathrm{dBmV}/\mathrm{m}',
      ),
      UnitConverterUnit(
        key: 'dbvp_m',
        label: 'dBV/m',
        texLabel: r'\mathrm{dBV}/\mathrm{m}',
      ),
      UnitConverterUnit(
        key: 'uvp_m',
        label: 'μV/m',
        texLabel: r'\mu\mathrm{V}/\mathrm{m}',
      ),
      UnitConverterUnit(
        key: 'mvp_m',
        label: 'mV/m',
        texLabel: r'\mathrm{mV}/\mathrm{m}',
      ),
      UnitConverterUnit(
        key: 'dbuvp_m',
        label: 'dBμV/m',
        texLabel: r'\mathrm{dB}\mu\mathrm{V}/\mathrm{m}',
      ),
    ];
  }

  List<UnitConverterUnit> fluxDensityUnitsFor() {
    return const [
      UnitConverterUnit(
        key: 'wpm2',
        label: 'W/m²',
        texLabel: r'\mathrm{W}/\mathrm{m}^{2}',
      ),
      UnitConverterUnit(
        key: 'dbmwp_m2',
        label: 'dBmW/m²',
        texLabel: r'\mathrm{dBmW}/\mathrm{m}^{2}',
      ),
      UnitConverterUnit(
        key: 'dbwp_m2',
        label: 'dBW/m²',
        texLabel: r'\mathrm{dBW}/\mathrm{m}^{2}',
      ),
      UnitConverterUnit(
        key: 'uwp_m2',
        label: 'μW/m²',
        texLabel: r'\mu\mathrm{W}/\mathrm{m}^{2}',
      ),
      UnitConverterUnit(
        key: 'mwp_m2',
        label: 'mW/m²',
        texLabel: r'\mathrm{mW}/\mathrm{m}^{2}',
      ),
      UnitConverterUnit(
        key: 'dbuwp_m2',
        label: 'dBμW/m²',
        texLabel: r'\mathrm{dB}\mu\mathrm{W}/\mathrm{m}^{2}',
      ),
    ];
  }

  BasicConversionResult convertFrequency({
    required String sourceUnitKey,
    required double inputValue,
  }) {
    final hertz = switch (sourceUnitKey) {
      'hz' => inputValue,
      'khz' => inputValue * 1000,
      'mhz' => inputValue * 1000000,
      'ghz' => inputValue * 1000000000,
      _ => throw ArgumentError('Unsupported frequency unit: $sourceUnitKey'),
    };

    return BasicConversionResult(
      values: frequencyUnitsFor().map((unit) {
        final converted = switch (unit.key) {
          'hz' => hertz,
          'khz' => hertz / 1000,
          'mhz' => hertz / 1000000,
          'ghz' => hertz / 1000000000,
          _ => throw ArgumentError('Unsupported frequency unit: ${unit.key}'),
        };
        return UnitConverterValue(
          unit: unit,
          value: _format(converted),
        );
      }).toList(growable: false),
    );
  }

  BasicConversionResult convertWavelength({
    required String sourceUnitKey,
    required double inputValue,
  }) {
    final meters = switch (sourceUnitKey) {
      'm' => inputValue,
      'cm' => inputValue / 100,
      'mm' => inputValue / 1000,
      'lambda_mhz' => _speedOfLight / (inputValue * 1000000),
      _ => throw ArgumentError('Unsupported wavelength unit: $sourceUnitKey'),
    };

    return BasicConversionResult(
      values: wavelengthUnitsFor().map((unit) {
        final converted = switch (unit.key) {
          'm' => meters,
          'cm' => meters * 100,
          'mm' => meters * 1000,
          'lambda_mhz' => _speedOfLight / meters / 1000000,
          _ => throw ArgumentError('Unsupported wavelength unit: ${unit.key}'),
        };
        return UnitConverterValue(
          unit: unit,
          value: _format(converted),
        );
      }).toList(growable: false),
    );
  }

  PowerVoltageConversionResult convertPowerVoltage({
    required String sourceUnitKey,
    required double inputValue,
    required double impedanceOhms,
  }) {
    final isVoltageSource =
        voltageUnitsFor().any((unit) => unit.key == sourceUnitKey);
    final voltageVolts = isVoltageSource
        ? _voltageToVolts(sourceUnitKey, inputValue)
        : _powerToVoltageVolts(sourceUnitKey, inputValue, impedanceOhms);
    final powerWatts = voltageVolts * voltageVolts / impedanceOhms;

    return PowerVoltageConversionResult(
      voltageValues: voltageUnitsFor().map((unit) {
        return UnitConverterValue(
          unit: unit,
          value: _format(_voltsToVoltage(unit.key, voltageVolts)),
        );
      }).toList(growable: false),
      powerValues: powerUnitsFor().map((unit) {
        return UnitConverterValue(
          unit: unit,
          value: _format(_wattsToPower(unit.key, powerWatts)),
        );
      }).toList(growable: false),
    );
  }

  FieldFluxConversionResult convertFieldStrengthFluxDensity({
    required String sourceUnitKey,
    required double inputValue,
    required double frequencyMHz,
    required double impedanceOhms,
  }) {
    final isFieldStrengthSource =
        fieldStrengthUnitsFor().any((unit) => unit.key == sourceUnitKey);
    final isFluxSource =
        fluxDensityUnitsFor().any((unit) => unit.key == sourceUnitKey);

    final fieldStrengthVoltsPerMeter =
        switch ((isFieldStrengthSource, isFluxSource)) {
      (true, _) => _fieldStrengthToVoltsPerMeter(sourceUnitKey, inputValue),
      (_, true) => _fluxDensityToFieldStrengthVoltsPerMeter(
          sourceUnitKey,
          inputValue,
        ),
      _ => _receivedPowerToFieldStrengthVoltsPerMeter(
          sourceUnitKey: sourceUnitKey,
          inputValue: inputValue,
          frequencyMHz: frequencyMHz,
          impedanceOhms: impedanceOhms,
        ),
    };

    final fluxDensityWattsPerSquareMeter = fieldStrengthVoltsPerMeter *
        fieldStrengthVoltsPerMeter /
        _freeSpaceImpedance;
    final receivedPowerWatts = _fluxDensityToReceivedPowerWatts(
      fluxDensityWattsPerSquareMeter: fluxDensityWattsPerSquareMeter,
      frequencyMHz: frequencyMHz,
      impedanceOhms: impedanceOhms,
    );

    return FieldFluxConversionResult(
      fieldStrengthValues: fieldStrengthUnitsFor().map((unit) {
        return UnitConverterValue(
          unit: unit,
          value: _format(
            _voltsPerMeterToFieldStrength(unit.key, fieldStrengthVoltsPerMeter),
          ),
        );
      }).toList(growable: false),
      fluxDensityValues: fluxDensityUnitsFor().map((unit) {
        return UnitConverterValue(
          unit: unit,
          value: _format(
            _wattsPerSquareMeterToFluxDensity(
              unit.key,
              fluxDensityWattsPerSquareMeter,
            ),
          ),
        );
      }).toList(growable: false),
      powerValues: powerUnitsFor().map((unit) {
        return UnitConverterValue(
          unit: unit,
          value: _format(_wattsToPower(unit.key, receivedPowerWatts)),
        );
      }).toList(growable: false),
    );
  }

  double _voltageToVolts(String unitKey, double value) {
    return switch (unitKey) {
      'v' => value,
      'dbv' => pow(10, value / 20).toDouble(),
      'mv' => value / 1000,
      'dbmv' => pow(10, value / 20).toDouble() / 1000,
      'uv' => value / 1000000,
      'dbuv' => pow(10, value / 20).toDouble() / 1000000,
      _ => throw ArgumentError('Unsupported voltage unit: $unitKey'),
    };
  }

  double _voltsToVoltage(String unitKey, double volts) {
    return switch (unitKey) {
      'v' => volts,
      'dbv' => _toDb20(volts),
      'mv' => volts * 1000,
      'dbmv' => _toDb20(volts * 1000),
      'uv' => volts * 1000000,
      'dbuv' => _toDb20(volts * 1000000),
      _ => throw ArgumentError('Unsupported voltage unit: $unitKey'),
    };
  }

  double _powerToWatts(String unitKey, double value) {
    return switch (unitKey) {
      'w' => value,
      'dbw' => pow(10, value / 10).toDouble(),
      'mw' => value / 1000,
      'dbmw' => pow(10, value / 10).toDouble() / 1000,
      'uw' => value / 1000000,
      'dbuw' => pow(10, value / 10).toDouble() / 1000000,
      _ => throw ArgumentError('Unsupported power unit: $unitKey'),
    };
  }

  double _wattsToPower(String unitKey, double watts) {
    return switch (unitKey) {
      'w' => watts,
      'dbw' => _toDb10(watts),
      'mw' => watts * 1000,
      'dbmw' => _toDb10(watts * 1000),
      'uw' => watts * 1000000,
      'dbuw' => _toDb10(watts * 1000000),
      _ => throw ArgumentError('Unsupported power unit: $unitKey'),
    };
  }

  double _fieldStrengthToVoltsPerMeter(String unitKey, double value) {
    return switch (unitKey) {
      'vpm' => value,
      'dbmvp_m' => pow(10, value / 20).toDouble() / 1000,
      'dbvp_m' => pow(10, value / 20).toDouble(),
      'uvp_m' => value / 1000000,
      'mvp_m' => value / 1000,
      'dbuvp_m' => pow(10, value / 20).toDouble() / 1000000,
      _ => throw ArgumentError('Unsupported field strength unit: $unitKey'),
    };
  }

  double _voltsPerMeterToFieldStrength(String unitKey, double value) {
    return switch (unitKey) {
      'vpm' => value,
      'dbmvp_m' => _toDb20(value * 1000),
      'dbvp_m' => _toDb20(value),
      'uvp_m' => value * 1000000,
      'mvp_m' => value * 1000,
      'dbuvp_m' => _toDb20(value * 1000000),
      _ => throw ArgumentError('Unsupported field strength unit: $unitKey'),
    };
  }

  double _fluxDensityToWattsPerSquareMeter(String unitKey, double value) {
    return switch (unitKey) {
      'wpm2' => value,
      'dbmwp_m2' => pow(10, value / 10).toDouble() / 1000,
      'dbwp_m2' => pow(10, value / 10).toDouble(),
      'uwp_m2' => value / 1000000,
      'mwp_m2' => value / 1000,
      'dbuwp_m2' => pow(10, value / 10).toDouble() / 1000000,
      _ => throw ArgumentError('Unsupported flux density unit: $unitKey'),
    };
  }

  double _wattsPerSquareMeterToFluxDensity(String unitKey, double value) {
    return switch (unitKey) {
      'wpm2' => value,
      'dbmwp_m2' => _toDb10(value * 1000),
      'dbwp_m2' => _toDb10(value),
      'uwp_m2' => value * 1000000,
      'mwp_m2' => value * 1000,
      'dbuwp_m2' => _toDb10(value * 1000000),
      _ => throw ArgumentError('Unsupported flux density unit: $unitKey'),
    };
  }

  double _fluxDensityToFieldStrengthVoltsPerMeter(
    String unitKey,
    double value,
  ) {
    final wattsPerSquareMeter =
        _fluxDensityToWattsPerSquareMeter(unitKey, value);
    return sqrt(wattsPerSquareMeter * _freeSpaceImpedance);
  }

  double _receivedPowerToFieldStrengthVoltsPerMeter({
    required String sourceUnitKey,
    required double inputValue,
    required double frequencyMHz,
    required double impedanceOhms,
  }) {
    final powerWatts = _powerToWatts(sourceUnitKey, inputValue);
    final fluxDensity = _receivedPowerToFluxDensityWattsPerSquareMeter(
      powerWatts: powerWatts,
      frequencyMHz: frequencyMHz,
      impedanceOhms: impedanceOhms,
    );
    return sqrt(fluxDensity * _freeSpaceImpedance);
  }

  double _receivedPowerToFluxDensityWattsPerSquareMeter({
    required double powerWatts,
    required double frequencyMHz,
    required double impedanceOhms,
  }) {
    final effectiveAperture = _effectiveApertureSquareMeters(
      frequencyMHz: frequencyMHz,
      impedanceOhms: impedanceOhms,
    );
    return powerWatts / effectiveAperture;
  }

  double _fluxDensityToReceivedPowerWatts({
    required double fluxDensityWattsPerSquareMeter,
    required double frequencyMHz,
    required double impedanceOhms,
  }) {
    final effectiveAperture = _effectiveApertureSquareMeters(
      frequencyMHz: frequencyMHz,
      impedanceOhms: impedanceOhms,
    );
    return fluxDensityWattsPerSquareMeter * effectiveAperture;
  }

  double _effectiveApertureSquareMeters({
    required double frequencyMHz,
    required double impedanceOhms,
  }) {
    final wavelengthMeters = _speedOfLight / (frequencyMHz * 1000000);
    final normalizedImpedance = impedanceOhms / 50;
    return wavelengthMeters * wavelengthMeters / (4 * pi) * normalizedImpedance;
  }

  double _powerToVoltageVolts(
    String unitKey,
    double value,
    double impedanceOhms,
  ) {
    final watts = _powerToWatts(unitKey, value);
    return sqrt(watts * impedanceOhms);
  }

  double _toDb10(double value) => 10 * log(value) / ln10;

  double _toDb20(double value) => 20 * log(value) / ln10;

  String _format(double value) {
    if (value == 0) return '0';
    final absolute = value.abs();
    if (absolute >= 1000000) return value.toStringAsFixed(2);
    if (absolute >= 1000) return value.toStringAsFixed(3);
    if (absolute >= 1) return value.toStringAsFixed(4);
    if (absolute >= 0.001) return value.toStringAsFixed(6);
    return value.toStringAsExponential(4);
  }
}
