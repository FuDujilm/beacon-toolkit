class RadioProfile {
  final String callsign;
  final String qth;
  final String grid;
  final double? latitude;
  final double? longitude;
  final String licenseClass;
  final String licenseExpiry;

  const RadioProfile({
    required this.callsign,
    required this.qth,
    required this.grid,
    this.latitude,
    this.longitude,
    required this.licenseClass,
    required this.licenseExpiry,
  });

  static const defaults = RadioProfile(
    callsign: '未设置',
    qth: '未设置 QTH',
    grid: '未设置 Grid',
    licenseClass: 'A 级',
    licenseExpiry: '未设置到期日',
  );

  RadioProfile copyWith({
    String? callsign,
    String? qth,
    String? grid,
    double? latitude,
    double? longitude,
    String? licenseClass,
    String? licenseExpiry,
  }) {
    return RadioProfile(
      callsign: callsign ?? this.callsign,
      qth: qth ?? this.qth,
      grid: grid ?? this.grid,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      licenseClass: licenseClass ?? this.licenseClass,
      licenseExpiry: licenseExpiry ?? this.licenseExpiry,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'callsign': callsign,
      'qth': qth,
      'grid': grid,
      'latitude': latitude,
      'longitude': longitude,
      'licenseClass': licenseClass,
      'licenseExpiry': licenseExpiry,
    };
  }

  factory RadioProfile.fromJson(Map<String, dynamic> json) {
    return RadioProfile(
      callsign: json['callsign'] as String? ?? defaults.callsign,
      qth: json['qth'] as String? ?? defaults.qth,
      grid: json['grid'] as String? ?? defaults.grid,
      latitude: _doubleFromJson(json['latitude']),
      longitude: _doubleFromJson(json['longitude']),
      licenseClass: json['licenseClass'] as String? ?? defaults.licenseClass,
      licenseExpiry: json['licenseExpiry'] as String? ?? defaults.licenseExpiry,
    );
  }

  static double? _doubleFromJson(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
