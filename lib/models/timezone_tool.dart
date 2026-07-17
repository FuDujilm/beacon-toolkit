class TimezonePoint {
  final double latitude;
  final double longitude;
  final int utcOffsetMinutes;
  final String label;

  const TimezonePoint({
    required this.latitude,
    required this.longitude,
    required this.utcOffsetMinutes,
    required this.label,
  });

  DateTime localTimeAt(DateTime utcTime) {
    return utcTime.add(Duration(minutes: utcOffsetMinutes));
  }

  String get utcOffsetLabel {
    final sign = utcOffsetMinutes >= 0 ? '+' : '-';
    final absolute = utcOffsetMinutes.abs();
    final hours = absolute ~/ 60;
    final minutes = absolute % 60;
    return 'UTC$sign${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }
}

class TimezoneComparisonResult {
  final DateTime timeA;
  final DateTime timeB;
  final int differenceMinutes;
  final int dayShift;

  const TimezoneComparisonResult({
    required this.timeA,
    required this.timeB,
    required this.differenceMinutes,
    required this.dayShift,
  });
}
