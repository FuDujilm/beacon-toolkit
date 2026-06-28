import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:latlng/latlng.dart';
import 'package:orbit/orbit.dart';

import '../models/discovery.dart';
import 'local_database_service.dart';
import 'satellite_api_service.dart';

class SatelliteService {
  static const _tleCacheKey = 'satellite_tle_cache';
  static const _tleCacheTimeKey = 'satellite_tle_cache_time';
  static const _satnogsBaseUrl = 'https://db.satnogs.org/api';
  final _databaseService = LocalDatabaseService();
  final _apiService = SatelliteApiService();
  final _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));
  final bool _skipCache;

  SatelliteService({bool skipCache = false}) : _skipCache = skipCache;

  Future<List<SatelliteCatalogItem>> getSatelliteCatalog({
    required List<String> tleSourceUrls,
    List<String> subscribedNames = const [],
  }) async {
    final cached = await _refreshAndReadCatalog(
      subscribedNames: subscribedNames,
      limit: 200,
    );
    if (cached.isNotEmpty) return cached;

    final entries = await _loadTleEntries(tleSourceUrls);
    return entries
        .map(
          (entry) => SatelliteCatalogItem(
            name: entry.name,
            noradCatId: entry.noradCatId,
            tleSource: _tleSourceLabel(tleSourceUrls),
            subscribed: subscribedNames.any(
              (name) => _matchesSatellite(entry.name, name),
            ),
          ),
        )
        .toList();
  }

  Future<List<SatelliteCatalogItem>> searchSatellites({
    required String query,
    required List<String> tleSourceUrls,
    List<String> subscribedNames = const [],
    int page = 1,
    int limit = 50,
  }) async {
    final normalized = query.trim().toUpperCase();
    final cached = await _refreshAndReadCatalog(
      query: query,
      subscribedNames: subscribedNames,
      page: page,
      limit: limit,
    );
    if (cached.isNotEmpty) return cached;

    final catalog = await getSatelliteCatalog(
      tleSourceUrls: tleSourceUrls,
      subscribedNames: subscribedNames,
    );
    if (normalized.isEmpty) {
      return catalog.take(limit).toList();
    }
    return catalog
        .where((item) {
          final name = item.name.toUpperCase();
          final norad = item.noradCatId?.toString() ?? '';
          return name.contains(normalized) || norad.contains(normalized);
        })
        .take(limit)
        .toList();
  }

  Future<List<SatelliteMapItem>> getSubscribedSatelliteMapItems({
    required ObserverLocation observer,
    required List<String> tleSourceUrls,
    required List<String> satelliteNames,
    Duration window = const Duration(hours: 72),
  }) async {
    final names = satelliteNames.isEmpty
        ? const ['ISS (ZARYA)', 'AO-91', 'SO-50', 'PO-101']
        : satelliteNames;
    final entries = await _loadTleEntries(tleSourceUrls);
    final now = DateTime.now();
    final passes = await getUpcomingPasses(
      observer: observer,
      tleSourceUrls: tleSourceUrls,
      satelliteNames: names,
      window: window,
    );

    return names.map((name) {
      final entry = _findEntry(entries, name);
      final matchedPasses = passes
          .where((pass) => _matchesSatellite(pass.satelliteName, name))
          .toList();
      return SatelliteMapItem(
        name: entry?.name ?? name,
        noradCatId: entry?.noradCatId,
        nextPass: matchedPasses.isEmpty ? null : matchedPasses.first,
        currentPosition: entry == null ? null : _positionAt(entry, now),
        groundTrack: entry == null
            ? const []
            : _groundTrack(entry, now, const Duration(minutes: 110)),
      );
    }).toList();
  }

  Future<List<SatelliteSummary>> getSubscribedSatellites({
    required String grid,
    required List<String> tleSourceUrls,
    required List<String> satelliteNames,
    Duration window = const Duration(hours: 48),
  }) async {
    final names = satelliteNames.isEmpty
        ? const ['ISS (ZARYA)', 'AO-91', 'SO-50', 'PO-101']
        : satelliteNames;
    final observer = observerFromGrid(grid);
    if (observer == null) {
      throw const FormatException('请先在我的资料中设置有效 Grid，例如 OM89dw');
    }
    final passes = await getUpcomingPasses(
      observer: observer,
      tleSourceUrls: tleSourceUrls,
      satelliteNames: names,
      window: window,
    );
    await _refreshAndReadCatalog(
      subscribedNames: satelliteNames,
      limit: 200,
    );
    final entries = await _loadTleEntries(tleSourceUrls);
    final summaries = <SatelliteSummary>[];

    for (final name in names) {
      final matchedEntry = _findEntry(entries, name);
      final catalogQuery = matchedEntry?.noradCatId?.toString() ?? name;
      await _refreshAndReadCatalog(
        query: catalogQuery,
        subscribedNames: satelliteNames,
        limit: 20,
      );
      final catalogItem =
          await _databaseService.getCachedSatelliteByNameOrNorad(
        name: matchedEntry?.name ?? name,
        noradCatId: matchedEntry?.noradCatId,
      );
      final matchedPasses = passes
          .where((pass) => _matchesSatellite(pass.satelliteName, name))
          .toList();
      summaries.add(SatelliteSummary(
        name: matchedEntry?.name ?? name,
        noradCatId: matchedEntry?.noradCatId,
        catalogItem: catalogItem,
        nextPass: matchedPasses.isEmpty ? null : matchedPasses.first,
        upcomingPassCount: matchedPasses.length,
        tleSource: _tleSourceLabel(tleSourceUrls),
      ));
    }
    return summaries;
  }

  Future<SatelliteDetail> getSatelliteDetail({
    required String grid,
    ObserverLocation? observer,
    required List<String> tleSourceUrls,
    required String satelliteName,
    Duration window = const Duration(hours: 72),
  }) async {
    final resolvedObserver = observer ?? observerFromGrid(grid);
    if (resolvedObserver == null) {
      throw const FormatException('请先在我的资料中设置有效 Grid，例如 OM89dw');
    }
    final passes = await getUpcomingPasses(
      observer: resolvedObserver,
      tleSourceUrls: tleSourceUrls,
      satelliteNames: [satelliteName],
      window: window,
    );
    final entries = await _loadTleEntries(tleSourceUrls);
    final entry = _findEntry(entries, satelliteName);
    final now = DateTime.now();
    final groundTrack = entry == null
        ? const <GroundTrackPoint>[]
        : _groundTrack(entry, now, const Duration(minutes: 110));
    final currentPosition = entry == null ? null : _positionAt(entry, now);
    final noradCatId =
        entry?.noradCatId ?? (passes.isEmpty ? null : passes.first.noradCatId);
    final transponders = await getTransponders(
      satelliteName: entry?.name ?? satelliteName,
      noradCatId: noradCatId,
    );
    var apiStatusSummaries = const <SatelliteStatusSummary>[];
    var catalogItem = await _resolveCatalogItem(
      name: entry?.name ?? satelliteName,
      noradCatId: noradCatId,
    );
    if (catalogItem?.id != null) {
      try {
        final detail = await _apiService.getSatelliteDetail(catalogItem!.id!);
        catalogItem = detail.satellite;
        await _databaseService.cacheSatelliteCatalog([detail.satellite]);
        await _databaseService.cacheSatelliteDetail(
          satelliteId: detail.satellite.id!,
          transponders: detail.transponders,
          statusSummaries: detail.statusSummaries,
        );
        apiStatusSummaries = detail.statusSummaries;
      } catch (_) {
        apiStatusSummaries = await _databaseService
            .getCachedSatelliteStatusSummaries(catalogItem!.id!);
      }
    }
    return SatelliteDetail(
      name: entry?.name ?? satelliteName,
      noradCatId: noradCatId,
      catalogItem: catalogItem,
      passes: passes,
      transponders: transponders,
      statusSummaries: apiStatusSummaries,
      tleSource: _tleSourceLabel(tleSourceUrls),
      tleUpdatedAt: DateTime.tryParse(
        await _databaseService.getSetting(_tleCacheTimeKey) ?? '',
      ),
      currentPosition: currentPosition,
      groundTrack: groundTrack,
    );
  }

  Future<List<SatelliteTransponder>> getTransponders({
    required String satelliteName,
    int? noradCatId,
  }) async {
    final cachedSatellite = await _resolveCatalogItem(
      name: satelliteName,
      noradCatId: noradCatId,
    );
    if (cachedSatellite?.id != null) {
      try {
        final detail =
            await _apiService.getSatelliteDetail(cachedSatellite!.id!);
        await _databaseService.cacheSatelliteCatalog([detail.satellite]);
        await _databaseService.cacheSatelliteDetail(
          satelliteId: detail.satellite.id!,
          transponders: detail.transponders,
          statusSummaries: detail.statusSummaries,
        );
        if (detail.transponders.isNotEmpty) return detail.transponders;
      } catch (_) {
        final cached = await _databaseService
            .getCachedSatelliteTransponders(cachedSatellite!.id!);
        if (cached.isNotEmpty) return cached;
      }
    }

    if (noradCatId != null) {
      try {
        final response = await _dio.get<List<dynamic>>(
          '$_satnogsBaseUrl/transmitters/',
          queryParameters: {'satellite__norad_cat_id': noradCatId},
        );
        final data = response.data ?? const [];
        final transponders = data
            .map((item) =>
                SatelliteTransponder.fromJson(item as Map<String, dynamic>))
            .where((item) => item.alive || item.status == 'active')
            .toList();
        if (transponders.isNotEmpty) return transponders;
      } catch (_) {
        // Fall through to built-in common amateur satellite frequencies.
      }
    }
    return _fallbackTransponders(satelliteName);
  }

  Future<SatelliteCatalogItem?> _resolveCatalogItem({
    required String name,
    int? noradCatId,
  }) async {
    final query = noradCatId?.toString() ?? name;
    final remote = await _refreshAndReadCatalog(
      query: query,
      subscribedNames: const [],
      limit: 20,
    );
    for (final item in remote) {
      if ((noradCatId != null && item.noradCatId == noradCatId) ||
          _matchesSatellite(item.name, name)) {
        return item;
      }
    }
    return _databaseService.getCachedSatelliteByNameOrNorad(
      name: name,
      noradCatId: noradCatId,
    );
  }

  Future<List<SatelliteCatalogItem>> _refreshAndReadCatalog({
    String? query,
    required List<String> subscribedNames,
    int page = 1,
    required int limit,
  }) async {
    if (_skipCache) return const [];

    try {
      final remote = await _apiService.listSatellites(
        query: query,
        page: page,
        pageSize: max(limit, 200),
      );
      if (remote.isNotEmpty) {
        await _databaseService.cacheSatelliteCatalog(remote);
      }
    } catch (_) {
      // Offline and misconfigured API cases fall back to local cache/TLE.
    }
    final cached = await _databaseService.getCachedSatelliteCatalog(
      query: query,
      offset: (page - 1) * limit,
      limit: limit,
    );
    return cached
        .map((item) => item.copyWith(
              subscribed: subscribedNames.any(
                (name) => _matchesSatellite(item.name, name),
              ),
            ))
        .toList();
  }

  Future<List<SatellitePass>> getUpcomingPasses({
    required ObserverLocation observer,
    required List<String> tleSourceUrls,
    required List<String> satelliteNames,
    Duration window = const Duration(hours: 48),
  }) async {
    final entries = await _loadTleEntries(tleSourceUrls);
    final nameFilters =
        satelliteNames.map((item) => item.toUpperCase()).toList();
    final selected = entries.where((entry) {
      if (nameFilters.isEmpty) return true;
      final upperName = entry.name.toUpperCase();
      return nameFilters.any(upperName.contains);
    }).toList();

    final now = DateTime.now();
    final until = now.add(window);
    final passes = <SatellitePass>[];
    for (final entry in selected.take(16)) {
      passes.addAll(_predictPasses(entry, observer, now, until));
    }
    passes.sort((a, b) => a.aos.compareTo(b.aos));
    return passes.take(40).toList();
  }

  ObserverLocation? observerFromGrid(String grid) {
    final location = _gridToLatLon(grid);
    if (location == null) return null;
    return ObserverLocation(
      latitude: location.latitude,
      longitude: location.longitude,
      label: grid.trim().toUpperCase(),
      source: 'Grid',
    );
  }

  Future<List<_TleEntry>> _loadTleEntries(List<String> urls) async {
    String? raw;
    for (final url in urls) {
      try {
        final response = await _dio.get<String>(url);
        final data = response.data;
        if (data != null && data.trim().isNotEmpty) {
          raw = data;
          if (!_skipCache) {
            await _databaseService.saveSetting(_tleCacheKey, raw);
            await _databaseService.saveSetting(
                _tleCacheTimeKey, DateTime.now().toIso8601String());
          }
          break;
        }
      } catch (_) {
        // Keep trying the next source; cached TLE is used below.
      }
    }
    raw ??= _skipCache ? null : await _databaseService.getSetting(_tleCacheKey);
    if (raw == null || raw.trim().isEmpty) {
      raw = _fallbackTle;
    }
    return _parseTle(raw);
  }

  List<_TleEntry> _parseTle(String raw) {
    final lines = const LineSplitter()
        .convert(raw)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final entries = <_TleEntry>[];
    for (var index = 0; index + 2 < lines.length; index++) {
      final name = lines[index];
      final line1 = lines[index + 1];
      final line2 = lines[index + 2];
      if (!line1.startsWith('1 ') || !line2.startsWith('2 ')) continue;
      final noradCatId = int.tryParse(_slice(line1, 2, 7).trim());
      entries.add(_TleEntry(
        name: name,
        line1: line1,
        line2: line2,
        noradCatId: noradCatId,
      ));
      index += 2;
    }
    return entries;
  }

  List<SatellitePass> _predictPasses(
    _TleEntry entry,
    ObserverLocation observer,
    DateTime start,
    DateTime until,
  ) {
    final satellite = entry.toTle();
    final sgp = SGP4(satellite.keplerianElements, wgs84);
    final period = sgp.periodInMinutes ?? 100;
    final orbitCount =
        max(2, (until.difference(start).inMinutes / period).ceil() + 2);
    final orbitIndexes = List<int>.generate(orbitCount, (index) => index);
    final orbitPasses = Pass.predict(
      wgs84,
      _toLatLngAlt(observer),
      sgp.propagate(start.toUtc(), orbitIndexes),
    );
    final passes = <SatellitePass>[];
    final now = DateTime.now();

    for (final pass in orbitPasses) {
      if (pass.points.isEmpty) continue;
      final aos = pass.points.first.point.time.toDateTime().toLocal();
      final los = pass.points.last.point.time.toDateTime().toLocal();
      if (los.isBefore(start) || aos.isAfter(until)) continue;

      final samples = pass.points.map(_toLookSample).toList();
      final activeSample = _nearestSample(samples, now);
      passes.add(SatellitePass(
        satelliteName: entry.name,
        noradCatId: entry.noradCatId,
        aos: aos,
        los: los,
        maxElevationAt: pass.max.point.time.toDateTime().toLocal(),
        maxElevation: pass.max.lookAngle.elevation.degrees,
        aosAzimuth: pass.points.first.lookAngle.azimuth.degrees,
        losAzimuth: pass.points.last.lookAngle.azimuth.degrees,
        currentElevation: activeSample?.elevation,
        currentAzimuth: activeSample?.azimuth,
        currentRangeKm: activeSample?.rangeKm,
        dopplerFactor: _finiteOrNull(pass.max.dopplerFactor),
        source: 'TLE SGP4',
        lookSamples: samples,
        trackPoints: samples.map((sample) => sample.groundPoint).toList(),
      ));
    }
    return passes;
  }

  GroundTrackPoint? _positionAt(_TleEntry entry, DateTime time) {
    final satellite = entry.toTle();
    final sgp = SGP4(satellite.keplerianElements, wgs84);
    final state = sgp.getPositionByDateTime(time.toUtc());
    final geodetic = state.r.toGeodeticByDateTime(wgs84, time.toUtc());
    return GroundTrackPoint(
      time: time,
      latitude: geodetic.latitude.degrees,
      longitude: _normalizeLongitude(geodetic.longitude.degrees),
      altitudeKm: geodetic.altitude,
    );
  }

  List<GroundTrackPoint> _groundTrack(
    _TleEntry entry,
    DateTime start,
    Duration window,
  ) {
    final satellite = entry.toTle();
    final sgp = SGP4(satellite.keplerianElements, wgs84);
    final points = <GroundTrackPoint>[];
    for (var minutes = 0; minutes <= window.inMinutes; minutes += 3) {
      final time = start.add(Duration(minutes: minutes));
      final state = sgp.getPositionByDateTime(time.toUtc());
      final geodetic = state.r.toGeodeticByDateTime(wgs84, time.toUtc());
      points.add(GroundTrackPoint(
        time: time,
        latitude: geodetic.latitude.degrees,
        longitude: _normalizeLongitude(geodetic.longitude.degrees),
        altitudeKm: geodetic.altitude,
      ));
    }
    return points;
  }

  SatelliteLookSample _toLookSample(PassPoint point) {
    final location = point.point.location;
    return SatelliteLookSample(
      time: point.point.time.toDateTime().toLocal(),
      elevation: point.lookAngle.elevation.degrees,
      azimuth: point.lookAngle.azimuth.degrees,
      rangeKm: point.lookAngle.range,
      dopplerFactor: _finiteOrNull(point.dopplerFactor),
      groundPoint: GroundTrackPoint(
        time: point.point.time.toDateTime().toLocal(),
        latitude: location.latitude.degrees,
        longitude: _normalizeLongitude(location.longitude.degrees),
        altitudeKm: location.altitude,
      ),
    );
  }

  SatelliteLookSample? _nearestSample(
    List<SatelliteLookSample> samples,
    DateTime target,
  ) {
    if (samples.isEmpty) return null;
    SatelliteLookSample? nearest;
    var nearestDelta = 1 << 62;
    for (final sample in samples) {
      final delta = sample.time.difference(target).inSeconds.abs();
      if (delta < nearestDelta) {
        nearestDelta = delta;
        nearest = sample;
      }
    }
    return nearestDelta <= 180 ? nearest : null;
  }

  LatLngAlt _toLatLngAlt(ObserverLocation observer) {
    return LatLngAlt(
      Angle.degree(observer.latitude),
      Angle.degree(observer.longitude),
      observer.altitudeKm,
    );
  }

  double _normalizeLongitude(double longitude) {
    var value = longitude % 360;
    if (value > 180) value -= 360;
    if (value < -180) value += 360;
    return value;
  }

  double? _finiteOrNull(double value) {
    return value.isFinite ? value : null;
  }

  _GeoPoint? _gridToLatLon(String grid) {
    final normalized = grid.trim().toUpperCase();
    if (normalized.length < 4) return null;
    final a = normalized.codeUnitAt(0) - 65;
    final b = normalized.codeUnitAt(1) - 65;
    final c = int.tryParse(normalized[2]);
    final d = int.tryParse(normalized[3]);
    if (a < 0 || a > 17 || b < 0 || b > 17 || c == null || d == null) {
      return null;
    }
    var lon = -180 + a * 20 + c * 2 + 1.0;
    var lat = -90 + b * 10 + d + 0.5;
    if (normalized.length >= 6) {
      final e = normalized.codeUnitAt(4) - 65;
      final f = normalized.codeUnitAt(5) - 65;
      if (e >= 0 && e < 24 && f >= 0 && f < 24) {
        lon = -180 + a * 20 + c * 2 + e / 12 + 1 / 24;
        lat = -90 + b * 10 + d + f / 24 + 1 / 48;
      }
    }
    return _GeoPoint(lat, lon);
  }

  String _slice(String value, int start, int end) {
    if (value.length <= start) return '';
    return value.substring(start, min(end, value.length));
  }

  _TleEntry? _findEntry(List<_TleEntry> entries, String name) {
    for (final entry in entries) {
      if (_matchesSatellite(entry.name, name)) return entry;
    }
    return null;
  }

  bool _matchesSatellite(String sourceName, String filter) {
    final source = sourceName.toUpperCase();
    final target = filter.toUpperCase();
    final normalizedSource = _normalizeSatelliteName(sourceName);
    final normalizedTarget = _normalizeSatelliteName(filter);
    return source.contains(target) ||
        target.contains(source) ||
        normalizedSource.contains(normalizedTarget) ||
        normalizedTarget.contains(normalizedSource);
  }

  String _normalizeSatelliteName(String value) {
    return value
        .toUpperCase()
        .replaceAll('(ZARYA)', '')
        .replaceAll(RegExp(r'[_\-\[\]/()]'), ' ')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .join(' ');
  }

  String _tleSourceLabel(List<String> urls) {
    if (urls.isEmpty) return '内置 TLE';
    final uri = Uri.tryParse(urls.first);
    return uri?.host.isNotEmpty == true ? uri!.host : '自定义 TLE';
  }

  List<SatelliteTransponder> _fallbackTransponders(String satelliteName) {
    final name = satelliteName.toUpperCase();
    if (name.contains('ISS')) {
      return const [
        SatelliteTransponder(
          description: 'Mode V APRS',
          type: 'Transceiver',
          mode: 'AFSK 1200',
          uplinkLow: 145825000,
          downlinkLow: 145825000,
          alive: true,
          status: 'active',
        ),
        SatelliteTransponder(
          description: 'Mode V/V FM',
          type: 'Transceiver',
          mode: 'FM',
          uplinkLow: 144490000,
          downlinkLow: 145800000,
          alive: true,
          status: 'active',
        ),
      ];
    }
    if (name.contains('SO-50')) {
      return const [
        SatelliteTransponder(
          description: 'Mode V/U FM Repeater',
          type: 'Transponder',
          mode: 'FM',
          uplinkLow: 145850000,
          downlinkLow: 436795000,
          alive: true,
          status: 'active',
        ),
      ];
    }
    if (name.contains('AO-91')) {
      return const [
        SatelliteTransponder(
          description: 'Mode U/V FM Repeater',
          type: 'Transponder',
          mode: 'FM',
          uplinkLow: 435250000,
          downlinkLow: 145960000,
          alive: true,
          status: 'active',
        ),
      ];
    }
    return const [];
  }
}

class _GeoPoint {
  final double latitude;
  final double longitude;

  const _GeoPoint(this.latitude, this.longitude);
}

class _TleEntry {
  final String name;
  final String line1;
  final String line2;
  final int? noradCatId;

  const _TleEntry({
    required this.name,
    required this.line1,
    required this.line2,
    this.noradCatId,
  });

  TwoLineElement toTle() => TwoLineElement.parse('$name\n$line1\n$line2');
}

const _fallbackTle = '''
ISS (ZARYA)
1 25544U 98067A   24150.51876213  .00016717  00000+0  30464-3 0  9993
2 25544  51.6393  45.6302 0005160  72.6182  48.5341 15.50474411454058
AO-91
1 43017U 17073E   24150.47228639  .00009763  00000+0  10869-2 0  9997
2 43017  97.7227 143.7437 0258342 289.2511  68.1059 14.64508334346701
SO-50
1 27607U 02058C   24150.47064152  .00000429  00000+0  16635-3 0  9997
2 27607  64.5551 150.7922 0067253 239.1830 120.2607 14.75538276156775
PO-101
1 44830U 19084G   24150.51020408  .00001840  00000+0  16913-3 0  9998
2 44830  97.4651 212.2939 0012163 276.0510  83.9342 14.96634573246066
''';
