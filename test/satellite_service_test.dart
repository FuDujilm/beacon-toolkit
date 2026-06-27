import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/discovery.dart';
import 'package:mobile/services/satellite_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('observerFromGrid resolves 6-character Maidenhead grid', () {
    final service = SatelliteService(skipCache: true);

    final observer = service.observerFromGrid('OM89dw');

    expect(observer, isNotNull);
    expect(observer!.source, 'Grid');
    expect(observer.latitude, closeTo(39.9375, 0.0001));
    expect(observer.longitude, closeTo(116.2917, 0.0001));
  });

  test('getUpcomingPasses returns SGP4 passes from fallback TLE', () async {
    final service = SatelliteService(skipCache: true);
    const observer = ObserverLocation(
      latitude: 39.9375,
      longitude: 116.2917,
      label: 'OM89DW',
      source: 'Grid',
    );

    final passes = await service.getUpcomingPasses(
      observer: observer,
      tleSourceUrls: const [],
      satelliteNames: const ['ISS (ZARYA)'],
      window: const Duration(hours: 72),
    );

    expect(passes, isNotEmpty);
    expect(passes.first.source, 'TLE SGP4');
    expect(passes.first.aos.isBefore(passes.first.los), isTrue);
    expect(passes.first.maxElevation, greaterThanOrEqualTo(0));
    expect(passes.first.lookSamples, isNotEmpty);
    expect(passes.first.trackPoints, isNotEmpty);
  });

  test('searchSatellites finds fallback TLE catalog entries', () async {
    final service = SatelliteService(skipCache: true);

    final results = await service.searchSatellites(
      query: 'ISS',
      tleSourceUrls: const [],
      subscribedNames: const ['ISS (ZARYA)'],
    );

    expect(results, isNotEmpty);
    expect(results.first.name, contains('ISS'));
    expect(results.first.subscribed, isTrue);
  });

  test('getSubscribedSatelliteMapItems returns batch map data', () async {
    final service = SatelliteService(skipCache: true);
    const observer = ObserverLocation(
      latitude: 39.9375,
      longitude: 116.2917,
      label: 'OM89DW',
      source: 'Grid',
    );

    final items = await service.getSubscribedSatelliteMapItems(
      observer: observer,
      tleSourceUrls: const [],
      satelliteNames: const ['ISS (ZARYA)', 'SO-50'],
    );

    expect(items, hasLength(2));
    expect(items.first.currentPosition, isNotNull);
    expect(items.first.groundTrack, isNotEmpty);
  });
}
