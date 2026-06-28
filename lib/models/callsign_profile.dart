class CallsignProfile {
  final String source;
  final String callsign;
  final String? displayName;
  final String? firstName;
  final String? lastName;
  final String? nickname;
  final String? country;
  final String? address;
  final String? grid;
  final double? latitude;
  final double? longitude;
  final String? email;
  final String? url;
  final String? imageUrl;
  final String? qsl;
  final String? cqZone;
  final String? ituZone;
  final DxccInfo? dxcc;
  final String? biographyHtml;
  final String? rawUpdatedAt;

  const CallsignProfile({
    required this.source,
    required this.callsign,
    this.displayName,
    this.firstName,
    this.lastName,
    this.nickname,
    this.country,
    this.address,
    this.grid,
    this.latitude,
    this.longitude,
    this.email,
    this.url,
    this.imageUrl,
    this.qsl,
    this.cqZone,
    this.ituZone,
    this.dxcc,
    this.biographyHtml,
    this.rawUpdatedAt,
  });

  factory CallsignProfile.fromJson(Map<String, dynamic> json) {
    return CallsignProfile(
      source: json['source'] as String? ?? '',
      callsign: json['callsign'] as String? ?? '',
      displayName: json['display_name'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      nickname: json['nickname'] as String?,
      country: json['country'] as String?,
      address: json['address'] as String?,
      grid: json['grid'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      email: json['email'] as String?,
      url: json['url'] as String?,
      imageUrl: json['image_url'] as String?,
      qsl: json['qsl'] as String?,
      cqZone: json['cq_zone'] as String?,
      ituZone: json['itu_zone'] as String?,
      dxcc: json['dxcc'] is Map<String, dynamic>
          ? DxccInfo.fromJson(json['dxcc'] as Map<String, dynamic>)
          : null,
      biographyHtml: json['biography_html'] as String?,
      rawUpdatedAt: json['raw_updated_at'] as String?,
    );
  }

  CallsignProfile copyWith({
    DxccInfo? dxcc,
    String? biographyHtml,
  }) {
    return CallsignProfile(
      source: source,
      callsign: callsign,
      displayName: displayName,
      firstName: firstName,
      lastName: lastName,
      nickname: nickname,
      country: country,
      address: address,
      grid: grid,
      latitude: latitude,
      longitude: longitude,
      email: email,
      url: url,
      imageUrl: imageUrl,
      qsl: qsl,
      cqZone: cqZone,
      ituZone: ituZone,
      dxcc: dxcc ?? this.dxcc,
      biographyHtml: biographyHtml ?? this.biographyHtml,
      rawUpdatedAt: rawUpdatedAt,
    );
  }
}

class DxccInfo {
  final String? dxcc;
  final String? name;
  final String? continent;
  final String? countryCode;
  final double? latitude;
  final double? longitude;
  final String? timezone;
  final String? cqZone;
  final String? ituZone;
  final String? notes;

  const DxccInfo({
    this.dxcc,
    this.name,
    this.continent,
    this.countryCode,
    this.latitude,
    this.longitude,
    this.timezone,
    this.cqZone,
    this.ituZone,
    this.notes,
  });

  factory DxccInfo.fromJson(Map<String, dynamic> json) {
    return DxccInfo(
      dxcc: json['dxcc'] as String?,
      name: json['name'] as String?,
      continent: json['continent'] as String?,
      countryCode: json['country_code'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      timezone: json['timezone'] as String?,
      cqZone: json['cq_zone'] as String?,
      ituZone: json['itu_zone'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

class CallsignLookupResult {
  final List<CallsignProfile> items;
  final List<String> warnings;
  final List<String> debugLogs;

  const CallsignLookupResult({
    required this.items,
    this.warnings = const [],
    this.debugLogs = const [],
  });
}
