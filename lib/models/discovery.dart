class DiscoveryPreferences {
  final String? province;
  final String? city;
  final String? examLevel;
  final List<String> contentTypes;
  final List<String> keywords;
  final List<DiscoveryApiSource> apiSources;
  final List<String> tleSourceUrls;
  final List<String> satelliteNames;

  const DiscoveryPreferences({
    this.province,
    this.city,
    this.examLevel,
    this.contentTypes = const [
      'exam_info',
      'license_renewal',
      'policy',
      'activity'
    ],
    this.keywords = const [],
    this.apiSources = const [],
    this.tleSourceUrls = const [
      'https://celestrak.org/NORAD/elements/gp.php?GROUP=amateur&FORMAT=tle',
    ],
    this.satelliteNames = const ['ISS (ZARYA)', 'AO-91', 'SO-50', 'PO-101'],
  });

  factory DiscoveryPreferences.fromJson(Map<String, dynamic> json) {
    return DiscoveryPreferences(
      province: json['province'] as String?,
      city: json['city'] as String?,
      examLevel: json['examLevel'] as String?,
      contentTypes: (json['contentTypes'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList() ??
          const ['exam_info', 'license_renewal', 'policy', 'activity'],
      keywords: (json['keywords'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList() ??
          const [],
      apiSources: (json['apiSources'] as List<dynamic>?)
              ?.map((item) =>
                  DiscoveryApiSource.fromJson(item as Map<String, dynamic>))
              .toList() ??
          (json['sourceDrafts'] as List<dynamic>?)
              ?.map((item) => DiscoveryApiSource.fromLegacyJson(
                  item as Map<String, dynamic>))
              .toList() ??
          const [],
      tleSourceUrls: (json['tleSourceUrls'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList() ??
          const [
            'https://celestrak.org/NORAD/elements/gp.php?GROUP=amateur&FORMAT=tle',
          ],
      satelliteNames: (json['satelliteNames'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList() ??
          const ['ISS (ZARYA)', 'AO-91', 'SO-50', 'PO-101'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'province': province,
      'city': city,
      'examLevel': examLevel,
      'contentTypes': contentTypes,
      'keywords': keywords,
      'apiSources': apiSources.map((item) => item.toJson()).toList(),
      'tleSourceUrls': tleSourceUrls,
      'satelliteNames': satelliteNames,
    };
  }

  DiscoveryPreferences copyWith({
    String? province,
    String? city,
    String? examLevel,
    List<String>? contentTypes,
    List<String>? keywords,
    List<DiscoveryApiSource>? apiSources,
    List<String>? tleSourceUrls,
    List<String>? satelliteNames,
    bool clearProvince = false,
    bool clearCity = false,
    bool clearExamLevel = false,
  }) {
    return DiscoveryPreferences(
      province: clearProvince ? null : province ?? this.province,
      city: clearCity ? null : city ?? this.city,
      examLevel: clearExamLevel ? null : examLevel ?? this.examLevel,
      contentTypes: contentTypes ?? this.contentTypes,
      keywords: keywords ?? this.keywords,
      apiSources: apiSources ?? this.apiSources,
      tleSourceUrls: tleSourceUrls ?? this.tleSourceUrls,
      satelliteNames: satelliteNames ?? this.satelliteNames,
    );
  }
}

class DiscoveryApiSource {
  final String name;
  final String baseUrl;
  final bool enabled;
  final DateTime createdAt;

  const DiscoveryApiSource({
    required this.name,
    required this.baseUrl,
    this.enabled = true,
    required this.createdAt,
  });

  factory DiscoveryApiSource.fromJson(Map<String, dynamic> json) {
    return DiscoveryApiSource(
      name: json['name'] as String? ?? '',
      baseUrl: json['baseUrl'] as String? ?? json['url'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  factory DiscoveryApiSource.fromLegacyJson(Map<String, dynamic> json) {
    return DiscoveryApiSource.fromJson(json);
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'baseUrl': baseUrl,
      'enabled': enabled,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  DiscoveryApiSource copyWith({
    String? name,
    String? baseUrl,
    bool? enabled,
    DateTime? createdAt,
  }) {
    return DiscoveryApiSource(
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class DiscoveryFeedItem {
  final String id;
  final String contentType;
  final String title;
  final String? province;
  final String? city;
  final String? summary;
  final String? sourceId;
  final String sourceName;
  final String sourceUrl;
  final String? examLevel;
  final bool isExpired;
  final List<String> tags;
  final DateTime? publishedAt;
  final DateTime? fetchedAt;
  final String? apiBaseUrl;
  final String status;
  final DateTime? registrationStart;
  final DateTime? registrationEnd;
  final DateTime? examTime;
  final String? venue;
  final String? signupUrl;

  const DiscoveryFeedItem({
    required this.id,
    required this.contentType,
    required this.title,
    this.province,
    this.city,
    this.summary,
    this.sourceId,
    required this.sourceName,
    required this.sourceUrl,
    this.examLevel,
    this.isExpired = false,
    this.tags = const [],
    this.publishedAt,
    this.fetchedAt,
    this.apiBaseUrl,
    this.status = 'unknown',
    this.registrationStart,
    this.registrationEnd,
    this.examTime,
    this.venue,
    this.signupUrl,
  });

  factory DiscoveryFeedItem.fromJson(
    Map<String, dynamic> json, {
    String? apiBaseUrl,
  }) {
    return DiscoveryFeedItem(
      id: json['id'] as String,
      contentType: json['content_type'] as String? ??
          json['contentType'] as String? ??
          'other',
      title: json['title'] as String? ?? '',
      province: json['province'] as String?,
      city: json['city'] as String?,
      summary: json['summary'] as String?,
      sourceId: json['source_id'] as String? ?? json['sourceId'] as String?,
      sourceName: json['source_name'] as String? ??
          json['sourceName'] as String? ??
          '未知来源',
      sourceUrl:
          json['source_url'] as String? ?? json['sourceUrl'] as String? ?? '',
      examLevel: json['exam_level'] as String? ?? json['examLevel'] as String?,
      isExpired:
          json['is_expired'] as bool? ?? json['isExpired'] as bool? ?? false,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList() ??
          const [],
      publishedAt: DateTime.tryParse(json['published_at'] as String? ??
          json['publishedAt'] as String? ??
          ''),
      fetchedAt: DateTime.tryParse(
          json['fetched_at'] as String? ?? json['fetchedAt'] as String? ?? ''),
      apiBaseUrl: apiBaseUrl,
      status: json['status'] as String? ?? 'unknown',
      registrationStart: DateTime.tryParse(
          json['registration_start'] as String? ??
              json['registrationStart'] as String? ??
              ''),
      registrationEnd: DateTime.tryParse(json['registration_end'] as String? ??
          json['registrationEnd'] as String? ??
          ''),
      examTime: DateTime.tryParse(
          json['exam_time'] as String? ?? json['examTime'] as String? ?? ''),
      venue: json['venue'] as String?,
      signupUrl: json['signup_url'] as String? ?? json['signupUrl'] as String?,
    );
  }
}

class DiscoveryDetail extends DiscoveryFeedItem {
  final double confidence;
  final String disclaimer;

  const DiscoveryDetail({
    required super.id,
    required super.contentType,
    required super.title,
    super.province,
    super.city,
    super.summary,
    super.sourceId,
    required super.sourceName,
    required super.sourceUrl,
    super.examLevel,
    super.isExpired,
    super.tags,
    super.publishedAt,
    super.fetchedAt,
    super.apiBaseUrl,
    super.status,
    super.registrationStart,
    super.registrationEnd,
    super.examTime,
    super.venue,
    super.signupUrl,
    this.confidence = 0,
    this.disclaimer = '资讯由系统聚合整理，具体安排以官方原文为准。',
  });

  factory DiscoveryDetail.fromJson(
    Map<String, dynamic> json, {
    String? apiBaseUrl,
  }) {
    return DiscoveryDetail(
      id: json['id'] as String,
      contentType: json['content_type'] as String? ?? 'other',
      title: json['title'] as String? ?? '',
      province: json['province'] as String?,
      city: json['city'] as String?,
      summary: json['summary'] as String?,
      sourceName: json['source_name'] as String? ?? '未知来源',
      sourceUrl: json['source_url'] as String? ?? '',
      examLevel: json['exam_level'] as String?,
      isExpired: json['is_expired'] as bool? ?? false,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList() ??
          const [],
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
      fetchedAt: DateTime.tryParse(json['fetched_at'] as String? ?? ''),
      apiBaseUrl: apiBaseUrl,
      status: json['status'] as String? ?? 'unknown',
      registrationStart: DateTime.tryParse(
          json['registration_start'] as String? ??
              json['registrationStart'] as String? ??
              ''),
      registrationEnd: DateTime.tryParse(json['registration_end'] as String? ??
          json['registrationEnd'] as String? ??
          ''),
      examTime: DateTime.tryParse(
          json['exam_time'] as String? ?? json['examTime'] as String? ?? ''),
      venue: json['venue'] as String?,
      signupUrl: json['signup_url'] as String? ?? json['signupUrl'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      disclaimer: json['disclaimer'] as String? ?? '资讯由系统聚合整理，具体安排以官方原文为准。',
    );
  }
}

class DiscoveryPageResult {
  final List<DiscoveryFeedItem> items;
  final int total;
  final int page;
  final int pageSize;

  const DiscoveryPageResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  bool get hasMore => page * pageSize < total;
}

class SatellitePass {
  final String satelliteName;
  final int? noradCatId;
  final DateTime aos;
  final DateTime los;
  final DateTime maxElevationAt;
  final double maxElevation;
  final double aosAzimuth;
  final double losAzimuth;
  final double? currentElevation;
  final double? currentAzimuth;
  final double? currentRangeKm;
  final double? dopplerFactor;
  final String source;
  final List<SatelliteLookSample> lookSamples;
  final List<GroundTrackPoint> trackPoints;

  const SatellitePass({
    required this.satelliteName,
    this.noradCatId,
    required this.aos,
    required this.los,
    required this.maxElevationAt,
    required this.maxElevation,
    required this.aosAzimuth,
    required this.losAzimuth,
    this.currentElevation,
    this.currentAzimuth,
    this.currentRangeKm,
    this.dopplerFactor,
    required this.source,
    this.lookSamples = const [],
    this.trackPoints = const [],
  });

  Duration get duration => los.difference(aos);

  bool get isActive {
    final now = DateTime.now();
    return !now.isBefore(aos) && !now.isAfter(los);
  }
}

class SatelliteSummary {
  final String name;
  final int? noradCatId;
  final SatelliteCatalogItem? catalogItem;
  final SatellitePass? nextPass;
  final int upcomingPassCount;
  final String tleSource;

  const SatelliteSummary({
    required this.name,
    this.noradCatId,
    this.catalogItem,
    this.nextPass,
    required this.upcomingPassCount,
    required this.tleSource,
  });
}

class SatelliteCatalogItem {
  final String? id;
  final String name;
  final String? displayName;
  final int? noradCatId;
  final String? satnogsId;
  final String? callsign;
  final List<String> aliases;
  final String? status;
  final String? countries;
  final String? operatorName;
  final String? website;
  final String? imageUrl;
  final String? amsatName;
  final String? amsatDisplayName;
  final int? amsatReportCount;
  final DateTime? amsatLatestReportedAt;
  final DateTime? sourceUpdatedAt;
  final DateTime? updatedAt;
  final String tleSource;
  final bool subscribed;

  const SatelliteCatalogItem({
    this.id,
    required this.name,
    this.displayName,
    this.noradCatId,
    this.satnogsId,
    this.callsign,
    this.aliases = const [],
    this.status,
    this.countries,
    this.operatorName,
    this.website,
    this.imageUrl,
    this.amsatName,
    this.amsatDisplayName,
    this.amsatReportCount,
    this.amsatLatestReportedAt,
    this.sourceUpdatedAt,
    this.updatedAt,
    required this.tleSource,
    this.subscribed = false,
  });

  factory SatelliteCatalogItem.fromJson(Map<String, dynamic> json) {
    return SatelliteCatalogItem(
      id: json['id'] as String?,
      name: json['name'] as String? ?? json['display_name'] as String? ?? '',
      displayName: json['display_name'] as String?,
      noradCatId: (json['norad_cat_id'] as num?)?.toInt(),
      satnogsId: json['satnogs_id'] as String?,
      callsign: json['callsign'] as String?,
      aliases: (json['aliases'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList() ??
          const [],
      status: json['status'] as String?,
      countries: json['countries'] as String?,
      operatorName: json['operator'] as String?,
      website: json['website'] as String?,
      imageUrl: json['image_url'] as String?,
      amsatName: json['amsat_name'] as String?,
      amsatDisplayName: json['amsat_display_name'] as String?,
      amsatReportCount: (json['amsat_report_count'] as num?)?.toInt(),
      amsatLatestReportedAt:
          DateTime.tryParse(json['amsat_latest_reported_at'] as String? ?? ''),
      sourceUpdatedAt:
          DateTime.tryParse(json['source_updated_at'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
      tleSource: 'beacon-api',
    );
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'name': name,
      'display_name': displayName,
      'norad_cat_id': noradCatId,
      'satnogs_id': satnogsId,
      'callsign': callsign,
      'aliases': aliases,
      'status': status,
      'countries': countries,
      'operator': operatorName,
      'website': website,
      'image_url': imageUrl,
      'amsat_name': amsatName,
      'amsat_display_name': amsatDisplayName,
      'amsat_report_count': amsatReportCount,
      'amsat_latest_reported_at': amsatLatestReportedAt?.toIso8601String(),
      'source_updated_at': sourceUpdatedAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  SatelliteCatalogItem copyWith({
    bool? subscribed,
  }) {
    return SatelliteCatalogItem(
      id: id,
      name: name,
      displayName: displayName,
      noradCatId: noradCatId,
      satnogsId: satnogsId,
      callsign: callsign,
      aliases: aliases,
      status: status,
      countries: countries,
      operatorName: operatorName,
      website: website,
      imageUrl: imageUrl,
      amsatName: amsatName,
      amsatDisplayName: amsatDisplayName,
      amsatReportCount: amsatReportCount,
      amsatLatestReportedAt: amsatLatestReportedAt,
      sourceUpdatedAt: sourceUpdatedAt,
      updatedAt: updatedAt,
      tleSource: tleSource,
      subscribed: subscribed ?? this.subscribed,
    );
  }
}

class SatelliteMapItem {
  final String name;
  final int? noradCatId;
  final SatellitePass? nextPass;
  final GroundTrackPoint? currentPosition;
  final List<GroundTrackPoint> groundTrack;

  const SatelliteMapItem({
    required this.name,
    this.noradCatId,
    this.nextPass,
    this.currentPosition,
    this.groundTrack = const [],
  });
}

class SatelliteDetail {
  final String name;
  final int? noradCatId;
  final SatelliteCatalogItem? catalogItem;
  final List<SatellitePass> passes;
  final List<SatelliteTransponder> transponders;
  final List<SatelliteStatusSummary> statusSummaries;
  final String tleSource;
  final DateTime? tleUpdatedAt;
  final GroundTrackPoint? currentPosition;
  final List<GroundTrackPoint> groundTrack;

  const SatelliteDetail({
    required this.name,
    this.noradCatId,
    this.catalogItem,
    required this.passes,
    required this.transponders,
    this.statusSummaries = const [],
    required this.tleSource,
    this.tleUpdatedAt,
    this.currentPosition,
    this.groundTrack = const [],
  });

  SatellitePass? get nextPass => passes.isEmpty ? null : passes.first;
}

class ObserverLocation {
  final double latitude;
  final double longitude;
  final double altitudeKm;
  final String label;
  final String source;

  const ObserverLocation({
    required this.latitude,
    required this.longitude,
    this.altitudeKm = 0,
    required this.label,
    required this.source,
  });
}

class GroundTrackPoint {
  final DateTime time;
  final double latitude;
  final double longitude;
  final double altitudeKm;

  const GroundTrackPoint({
    required this.time,
    required this.latitude,
    required this.longitude,
    required this.altitudeKm,
  });
}

class SatelliteLookSample {
  final DateTime time;
  final double elevation;
  final double azimuth;
  final double rangeKm;
  final double? dopplerFactor;
  final GroundTrackPoint groundPoint;

  const SatelliteLookSample({
    required this.time,
    required this.elevation,
    required this.azimuth,
    required this.rangeKm,
    this.dopplerFactor,
    required this.groundPoint,
  });
}

class SatelliteTransponder {
  final String description;
  final String type;
  final String mode;
  final int? uplinkLow;
  final int? downlinkLow;
  final bool alive;
  final String status;
  final DateTime? updatedAt;

  const SatelliteTransponder({
    required this.description,
    required this.type,
    required this.mode,
    this.uplinkLow,
    this.downlinkLow,
    required this.alive,
    required this.status,
    this.updatedAt,
  });

  factory SatelliteTransponder.fromJson(Map<String, dynamic> json) {
    return SatelliteTransponder(
      description: json['description'] as String? ?? '未命名转发器',
      type: json['type'] as String? ?? 'Transponder',
      mode: json['mode'] as String? ?? json['uplink_mode'] as String? ?? '',
      uplinkLow: (json['uplink_low'] as num?)?.toInt(),
      downlinkLow: (json['downlink_low'] as num?)?.toInt(),
      alive: json['alive'] as bool? ?? false,
      status: json['status'] as String? ?? 'unknown',
      updatedAt: DateTime.tryParse(json['updated'] as String? ?? ''),
    );
  }

  factory SatelliteTransponder.fromBeaconApiJson(Map<String, dynamic> json) {
    final uplink = json['uplink'] as String?;
    final downlink = json['downlink'] as String?;
    final beacon = json['beacon'] as String?;
    final mode = json['mode'] as String? ?? '';
    return SatelliteTransponder(
      description: [
        if (uplink != null && uplink.isNotEmpty) '上行 $uplink MHz',
        if (downlink != null && downlink.isNotEmpty) '下行 $downlink MHz',
        if (beacon != null && beacon.isNotEmpty) '信标 $beacon MHz',
      ].join(' / ').ifEmpty('卫星频率'),
      type: json['source'] as String? ?? 'beacon-api',
      mode: mode,
      uplinkLow: _mhzTextToHz(uplink),
      downlinkLow: _mhzTextToHz(downlink ?? beacon),
      alive: json['is_active'] as bool? ?? true,
      status: (json['is_active'] as bool?) == false ? 'inactive' : 'active',
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }
}

class SatelliteStatusSummary {
  final String amsatName;
  final String? satelliteDisplayName;
  final String report;
  final String reportLabel;
  final String statusLevel;
  final bool isPositive;
  final int reportCount;
  final DateTime? latestReportedAt;
  final DateTime? updatedAt;

  const SatelliteStatusSummary({
    required this.amsatName,
    this.satelliteDisplayName,
    required this.report,
    this.reportLabel = '',
    this.statusLevel = 'unknown',
    this.isPositive = false,
    required this.reportCount,
    this.latestReportedAt,
    this.updatedAt,
  });

  factory SatelliteStatusSummary.fromJson(Map<String, dynamic> json) {
    return SatelliteStatusSummary(
      amsatName: json['amsat_name'] as String? ?? '',
      satelliteDisplayName: json['satellite_display_name'] as String?,
      report: json['report'] as String? ?? 'unknown',
      reportLabel: json['report_label'] as String? ?? '',
      statusLevel: json['status_level'] as String? ?? 'unknown',
      isPositive: json['is_positive'] as bool? ?? false,
      reportCount: (json['report_count'] as num?)?.toInt() ?? 0,
      latestReportedAt:
          DateTime.tryParse(json['latest_reported_at'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toLocalMap(String satelliteId) {
    return {
      'satellite_id': satelliteId,
      'amsat_name': amsatName,
      'satellite_display_name': satelliteDisplayName,
      'report': report,
      'report_label': reportLabel,
      'status_level': statusLevel,
      'is_positive': isPositive ? 1 : 0,
      'report_count': reportCount,
      'latest_reported_at': latestReportedAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

extension _StringEmptyFallback on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

int? _mhzTextToHz(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final match = RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(value);
  final mhz = double.tryParse(match?.group(1) ?? '');
  return mhz == null ? null : (mhz * 1000000).round();
}
