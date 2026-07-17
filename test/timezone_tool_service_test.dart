import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/timezone_tool_service.dart';

void main() {
  const service = TimezoneToolService();

  group('TimezoneToolService', () {
    test('uses whole-hour offsets for common longitudes', () {
      expect(
        service.estimateUtcOffsetMinutes(latitude: 39.9, longitude: 116.4),
        480,
      );
      expect(
        service.estimateUtcOffsetMinutes(latitude: 51.5, longitude: -0.1),
        0,
      );
    });

    test('applies special half and quarter hour offsets', () {
      expect(
        service.estimateUtcOffsetMinutes(latitude: 27.7, longitude: 85.3),
        345,
      );
      expect(
        service.estimateUtcOffsetMinutes(latitude: 28.6, longitude: 77.2),
        330,
      );
    });

    test('compares two points and produces day shift', () {
      final pointA = service.resolvePoint(
        latitude: 39.9,
        longitude: 116.4,
        label: 'A',
      );
      final pointB = service.resolvePoint(
        latitude: 40.7,
        longitude: -74.0,
        label: 'B',
      );
      final result = service.compare(
        pointA: pointA,
        pointB: pointB,
        utcTime: DateTime.utc(2026, 7, 10, 23, 30),
      );

      expect(result.differenceMinutes, -780);
      expect(result.dayShift, -1);
    });

    test('daylight judgement changes between noon and midnight UTC', () {
      final noon = service.isDaylight(
        latitude: 0,
        longitude: 0,
        utcTime: DateTime.utc(2026, 7, 10, 12),
      );
      final midnight = service.isDaylight(
        latitude: 0,
        longitude: 0,
        utcTime: DateTime.utc(2026, 7, 10, 0),
      );

      expect(noon, isTrue);
      expect(midnight, isFalse);
    });
  });
}
