class SepcDailyReport {
  final String sourceName;
  final String sourceUrl;
  final String title;
  final String summary;
  final String forecast;
  final String kp;
  final String f107;
  final String sunspots;
  final String solarWindSpeed;
  final String forecaster;
  final String issuedAt;
  final List<String> imageBase64List;
  final String imageVersion;
  final String imageBaseUrl;

  const SepcDailyReport({
    required this.sourceName,
    required this.sourceUrl,
    required this.title,
    required this.summary,
    this.forecast = '',
    this.kp = '',
    this.f107 = '',
    this.sunspots = '',
    this.solarWindSpeed = '',
    required this.forecaster,
    required this.issuedAt,
    this.imageBase64List = const [],
    this.imageVersion = '',
    this.imageBaseUrl = '',
  });

  factory SepcDailyReport.fromJson(Map<String, dynamic> json) {
    return SepcDailyReport(
      sourceName: json['sourceName']?.toString() ?? '',
      sourceUrl: json['sourceUrl']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      forecast: json['forecast']?.toString() ?? '',
      kp: json['kp']?.toString() ?? '',
      f107: json['f107']?.toString() ?? '',
      sunspots: json['sunspots']?.toString() ?? '',
      solarWindSpeed: json['solarWindSpeed']?.toString() ?? '',
      forecaster: json['forecaster']?.toString() ?? '',
      issuedAt: json['issuedAt']?.toString() ?? '',
      imageBase64List: (json['imageBase64List'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      imageVersion: json['imageVersion']?.toString() ?? '',
      imageBaseUrl: json['imageBaseUrl']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sourceName': sourceName,
      'sourceUrl': sourceUrl,
      'title': title,
      'summary': summary,
      'forecast': forecast,
      'kp': kp,
      'f107': f107,
      'sunspots': sunspots,
      'solarWindSpeed': solarWindSpeed,
      'forecaster': forecaster,
      'issuedAt': issuedAt,
      'imageBase64List': imageBase64List,
      'imageVersion': imageVersion,
      'imageBaseUrl': imageBaseUrl,
    };
  }
}
