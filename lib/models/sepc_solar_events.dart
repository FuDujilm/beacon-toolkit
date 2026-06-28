class SepcSolarFlareEvent {
  final DateTime startTime;
  final DateTime endTime;
  final String level;
  final String rotation;

  const SepcSolarFlareEvent({
    required this.startTime,
    required this.endTime,
    required this.level,
    required this.rotation,
  });

  Duration get duration => endTime.difference(startTime);
}

class SepcSolarFlareReport {
  final String sourceName;
  final String sourceUrl;
  final List<SepcSolarFlareEvent> events;

  const SepcSolarFlareReport({
    required this.sourceName,
    required this.sourceUrl,
    required this.events,
  });
}

class SepcSidEvent {
  final DateTime peakTime;
  final String level;
  final String description;
  final String mapUrl;

  const SepcSidEvent({
    required this.peakTime,
    required this.level,
    required this.description,
    required this.mapUrl,
  });
}

class SepcSidReport {
  final String sourceName;
  final String sourceUrl;
  final List<SepcSidEvent> events;

  const SepcSidReport({
    required this.sourceName,
    required this.sourceUrl,
    required this.events,
  });
}
