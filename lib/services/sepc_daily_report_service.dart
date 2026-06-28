import 'dart:convert';

import 'package:charset/charset.dart';
import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart';

import '../core/configure_dio.dart';
import '../models/sepc_daily_report.dart';
import 'local_database_service.dart';

class SepcDailyReportService {
  static const String sourceUrl = 'http://www.sepc.ac.cn/dailyForecast_chn.php';
  static const String rpcUrl = 'http://159.226.23.81:4004';
  static const String sourceName = '空间环境预报中心 SEPC';
  static const String _cacheKey = 'sepc_daily_report_cache';
  static const String _cacheTimeKey = 'sepc_daily_report_cache_time';

  final Dio _dio;
  final Dio _rpcDio;
  final LocalDatabaseService _databaseService;

  SepcDailyReportService({
    Dio? dio,
    Dio? rpcDio,
    LocalDatabaseService? databaseService,
  })  : _databaseService = databaseService ?? LocalDatabaseService(),
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 20),
                responseType: ResponseType.bytes,
                headers: const {
                  'Accept': 'text/html,*/*',
                  'User-Agent': 'Mozilla/5.0',
                },
              ),
            ),
        _rpcDio = rpcDio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 25),
                responseType: ResponseType.plain,
                headers: const {
                  'Content-Type': 'text/xml',
                  'User-Agent': 'Apache-HttpClient/UNAVAILABLE (java 1.4)',
                  'Connection': 'Keep-Alive',
                },
              ),
            ) {
    configureDio(_dio);
    configureDio(_rpcDio);
  }

  Future<SepcDailyReport> fetchDailyReport() async {
    try {
      final report = await _fetchDailyReportFromRpc();
      await _saveCache(report);
      return report;
    } catch (rpcError) {
      try {
        final report = await _fetchDailyReportFromHtml();
        await _saveCache(report);
        return report;
      } catch (htmlError) {
        final cached = await _readCache();
        if (cached != null) return cached;
        throw htmlError is FormatException
            ? htmlError
            : FormatException(htmlError.toString());
      }
    }
  }

  Future<SepcDailyReport> _fetchDailyReportFromRpc({
    String imageVersion = '',
  }) async {
    try {
      final response = await _rpcDio.post<String>(
        rpcUrl,
        data: _buildRpcRequest(imageVersion),
      );
      final body = response.data;
      if (body == null || body.trim().isEmpty) {
        throw const FormatException('SEPC XML-RPC 返回空数据');
      }
      return _parseRpcResponse(body);
    } on DioException catch (e) {
      throw FormatException(_friendlyDioError(e));
    }
  }

  Future<void> _saveCache(SepcDailyReport report) async {
    await _databaseService.saveSetting(_cacheKey, jsonEncode(report.toJson()));
    await _databaseService.saveSetting(
      _cacheTimeKey,
      DateTime.now().toIso8601String(),
    );
  }

  Future<SepcDailyReport?> _readCache() async {
    final raw = await _databaseService.getSetting(_cacheKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return SepcDailyReport.fromJson(json);
    } catch (_) {
      await _databaseService.deleteSetting(_cacheKey);
      await _databaseService.deleteSetting(_cacheTimeKey);
      return null;
    }
  }

  Future<SepcDailyReport> _fetchDailyReportFromHtml() async {
    try {
      final response = await _dio.get<List<int>>(sourceUrl);
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException('SEPC 返回空数据');
      }
      final html = gbk.decode(bytes);
      return _parseReport(html);
    } on DioException catch (e) {
      throw FormatException(_friendlyDioError(e));
    }
  }

  String _buildRpcRequest(String imageVersion) {
    return "<?xml version='1.0' ?><methodCall><methodName>getMainPageData</methodName><params><param><value><string>$imageVersion</string></value></param></params></methodCall>";
  }

  SepcDailyReport _parseRpcResponse(String xml) {
    final document = XmlDocument.parse(xml);
    final values = document
        .findAllElements('value')
        .map((element) => _RpcValue.fromXml(element))
        .where((value) => value.text.isNotEmpty)
        .toList();
    final data = values.map((value) => value.text).toList();
    final mainDataIndex = data.indexWhere(
      (value) => value.contains('过去24小时') && value.contains('@'),
    );
    if (mainDataIndex < 0) {
      throw const FormatException('SEPC XML-RPC 缺少主数据');
    }

    final mainData = data[mainDataIndex];
    final imageBase64List = values
        .where((value) => value.isBase64 && value.text.length > 128)
        .map((value) => value.text)
        .toList();
    final imageVersion = data
        .skip(mainDataIndex + 1)
        .firstWhere(_looksLikeImageVersion, orElse: () => '');
    final imageBaseUrl = data.skip(mainDataIndex + 1).firstWhere(
          (value) =>
              value.startsWith('http://') || value.startsWith('https://'),
          orElse: () => '',
        );
    return _parseMainData(
      mainData,
      imageBase64List: imageBase64List,
      imageVersion: imageVersion,
      imageBaseUrl: imageBaseUrl,
    );
  }

  SepcDailyReport _parseMainData(
    String data, {
    required List<String> imageBase64List,
    required String imageVersion,
    required String imageBaseUrl,
  }) {
    final segments = data.split('@');
    final reportSegment = segments.firstWhere(
      (segment) => segment.contains('过去24小时'),
      orElse: () => '',
    );
    if (reportSegment.isEmpty) {
      throw const FormatException('SEPC XML-RPC 主数据缺少日报文本');
    }
    final fields = reportSegment.split('#');
    if (fields.length < 4) {
      throw const FormatException('SEPC XML-RPC 日报字段不完整');
    }

    return SepcDailyReport(
      sourceName: sourceName,
      sourceUrl: rpcUrl,
      title: '过去24小时空间环境综述',
      summary: fields.length > 2 ? fields[2].trim() : '',
      forecast: fields.length > 3 ? fields[3].trim() : '',
      kp: _extractKp(segments),
      f107: _extractF107(segments),
      sunspots: _extractSunspots(segments),
      solarWindSpeed: _extractSolarWindSpeed(segments),
      forecaster: fields.length > 1 ? fields[1].trim() : '',
      issuedAt: _formatRpcTime(fields.first),
      imageBase64List: imageBase64List,
      imageVersion: imageVersion,
      imageBaseUrl: imageBaseUrl,
    );
  }

  SepcDailyReport _parseReport(String html) {
    final document = html_parser.parse(html);
    final titleElement = document
        .querySelectorAll('#second-ttl-bg')
        .where((element) => element.text.contains('过去24小时空间环境综述'))
        .firstOrNull;
    if (titleElement == null) {
      throw const FormatException('SEPC 页面缺少过去24小时空间环境综述');
    }

    final box = _closestById(titleElement, 'spac-weather-alerts-overview-box3');
    final rows = box
            ?.querySelector('#daily-reports-textbox table')
            ?.querySelectorAll('tr') ??
        const <dom.Element>[];
    if (rows.isEmpty) {
      throw const FormatException('SEPC 页面缺少日报正文');
    }

    final summary = _normalizeText(rows.first.text);
    var issuedAt = '';
    var forecaster = '';
    for (final row in rows.skip(1)) {
      final cells = row.querySelectorAll('td');
      final texts = cells.map((cell) => _normalizeText(cell.text)).toList();
      for (var index = 0; index < texts.length; index++) {
        final text = texts[index];
        if (text.contains('时间')) {
          issuedAt = _valueAfterColon(text);
          if (issuedAt.isEmpty && index + 1 < texts.length) {
            issuedAt = texts[index + 1];
          }
        }
        if (text.contains('预报员')) {
          forecaster = _valueAfterColon(text);
          if (forecaster.isEmpty && index + 1 < texts.length) {
            forecaster = texts[index + 1];
          }
        }
      }
    }

    return SepcDailyReport(
      sourceName: sourceName,
      sourceUrl: sourceUrl,
      title: _normalizeText(titleElement.text),
      summary: summary,
      forecast: '',
      kp: _extractKpFromText(summary),
      f107: '',
      sunspots: '',
      solarWindSpeed: _extractSolarWindSpeedFromText(summary),
      forecaster: forecaster,
      issuedAt: issuedAt,
    );
  }

  dom.Element? _closestById(dom.Element element, String id) {
    dom.Element? current = element;
    while (current != null) {
      if (current.id == id) return current;
      current = current.parent;
    }
    return null;
  }

  String _normalizeText(String value) {
    return value
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _valueAfterColon(String value) {
    final index = value.indexOf(RegExp('[：:]'));
    if (index < 0) return '';
    return value.substring(index + 1).trim();
  }

  String _extractKp(List<String> segments) {
    final segment = segments.firstWhere(
      (item) => RegExp(r'^\d{10,14}#\d$').hasMatch(item),
      orElse: () => '',
    );
    if (segment.isEmpty) return '';
    return segment.split('#').last;
  }

  String _extractF107(List<String> segments) {
    final segment = segments.firstWhere(
      (item) => RegExp(r'^\d{8}#\d+(\.\d+)?sfu$').hasMatch(item),
      orElse: () => '',
    );
    if (segment.isEmpty) return '';
    return segment.split('#').last;
  }

  String _extractSunspots(List<String> segments) {
    final f107Index = segments.indexWhere(
      (item) => RegExp(r'^\d{8}#\d+(\.\d+)?sfu$').hasMatch(item),
    );
    if (f107Index < 0 || f107Index + 1 >= segments.length) return '';
    final next = segments[f107Index + 1].split('#');
    if (next.length < 2 || !RegExp(r'^\d+$').hasMatch(next.last)) return '';
    return next.last;
  }

  String _extractSolarWindSpeed(List<String> segments) {
    final segment = segments.firstWhere(
      (item) => RegExp(r'^\d{10,14}#[-\d.]+#[-\d.]+#[-\d.]+$').hasMatch(item),
      orElse: () => '',
    );
    if (segment.isEmpty) return '';
    final parts = segment.split('#');
    return parts.length > 1 ? parts[1] : '';
  }

  String _extractKpFromText(String text) {
    final match = RegExp(r'Kp\s*=?\s*(\d+)').firstMatch(text);
    return match?.group(1) ?? '';
  }

  String _extractSolarWindSpeedFromText(String text) {
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*km/s').firstMatch(text);
    return match?.group(1) ?? '';
  }

  bool _looksLikeImageVersion(String value) {
    if (!value.contains('#')) return false;
    return value
        .split('#')
        .every((part) => RegExp(r'^\d{12,14}$').hasMatch(part));
  }

  String _formatRpcTime(String value) {
    final text = value.trim();
    if (text.length < 12 || !RegExp(r'^\d+$').hasMatch(text)) return text;
    final year = text.substring(0, 4);
    final month = text.substring(4, 6);
    final day = text.substring(6, 8);
    final hour = text.substring(8, 10);
    final minute = text.substring(10, 12);
    final second = text.length >= 14 ? ':${text.substring(12, 14)}' : '';
    return '$year-$month-$day $hour:$minute$second UTC';
  }

  String _friendlyDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return '连接 SEPC 超时';
    }
    if (e.type == DioExceptionType.connectionError) {
      return '无法连接 SEPC，请检查网络';
    }
    final status = e.response?.statusCode;
    if (status != null) return 'SEPC 返回 HTTP $status';
    return e.message ?? 'SEPC 请求失败';
  }
}

class _RpcValue {
  final String text;
  final bool isBase64;

  const _RpcValue({
    required this.text,
    required this.isBase64,
  });

  factory _RpcValue.fromXml(XmlElement element) {
    final base64 = element.findElements('base64').firstOrNull;
    if (base64 != null) {
      return _RpcValue(
        text: base64.innerText.replaceAll(RegExp(r'\s+'), ''),
        isBase64: true,
      );
    }
    final string = element.findElements('string').firstOrNull;
    return _RpcValue(
      text: (string?.innerText ?? element.innerText).trim(),
      isBase64: false,
    );
  }
}
