enum SepcTecMapProduct {
  tec,
  roti,
  deltaTec,
}

class SepcTecMapImage {
  final SepcTecMapProduct product;
  final String title;
  final String imageUrl;

  const SepcTecMapImage({
    required this.product,
    required this.title,
    required this.imageUrl,
  });
}

class SepcTecMapReport {
  final String sourceName;
  final String sourceUrl;
  final List<SepcTecMapImage> images;

  const SepcTecMapReport({
    required this.sourceName,
    required this.sourceUrl,
    required this.images,
  });
}
