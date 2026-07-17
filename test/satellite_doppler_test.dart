import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/discovery.dart';
import 'package:mobile/models/satellite_doppler.dart';

void main() {
  group('satellite doppler helpers', () {
    test('interpolates current doppler factor between look samples', () {
      final start = DateTime.utc(2026, 1, 1, 0, 0);
      final pass = _pass(
        start,
        samples: [
          _sample(start, 1.000010),
          _sample(start.add(const Duration(seconds: 10)), 0.999990),
        ],
      );

      final factor = interpolatedDopplerFactor(
        pass,
        start.add(const Duration(seconds: 5)),
      );

      expect(factor, closeTo(1.0, 0.0000001));
    });

    test('formats positive and negative VHF UHF frequency shifts', () {
      expect(frequencyOffset(145800000, 1.000010), '+1.5 kHz');
      expect(shiftedFrequency(145800000, 1.000010), '145.801 MHz');
      expect(frequencyOffset(435000000, 0.999990), '-4.3 kHz');
      expect(shiftedFrequency(435000000, 0.999990), '434.996 MHz');
    });
  });
}

SatellitePass _pass(
  DateTime start, {
  required List<SatelliteLookSample> samples,
}) {
  return SatellitePass(
    satelliteName: 'TEST',
    aos: start,
    los: start.add(const Duration(minutes: 10)),
    maxElevationAt: start.add(const Duration(minutes: 5)),
    maxElevation: 45,
    aosAzimuth: 10,
    losAzimuth: 200,
    source: 'test',
    lookSamples: samples,
  );
}

SatelliteLookSample _sample(DateTime time, double factor) {
  return SatelliteLookSample(
    time: time,
    elevation: 10,
    azimuth: 90,
    rangeKm: 1000,
    dopplerFactor: factor,
    groundPoint: GroundTrackPoint(
      time: time,
      latitude: 0,
      longitude: 0,
      altitudeKm: 400,
    ),
  );
}
