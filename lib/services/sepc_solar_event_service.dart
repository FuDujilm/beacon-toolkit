import 'package:charset/charset.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:intl/intl.dart';

import '../core/configure_dio.dart';
import '../models/sepc_solar_events.dart';

class SepcSolarEventService {
  static const String sxrSourceName = 'SEPC X 射线耀斑事件';
  static const String sxrSourceUrl = 'http://www.sepc.ac.cn/SXR_chn.php';
  static const String sidSourceName = 'SEPC 电离层突然骚扰';
  static const String sidSourceUrl = 'http://www.sepc.ac.cn/SID.php';
  static const String _sxrApiUrl = 'http://www.sepc.ac.cn/getSXR_js.php';
  static const String _sidApiUrl = 'http://www.sepc.ac.cn/getSidForecast1.php';
  static const String _baseUrl = 'http://www.sepc.ac.cn/';

  final Dio _jsonDio;
  final Dio _bytesDio;

  SepcSolarEventService({Dio? jsonDio, Dio? bytesDio})
      : _jsonDio = jsonDio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 20),
                responseType: ResponseType.json,
                headers: const {
                  'Accept': 'application/json,text/plain,*/*',
                  'User-Agent': 'Mozilla/5.0',
                  'Referer': sxrSourceUrl,
                },
              ),
            ),
        _bytesDio = bytesDio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 20),
                responseType: ResponseType.bytes,
                headers: const {
                  'Accept': 'text/html,*/*',
                  'User-Agent': 'Mozilla/5.0',
                  'Referer': sidSourceUrl,
                },
              ),
            ) {
    configureDio(_jsonDio);
    configureDio(_bytesDio);
  }

  Future<SepcSolarFlareReport> fetchSolarFlares({DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final startTime = DateFormat('yyyyMMdd').format(targetDate);
    try {
      final response = await _jsonDio.get<dynamic>(
        _sxrApiUrl,
        queryParameters: {
          'starttime': startTime,
          'sid': DateTime.now().microsecondsSinceEpoch / 1000000,
        },
      );
      return _parseSolarFlares(_asReportList(response.data));
    } on DioException catch (e) {
      if (date == null) {
        return fetchSolarFlares(
          date: targetDate.subtract(const Duration(days: 1)),
        );
      }
      throw FormatException(_friendlyDioError('SEPC X 射线耀斑事件', e));
    } on FormatException {
      if (date == null) {
        return fetchSolarFlares(
          date: targetDate.subtract(const Duration(days: 1)),
        );
      }
      return const SepcSolarFlareReport(
        sourceName: sxrSourceName,
        sourceUrl: sxrSourceUrl,
        events: [],
      );
    }
  }

  Future<SepcSidReport> fetchSidEvents({
    DateTime? now,
    int days = 30,
    int pageSize = 8,
  }) async {
    final end = now ?? DateTime.now();
    final start = end.subtract(Duration(days: days));
    final formatter = DateFormat('yyyyMMdd');
    try {
      final response = await _bytesDio.get<List<int>>(
        _sidApiUrl,
        queryParameters: {
          'starttime': formatter.format(start),
          'endtime': formatter.format(end),
          'nowpage': 1,
          'pagesize': pageSize,
          'sid': DateTime.now().microsecondsSinceEpoch / 1000000,
        },
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException('SEPC SID 事件返回空数据');
      }
      return _parseSidEvents(gbk.decode(bytes));
    } on DioException catch (e) {
      throw FormatException(_friendlyDioError('SEPC SID 事件', e));
    } on FormatException {
      rethrow;
    }
  }

  List<dynamic> _asReportList(Object? data) {
    if (data is List) return data;
    return const [];
  }

  SepcSolarFlareReport _parseSolarFlares(List<dynamic> rawReports) {
    final events = <SepcSolarFlareEvent>[];
    for (final rawReport in rawReports) {
      if (rawReport is! Map) continue;
      final rotation = rawReport['cr']?.toString() ?? '';
      final rawEvents = rawReport['data'];
      if (rawEvents is! List) continue;
      DateTime? pendingStart;
      String? pendingLevel;
      for (final rawEvent in rawEvents) {
        if (rawEvent is! List || rawEvent.length < 3) continue;
        final code = rawEvent[0]?.toString() ?? '';
        final time = _parseCompactDateTime(
          rawEvent[1]?.toString() ?? '',
          rawEvent[2]?.toString() ?? '',
        );
        if (time == null) continue;
        if (code.startsWith('JX')) {
          pendingStart = time;
          pendingLevel = _flareLevelFromCode(code);
          continue;
        }
        if (pendingStart == null) continue;
        final level = _flareLevelFromCode(code, fallback: pendingLevel);
        if (level == null) continue;
        events.add(
          SepcSolarFlareEvent(
            startTime: pendingStart,
            endTime: time.isBefore(pendingStart) ? pendingStart : time,
            level: level,
            rotation: rotation,
          ),
        );
        pendingStart = null;
        pendingLevel = null;
      }
    }
    events.sort((a, b) => b.startTime.compareTo(a.startTime));
    return SepcSolarFlareReport(
      sourceName: sxrSourceName,
      sourceUrl: sxrSourceUrl,
      events: events,
    );
  }

  SepcSidReport _parseSidEvents(String html) {
    final document = html_parser.parse(html);
    final rows = document.querySelectorAll('tr').skip(1);
    final events = <SepcSidEvent>[];
    for (final row in rows) {
      final cells = row.querySelectorAll('td');
      if (cells.length < 3) continue;
      final peakTime = _parseSidTime(cells[0].text.trim());
      if (peakTime == null) continue;
      final description = cells[1].text.trim().replaceAll(RegExp(r'\s+'), ' ');
      final link = cells[2].querySelector('a')?.attributes['href'] ?? '';
      final level = _extractFlareLevel(description) ?? '';
      events.add(
        SepcSidEvent(
          peakTime: peakTime,
          level: level,
          description: _translateSidDescription(description),
          mapUrl: _normalizeSidMapUrl(link),
        ),
      );
    }
    if (events.isEmpty) {
      throw const FormatException('SEPC SID 事件没有有效记录');
    }
    return SepcSidReport(
      sourceName: sidSourceName,
      sourceUrl: sidSourceUrl,
      events: events,
    );
  }

  DateTime? _parseCompactDateTime(String date, String time) {
    if (date.length < 8) return null;
    final paddedTime = time.padLeft(6, '0');
    return DateTime.tryParse(
      '${date.substring(0, 4)}-'
      '${date.substring(4, 6)}-'
      '${date.substring(6, 8)} '
      '${paddedTime.substring(0, 2)}:'
      '${paddedTime.substring(2, 4)}:'
      '${paddedTime.substring(4, 6)}',
    );
  }

  DateTime? _parseSidTime(String value) {
    final match =
        RegExp(r'(\d{4})/(\d{2})/(\d{2})\s+(\d{2}):(\d{2})').firstMatch(value);
    if (match == null) return null;
    return DateTime.tryParse(
      '${match.group(1)}-${match.group(2)}-${match.group(3)} '
      '${match.group(4)}:${match.group(5)}:00',
    );
  }

  String? _flareLevelFromCode(String code, {String? fallback}) {
    final match = RegExp(r'([CMX]\d+(?:\.\d+)?|M5)$').firstMatch(code);
    final level = match?.group(1) ?? fallback;
    if (level == null) return null;
    if (level == 'M5') return 'M5+';
    return level;
  }

  String? _extractFlareLevel(String value) {
    return RegExp(r'([CMX]\d+(?:\.\d+)?)\s+Class').firstMatch(value)?.group(1);
  }

  String _translateSidDescription(String value) {
    final level = _extractFlareLevel(value);
    if (level == null) return value;
    return '$level 级 X 射线太阳耀斑事件';
  }

  String _normalizeSidMapUrl(String link) {
    final uri = Uri.parse(_baseUrl).resolve(link.trim());
    return uri.replace(
      queryParameters: {
        for (final entry in uri.queryParameters.entries)
          entry.key.trim(): entry.value.trim(),
      },
    ).toString();
  }

  String _friendlyDioError(String label, DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return '连接 $label 接口超时';
    }
    if (e.type == DioExceptionType.connectionError) {
      return '无法连接 $label 接口，请检查网络';
    }
    final status = e.response?.statusCode;
    if (status != null) return '$label 接口返回 HTTP $status';
    return e.message ?? '$label 请求失败';
  }
}
