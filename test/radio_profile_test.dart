import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/radio_profile.dart';

void main() {
  group('RadioProfile', () {
    test('defaults altitude to zero for old JSON without altitude', () {
      final profile = RadioProfile.fromJson(const {
        'callsign': 'BG1ABC',
        'qth': 'Beijing',
        'grid': 'OM89DW',
        'latitude': 39.9,
        'longitude': 116.4,
      });

      expect(profile.altitudeMeters, 0);
    });

    test('reads altitudeMeters and altitude_meters JSON fields', () {
      final camel = RadioProfile.fromJson(const {
        'altitudeMeters': 123.4,
      });
      final snake = RadioProfile.fromJson(const {
        'altitude_meters': '456.7',
      });

      expect(camel.altitudeMeters, 123.4);
      expect(snake.altitudeMeters, 456.7);
    });

    test('copyWith and toJson preserve altitude', () {
      final profile = RadioProfile.defaults.copyWith(altitudeMeters: 88.5);

      expect(profile.altitudeMeters, 88.5);
      expect(profile.toJson()['altitudeMeters'], 88.5);
    });
  });
}
