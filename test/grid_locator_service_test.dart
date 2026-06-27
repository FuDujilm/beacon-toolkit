import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/grid_locator_service.dart';

void main() {
  group('GridLocatorService', () {
    const service = GridLocatorService();

    test('encodes common Maidenhead precisions', () {
      expect(
        service.encodeMaidenhead(
          latitude: 39.9042,
          longitude: 116.4074,
          precision: 4,
        ),
        'OM89',
      );
      expect(
        service.encodeMaidenhead(
          latitude: 39.9042,
          longitude: 116.4074,
          precision: 6,
        ),
        'OM89ev',
      );
      expect(
        service
            .encodeMaidenhead(
              latitude: 39.9042,
              longitude: 116.4074,
              precision: 8,
            )
            .length,
        8,
      );
      expect(
        service
            .encodeMaidenhead(
              latitude: 39.9042,
              longitude: 116.4074,
              precision: 10,
            )
            .length,
        10,
      );
    });

    test('decodes grid bounds and center', () {
      final cell = service.decodeMaidenhead('OM89dw');

      expect(cell.locator, 'OM89dw');
      expect(cell.precision, 6);
      expect(cell.center.latitude, closeTo(39.9375, 0.000001));
      expect(cell.center.longitude, closeTo(116.291666, 0.000001));
      expect(cell.bounds.contains(cell.center), isTrue);
    });

    test('roundtrips encoded centers', () {
      for (final precision in GridLocatorService.supportedPrecisions) {
        final locator = service.encodeMaidenhead(
          latitude: 31.2304,
          longitude: 121.4737,
          precision: precision,
        );
        final cell = service.decodeMaidenhead(locator);
        final centerLocator = service.encodeMaidenhead(
          latitude: cell.center.latitude,
          longitude: cell.center.longitude,
          precision: precision,
        );
        expect(centerLocator, locator);
      }
    });

    test('rejects invalid input', () {
      expect(() => service.decodeMaidenhead('OM8'), throwsFormatException);
      expect(() => service.decodeMaidenhead('SM89dw'), throwsFormatException);
      expect(() => service.decodeMaidenhead('OM89yy'), throwsFormatException);
      expect(
        () => service.encodeMaidenhead(
          latitude: 100,
          longitude: 116,
          precision: 6,
        ),
        throwsFormatException,
      );
    });
  });
}
