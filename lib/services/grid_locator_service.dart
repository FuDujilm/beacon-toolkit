import 'dart:math';

class GridPoint {
  final double latitude;
  final double longitude;

  const GridPoint({
    required this.latitude,
    required this.longitude,
  });
}

class GridBounds {
  final double south;
  final double west;
  final double north;
  final double east;

  const GridBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  GridPoint get center => GridPoint(
        latitude: (south + north) / 2,
        longitude: (west + east) / 2,
      );

  bool contains(GridPoint point) {
    return point.latitude >= south &&
        point.latitude <= north &&
        point.longitude >= west &&
        point.longitude <= east;
  }
}

class GridCell {
  final String locator;
  final int precision;
  final GridPoint center;
  final GridBounds bounds;

  const GridCell({
    required this.locator,
    required this.precision,
    required this.center,
    required this.bounds,
  });
}

class GridLocatorService {
  const GridLocatorService();

  static const supportedPrecisions = [4, 6, 8, 10];

  String encodeMaidenhead({
    required double latitude,
    required double longitude,
    int precision = 6,
  }) {
    _validatePrecision(precision);
    if (latitude < -90 || latitude > 90) {
      throw const FormatException('纬度必须在 -90 到 90 之间');
    }
    if (longitude < -180 || longitude > 180) {
      throw const FormatException('经度必须在 -180 到 180 之间');
    }

    final safeLat = latitude == 90 ? 89.999999999 : latitude;
    final safeLon = longitude == 180 ? 179.999999999 : longitude;
    var lon = safeLon + 180;
    var lat = safeLat + 90;
    final buffer = StringBuffer();

    buffer.writeCharCode(65 + (lon / 20).floor());
    buffer.writeCharCode(65 + (lat / 10).floor());
    lon %= 20;
    lat %= 10;

    buffer.write((lon / 2).floor());
    buffer.write(lat.floor());
    lon %= 2;
    lat %= 1;

    if (precision >= 6) {
      buffer.writeCharCode(97 + (lon * 12).floor());
      buffer.writeCharCode(97 + (lat * 24).floor());
      lon = (lon * 12) % 1;
      lat = (lat * 24) % 1;
    }

    if (precision >= 8) {
      buffer.write((lon * 10).floor());
      buffer.write((lat * 10).floor());
      lon = (lon * 10) % 1;
      lat = (lat * 10) % 1;
    }

    if (precision >= 10) {
      buffer.writeCharCode(97 + (lon * 24).floor());
      buffer.writeCharCode(97 + (lat * 24).floor());
    }

    return buffer.toString();
  }

  GridCell decodeMaidenhead(String grid) {
    final normalized = _normalizeGrid(grid);
    final precision = normalized.length;
    var west = -180.0;
    var south = -90.0;
    var lonSize = 20.0;
    var latSize = 10.0;

    west += _letterValue(normalized[0], max: 18) * lonSize;
    south += _letterValue(normalized[1], max: 18) * latSize;

    lonSize = 2;
    latSize = 1;
    west += _digitValue(normalized[2]) * lonSize;
    south += _digitValue(normalized[3]) * latSize;

    if (precision >= 6) {
      lonSize /= 24;
      latSize /= 24;
      west += _letterValue(normalized[4], max: 24) * lonSize;
      south += _letterValue(normalized[5], max: 24) * latSize;
    }

    if (precision >= 8) {
      lonSize /= 10;
      latSize /= 10;
      west += _digitValue(normalized[6]) * lonSize;
      south += _digitValue(normalized[7]) * latSize;
    }

    if (precision >= 10) {
      lonSize /= 24;
      latSize /= 24;
      west += _letterValue(normalized[8], max: 24) * lonSize;
      south += _letterValue(normalized[9], max: 24) * latSize;
    }

    final bounds = GridBounds(
      south: south,
      west: west,
      north: min(90, south + latSize),
      east: min(180, west + lonSize),
    );
    return GridCell(
      locator: _formatGrid(normalized),
      precision: precision,
      center: bounds.center,
      bounds: bounds,
    );
  }

  String _normalizeGrid(String grid) {
    final normalized = grid.trim().replaceAll(RegExp(r'\s+'), '');
    if (!supportedPrecisions.contains(normalized.length)) {
      throw const FormatException('Grid 长度必须为 4、6、8 或 10 位');
    }
    if (!_isLetter(normalized[0]) || !_isLetter(normalized[1])) {
      throw const FormatException('Grid 前两位必须为 A-R 字母');
    }
    if (!_isDigit(normalized[2]) || !_isDigit(normalized[3])) {
      throw const FormatException('Grid 第 3-4 位必须为数字');
    }
    if (normalized.length >= 6 &&
        (!_isLetter(normalized[4]) || !_isLetter(normalized[5]))) {
      throw const FormatException('Grid 第 5-6 位必须为 A-X 字母');
    }
    if (normalized.length >= 8 &&
        (!_isDigit(normalized[6]) || !_isDigit(normalized[7]))) {
      throw const FormatException('Grid 第 7-8 位必须为数字');
    }
    if (normalized.length >= 10 &&
        (!_isLetter(normalized[8]) || !_isLetter(normalized[9]))) {
      throw const FormatException('Grid 第 9-10 位必须为 A-X 字母');
    }
    return normalized.toUpperCase();
  }

  String _formatGrid(String normalized) {
    final buffer = StringBuffer(normalized.substring(0, 4));
    if (normalized.length >= 6) {
      buffer.write(normalized.substring(4, 6).toLowerCase());
    }
    if (normalized.length >= 8) {
      buffer.write(normalized.substring(6, 8));
    }
    if (normalized.length >= 10) {
      buffer.write(normalized.substring(8, 10).toLowerCase());
    }
    return buffer.toString();
  }

  int _letterValue(String value, {required int max}) {
    final code = value.toUpperCase().codeUnitAt(0) - 65;
    if (code < 0 || code >= max) {
      throw FormatException(max == 18 ? 'Grid 字段必须为 A-R' : 'Grid 子字段必须为 A-X');
    }
    return code;
  }

  int _digitValue(String value) {
    final result = int.tryParse(value);
    if (result == null || result < 0 || result > 9) {
      throw const FormatException('Grid 数字段必须为 0-9');
    }
    return result;
  }

  bool _isLetter(String value) {
    final code = value.codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }

  bool _isDigit(String value) {
    final code = value.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }

  void _validatePrecision(int precision) {
    if (!supportedPrecisions.contains(precision)) {
      throw const FormatException('Grid 精度必须为 4、6、8 或 10 位');
    }
  }
}
