enum YagiMountStyle {
  throughBoom,
  insulatedAboveBoom,
}

enum YagiDrivenElementStyle {
  splitDipole,
  foldedDipole,
}

enum YagiBoomMaterial {
  aluminum,
  fiberglass,
}

class YagiElementDimension {
  final String name;
  final String shortName;
  final double lengthMeters;
  final double positionMeters;
  final double spacingFromPreviousMeters;
  final String note;

  const YagiElementDimension({
    required this.name,
    required this.shortName,
    required this.lengthMeters,
    required this.positionMeters,
    required this.spacingFromPreviousMeters,
    this.note = '-',
  });

  double get lengthMillimeters => lengthMeters * 1000;

  double get halfLengthMillimeters => lengthMillimeters / 2;

  double get positionMillimeters => positionMeters * 1000;

  double get spacingMillimeters => spacingFromPreviousMeters * 1000;
}

class YagiAntennaResult {
  final double frequencyMHz;
  final double wavelengthMeters;
  final double boomLengthMeters;
  final int elementCount;
  final double elementDiameterMm;
  final double feedGapMm;
  final double boomDiameterMm;
  final YagiMountStyle mountStyle;
  final YagiDrivenElementStyle drivenElementStyle;
  final YagiBoomMaterial boomMaterial;
  final List<YagiElementDimension> elements;

  const YagiAntennaResult({
    required this.frequencyMHz,
    required this.wavelengthMeters,
    required this.boomLengthMeters,
    required this.elementCount,
    required this.elementDiameterMm,
    required this.feedGapMm,
    required this.boomDiameterMm,
    required this.mountStyle,
    required this.drivenElementStyle,
    required this.boomMaterial,
    required this.elements,
  });

  double get boomLengthMillimeters => boomLengthMeters * 1000;
}

class YagiAntennaService {
  static const double _speedOfLight = 299792458;
  static const int minElementCount = 3;
  static const int maxElementCount = 12;

  const YagiAntennaService();

  YagiAntennaResult calculate({
    required double frequencyMHz,
    required int elementCount,
    double elementDiameterMm = 6,
    double feedGapMm = 8,
    double boomDiameterMm = 20,
    YagiMountStyle mountStyle = YagiMountStyle.throughBoom,
    YagiDrivenElementStyle drivenElementStyle =
        YagiDrivenElementStyle.splitDipole,
    YagiBoomMaterial boomMaterial = YagiBoomMaterial.aluminum,
  }) {
    if (elementCount < minElementCount || elementCount > maxElementCount) {
      throw ArgumentError.value(
        elementCount,
        'elementCount',
        '只支持 $minElementCount 到 $maxElementCount 单元',
      );
    }
    if (elementDiameterMm <= 0) {
      throw ArgumentError.value(elementDiameterMm, 'elementDiameterMm', '元件直径必须大于 0');
    }
    if (feedGapMm < 0) {
      throw ArgumentError.value(feedGapMm, 'feedGapMm', '馈电间隙不能小于 0');
    }
    if (boomDiameterMm <= 0) {
      throw ArgumentError.value(boomDiameterMm, 'boomDiameterMm', 'boom 外径必须大于 0');
    }

    final wavelengthMeters = _speedOfLight / (frequencyMHz * 1000000);
    final diameterCorrection = (elementDiameterMm - 6) * 0.0004;
    final feedGapCorrection = feedGapMm * 0.0002;
    final boomDiameterCorrection = (boomDiameterMm - 20) * 0.00015;
    final mountCorrection = switch (mountStyle) {
      YagiMountStyle.throughBoom => -0.0015 - boomDiameterCorrection,
      YagiMountStyle.insulatedAboveBoom => 0.0,
    };
    final materialCorrection = switch (boomMaterial) {
      YagiBoomMaterial.aluminum => -0.0006,
      YagiBoomMaterial.fiberglass => 0.0,
    };
    final drivenStyleCorrection = switch (drivenElementStyle) {
      YagiDrivenElementStyle.splitDipole => 0.0,
      YagiDrivenElementStyle.foldedDipole => wavelengthMeters * 0.008,
    };

    final reflectorLength =
        wavelengthMeters * 0.515 +
        diameterCorrection +
        mountCorrection +
        materialCorrection;
    final drivenLength =
        wavelengthMeters * 0.475 +
        diameterCorrection +
        feedGapCorrection +
        mountCorrection +
        materialCorrection +
        drivenStyleCorrection;
    final reflectorSpacing = wavelengthMeters * 0.2;
    final elements = <YagiElementDimension>[
      YagiElementDimension(
        name: '反射器',
        shortName: 'R',
        lengthMeters: reflectorLength,
        positionMeters: 0,
        spacingFromPreviousMeters: 0,
      ),
      YagiElementDimension(
        name: '振子',
        shortName: 'DE',
        lengthMeters: drivenLength,
        positionMeters: reflectorSpacing,
        spacingFromPreviousMeters: reflectorSpacing,
        note:
            '${drivenElementStyle == YagiDrivenElementStyle.foldedDipole ? '折合振子' : '直振子'}，间隙 ${feedGapMm.toStringAsFixed(1)} mm',
      ),
    ];

    var currentPosition = reflectorSpacing;
    for (var index = 0; index < elementCount - 2; index++) {
      final directorNumber = index + 1;
      final spacingFactor = switch (directorNumber) {
        1 => 0.150,
        2 => 0.145,
        _ => 0.140,
      };
      final lengthFactor = switch (directorNumber) {
        1 => 0.445,
        2 => 0.438,
        _ => 0.432,
      };
      final spacing = wavelengthMeters * spacingFactor;
      currentPosition += spacing;
      elements.add(
        YagiElementDimension(
          name: '导向器 $directorNumber',
          shortName: 'D$directorNumber',
          lengthMeters: wavelengthMeters * lengthFactor +
              diameterCorrection +
              mountCorrection +
              materialCorrection,
          positionMeters: currentPosition,
          spacingFromPreviousMeters: spacing,
        ),
      );
    }

    final boomLength = currentPosition;

    return YagiAntennaResult(
      frequencyMHz: frequencyMHz,
      wavelengthMeters: wavelengthMeters,
      boomLengthMeters: boomLength,
      elementCount: elementCount,
      elementDiameterMm: elementDiameterMm,
      feedGapMm: feedGapMm,
      boomDiameterMm: boomDiameterMm,
      mountStyle: mountStyle,
      drivenElementStyle: drivenElementStyle,
      boomMaterial: boomMaterial,
      elements: elements,
    );
  }

  YagiAntennaResult calculateThreeElement({
    required double frequencyMHz,
  }) {
    return calculate(
      frequencyMHz: frequencyMHz,
      elementCount: 3,
    );
  }
}
