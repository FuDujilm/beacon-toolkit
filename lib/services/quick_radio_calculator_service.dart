import 'dart:math';

class QuickOhmsLawResult {
  final double voltage;
  final double current;
  final double resistance;
  final double power;

  const QuickOhmsLawResult({
    required this.voltage,
    required this.current,
    required this.resistance,
    required this.power,
  });
}

class QuickPowerDbResult {
  final double watts;
  final double dBm;
  final double dBw;

  const QuickPowerDbResult({
    required this.watts,
    required this.dBm,
    required this.dBw,
  });
}

class QuickSwrReturnLossResult {
  final double swr;
  final double returnLossDb;
  final double reflectionCoefficient;

  const QuickSwrReturnLossResult({
    required this.swr,
    required this.returnLossDb,
    required this.reflectionCoefficient,
  });
}

class QuickRadioCalculatorService {
  const QuickRadioCalculatorService();

  QuickOhmsLawResult solveOhmsLaw({
    double? voltage,
    double? current,
    double? resistance,
    double? power,
  }) {
    final known = [
      voltage != null,
      current != null,
      resistance != null,
      power != null,
    ].where((value) => value).length;
    if (known < 2) {
      throw ArgumentError('At least two values are required');
    }

    if (voltage != null && current != null) {
      final resolvedResistance = voltage / current;
      final resolvedPower = voltage * current;
      return QuickOhmsLawResult(
        voltage: voltage,
        current: current,
        resistance: resolvedResistance,
        power: resolvedPower,
      );
    }

    if (voltage != null && resistance != null) {
      final resolvedCurrent = voltage / resistance;
      final resolvedPower = voltage * resolvedCurrent;
      return QuickOhmsLawResult(
        voltage: voltage,
        current: resolvedCurrent,
        resistance: resistance,
        power: resolvedPower,
      );
    }

    if (voltage != null && power != null) {
      final resolvedCurrent = power / voltage;
      final resolvedResistance = voltage / resolvedCurrent;
      return QuickOhmsLawResult(
        voltage: voltage,
        current: resolvedCurrent,
        resistance: resolvedResistance,
        power: power,
      );
    }

    if (current != null && resistance != null) {
      final resolvedVoltage = current * resistance;
      final resolvedPower = resolvedVoltage * current;
      return QuickOhmsLawResult(
        voltage: resolvedVoltage,
        current: current,
        resistance: resistance,
        power: resolvedPower,
      );
    }

    if (current != null && power != null) {
      final resolvedVoltage = power / current;
      final resolvedResistance = resolvedVoltage / current;
      return QuickOhmsLawResult(
        voltage: resolvedVoltage,
        current: current,
        resistance: resolvedResistance,
        power: power,
      );
    }

    if (resistance == null || power == null) {
      throw ArgumentError('Unsupported value combination');
    }
    final resolvedVoltage = sqrt(power * resistance);
    final resolvedCurrent = resolvedVoltage / resistance;
    return QuickOhmsLawResult(
      voltage: resolvedVoltage,
      current: resolvedCurrent,
      resistance: resistance,
      power: power,
    );
  }

  QuickPowerDbResult fromWatts(double watts) {
    if (watts <= 0) throw ArgumentError('Power must be greater than 0');
    final dBw = 10 * log(watts) / ln10;
    final dBm = dBw + 30;
    return QuickPowerDbResult(watts: watts, dBm: dBm, dBw: dBw);
  }

  QuickPowerDbResult fromDbm(double dBm) {
    final watts = pow(10, (dBm - 30) / 10).toDouble();
    return fromWatts(watts);
  }

  QuickPowerDbResult fromDbw(double dBw) {
    final watts = pow(10, dBw / 10).toDouble();
    return fromWatts(watts);
  }

  QuickSwrReturnLossResult fromSwr(double swr) {
    if (swr < 1) throw ArgumentError('SWR must be >= 1');
    final gamma = (swr - 1) / (swr + 1);
    final returnLossDb = gamma == 0 ? double.infinity : -20 * log(gamma) / ln10;
    return QuickSwrReturnLossResult(
      swr: swr,
      returnLossDb: returnLossDb,
      reflectionCoefficient: gamma,
    );
  }

  QuickSwrReturnLossResult fromReturnLoss(double returnLossDb) {
    if (returnLossDb < 0) {
      throw ArgumentError('Return loss must be >= 0');
    }
    final gamma = pow(10, -returnLossDb / 20).toDouble();
    final swr = (1 + gamma) / (1 - gamma);
    return QuickSwrReturnLossResult(
      swr: swr,
      returnLossDb: returnLossDb,
      reflectionCoefficient: gamma,
    );
  }
}
