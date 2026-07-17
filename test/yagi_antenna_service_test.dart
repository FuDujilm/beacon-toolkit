import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/yagi_antenna_service.dart';

void main() {
  const service = YagiAntennaService();

  test('calculates 3-element yagi dimensions', () {
    final result = service.calculateThreeElement(frequencyMHz: 145.5);

    expect(result.elements.length, 3);
    expect(result.boomLengthMeters, greaterThan(0));
    expect(result.wavelengthMeters, greaterThan(2.0));
    expect(result.elements.first.name, '反射器');
    expect(result.elements[1].name, '振子');
    expect(result.elements[2].name, '导向器 1');
    expect(result.elements[1].note, contains('直振子'));
    expect(result.boomLengthMillimeters, greaterThan(0));
    expect(result.elementDiameterMm, 6);
    expect(result.feedGapMm, 8);
    expect(result.boomDiameterMm, 20);
    expect(result.mountStyle, YagiMountStyle.throughBoom);
    expect(result.drivenElementStyle, YagiDrivenElementStyle.splitDipole);
    expect(result.boomMaterial, YagiBoomMaterial.aluminum);
  });

  test('supports 5-element yagi dimensions', () {
    final result = service.calculate(
      frequencyMHz: 435,
      elementCount: 5,
      elementDiameterMm: 8,
      feedGapMm: 10,
      boomDiameterMm: 25,
      mountStyle: YagiMountStyle.insulatedAboveBoom,
      drivenElementStyle: YagiDrivenElementStyle.foldedDipole,
      boomMaterial: YagiBoomMaterial.fiberglass,
    );

    expect(result.elementCount, 5);
    expect(result.elements.length, 5);
    expect(result.elements.last.shortName, 'D3');
    expect(result.boomLengthMillimeters, greaterThan(result.elements[1].positionMillimeters));
    expect(result.elementDiameterMm, 8);
    expect(result.feedGapMm, 10);
    expect(result.boomDiameterMm, 25);
    expect(result.mountStyle, YagiMountStyle.insulatedAboveBoom);
    expect(result.drivenElementStyle, YagiDrivenElementStyle.foldedDipole);
    expect(result.boomMaterial, YagiBoomMaterial.fiberglass);
    expect(result.elements[1].note, contains('折合振子'));
  });

  test('supports larger element counts within safe range', () {
    final result = service.calculate(
      frequencyMHz: 145.5,
      elementCount: 8,
    );

    expect(result.elementCount, 8);
    expect(result.elements.length, 8);
    expect(result.elements.last.shortName, 'D6');
  });
}
