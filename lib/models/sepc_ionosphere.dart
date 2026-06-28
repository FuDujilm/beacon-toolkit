class SepcIonosphereStation {
  final String code;
  final String name;
  final double longitude;
  final double latitude;

  const SepcIonosphereStation({
    required this.code,
    required this.name,
    required this.longitude,
    required this.latitude,
  });
}

enum SepcIonosphereProduct {
  scintillation,
  tec,
}

class SepcIonosphereImage {
  final String sourceName;
  final String sourceUrl;
  final SepcIonosphereStation station;
  final SepcIonosphereProduct product;
  final DateTime date;
  final String imageUrl;

  const SepcIonosphereImage({
    required this.sourceName,
    required this.sourceUrl,
    required this.station,
    required this.product,
    required this.date,
    required this.imageUrl,
  });
}
