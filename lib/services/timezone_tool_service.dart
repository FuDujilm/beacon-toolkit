import 'dart:math';

import '../models/timezone_tool.dart';

class DayNightTerminatorPoint {
  final double latitude;
  final double longitude;

  const DayNightTerminatorPoint({
    required this.latitude,
    required this.longitude,
  });
}

class TimezoneToolService {
  static const List<_SpecialOffsetBand> _specialOffsetBands = [
    _SpecialOffsetBand(
        minLongitude: 73, maxLongitude: 82.5, offsetMinutes: 330),
    _SpecialOffsetBand(
        minLongitude: 82.5, maxLongitude: 88.5, offsetMinutes: 345),
    _SpecialOffsetBand(
        minLongitude: 126, maxLongitude: 131.5, offsetMinutes: 525),
    _SpecialOffsetBand(
        minLongitude: 131.5, maxLongitude: 136.5, offsetMinutes: 570),
    _SpecialOffsetBand(
        minLongitude: 136.5, maxLongitude: 142.5, offsetMinutes: 630),
    _SpecialOffsetBand(
        minLongitude: 177, maxLongitude: 180, offsetMinutes: 765),
    _SpecialOffsetBand(
        minLongitude: -180, maxLongitude: -174, offsetMinutes: 765),
    _SpecialOffsetBand(
      minLongitude: -60,
      maxLongitude: -52.5,
      offsetMinutes: -210,
    ),
  ];

  const TimezoneToolService();

  TimezonePoint resolvePoint({
    required double latitude,
    required double longitude,
    required String label,
  }) {
    final offset = estimateUtcOffsetMinutes(
      latitude: latitude,
      longitude: longitude,
    );
    return TimezonePoint(
      latitude: latitude,
      longitude: longitude,
      utcOffsetMinutes: offset,
      label: label,
    );
  }

  int estimateUtcOffsetMinutes({
    required double latitude,
    required double longitude,
  }) {
    final normalizedLongitude = _normalizeLongitude(longitude);
    final specialOffset = _specialOffsetForLongitude(normalizedLongitude);
    if (specialOffset != null) return specialOffset;
    final roundedHours =
        (((normalizedLongitude + 7.5) / 15).floor()).clamp(-12, 14);
    return roundedHours * 60;
  }

  TimezoneComparisonResult compare({
    required TimezonePoint pointA,
    required TimezonePoint pointB,
    required DateTime utcTime,
  }) {
    final timeA = pointA.localTimeAt(utcTime);
    final timeB = pointB.localTimeAt(utcTime);
    final differenceMinutes = pointB.utcOffsetMinutes - pointA.utcOffsetMinutes;
    final dayShift = DateTime(
      timeB.year,
      timeB.month,
      timeB.day,
    ).difference(DateTime(timeA.year, timeA.month, timeA.day)).inDays;
    return TimezoneComparisonResult(
      timeA: timeA,
      timeB: timeB,
      differenceMinutes: differenceMinutes,
      dayShift: dayShift,
    );
  }

  bool isDaylight({
    required double latitude,
    required double longitude,
    required DateTime utcTime,
  }) {
    final solarDeclination = _solarDeclinationRadians(utcTime);
    final subsolarLongitude = _subsolarLongitudeDegrees(utcTime);
    final latRad = _degreesToRadians(latitude.clamp(-89.9, 89.9));
    final lonDeltaRad =
        _degreesToRadians(_normalizeLongitude(longitude - subsolarLongitude));
    final altitude = asin(
      sin(latRad) * sin(solarDeclination) +
          cos(latRad) * cos(solarDeclination) * cos(lonDeltaRad),
    );
    return altitude > 0;
  }

  List<DayNightTerminatorPoint> buildTerminator({
    required DateTime utcTime,
    int longitudeStep = 4,
  }) {
    final solarDeclination = _solarDeclinationRadians(utcTime);
    final subsolarLongitude = _subsolarLongitudeDegrees(utcTime);
    final points = <DayNightTerminatorPoint>[];
    for (var longitude = -180; longitude <= 180; longitude += longitudeStep) {
      final lonDeltaRad =
          _degreesToRadians(_normalizeLongitude(longitude - subsolarLongitude));
      final denominator = tan(solarDeclination);
      final latitude = denominator.abs() < 1e-6
          ? 0.0
          : _radiansToDegrees(atan(-cos(lonDeltaRad) / denominator))
              .clamp(-89.9, 89.9);
      points.add(
        DayNightTerminatorPoint(
          latitude: latitude,
          longitude: longitude.toDouble(),
        ),
      );
    }
    return points;
  }

  double zoneCenterLongitude(int offsetMinutes) {
    return (offsetMinutes / 60) * 15;
  }

  double _normalizeLongitude(double longitude) {
    final normalized = ((longitude + 180) % 360 + 360) % 360 - 180;
    if (normalized == -180) return 180;
    return normalized;
  }

  int? _specialOffsetForLongitude(double longitude) {
    for (final band in _specialOffsetBands) {
      if (longitude >= band.minLongitude && longitude < band.maxLongitude) {
        return band.offsetMinutes;
      }
    }
    return null;
  }

  double _solarDeclinationRadians(DateTime utcTime) {
    final dayOfYear = int.parse(_dayOfYear(utcTime).toString());
    final fractionalHour =
        utcTime.hour + utcTime.minute / 60 + utcTime.second / 3600;
    final gamma = 2 * pi / 365 * (dayOfYear - 1 + (fractionalHour - 12) / 24);
    return 0.006918 -
        0.399912 * cos(gamma) +
        0.070257 * sin(gamma) -
        0.006758 * cos(2 * gamma) +
        0.000907 * sin(2 * gamma) -
        0.002697 * cos(3 * gamma) +
        0.00148 * sin(3 * gamma);
  }

  double _subsolarLongitudeDegrees(DateTime utcTime) {
    final hours = utcTime.hour +
        utcTime.minute / 60 +
        utcTime.second / 3600 +
        utcTime.millisecond / 3600000;
    return _normalizeLongitude((12 - hours) * 15);
  }

  int _dayOfYear(DateTime dateTime) {
    final start = DateTime.utc(dateTime.year, 1, 1);
    return dateTime.difference(start).inDays + 1;
  }

  double _degreesToRadians(double degrees) => degrees * pi / 180;

  double _radiansToDegrees(double radians) => radians * 180 / pi;
}

class _SpecialOffsetBand {
  final double minLongitude;
  final double maxLongitude;
  final int offsetMinutes;

  const _SpecialOffsetBand({
    required this.minLongitude,
    required this.maxLongitude,
    required this.offsetMinutes,
  });
}
