import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../core/configure_dio.dart';
import '../models/sepc_long_term_forecast.dart';

class SepcLongTermForecastService {
  static const String sourceName = 'SEPC 未来27天预报';
  static const String f107PageUrl =
      'http://www.sepc.ac.cn/F107Forecast_chn.php';
  static const String apPageUrl = 'http://www.sepc.ac.cn/ApForecast_chn.php';
  static const String _f107ApiUrl =
      'http://www.sepc.ac.cn/getF107Forecast_js.php';
  static const String _apApiUrl = 'http://www.sepc.ac.cn/getApForecast_js.php';

  final Dio _dio;

  SepcLongTermForecastService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 20),
                responseType: ResponseType.plain,
                headers: const {
                  'Accept': 'application/json,text/plain,*/*',
                  'User-Agent': 'Mozilla/5.0',
                },
              ),
            ) {
    configureDio(_dio);
  }

  Future<List<SepcLongTermForecast>> fetchAll({DateTime? now}) async {
    final date = now ?? DateTime.now();
    final results = await Future.wait([
      fetchForecast(kind: SepcForecastKind.f107, date: date),
      fetchForecast(kind: SepcForecastKind.ap, date: date),
    ]);
    return results;
  }

  Future<SepcLongTermForecast> fetchForecast({
    required SepcForecastKind kind,
    DateTime? date,
  }) async {
    final startTime = DateFormat('yyyyMMdd').format(date ?? DateTime.now());
    try {
      final response = await _dio.get<String>(
        _apiUrl(kind),
        queryParameters: {
          'starttime': startTime,
          'endtime': '',
          'sid': DateTime.now().microsecondsSinceEpoch / 1000000,
        },
      );
      final body = response.data;
      if (body == null || body.trim().isEmpty) {
        throw FormatException('${_label(kind)}返回空数据');
      }
      return _parse(kind, body);
    } on DioException catch (e) {
      throw FormatException(_friendlyDioError(kind, e));
    } on FormatException {
      rethrow;
    }
  }

  SepcLongTermForecast _parse(SepcForecastKind kind, String body) {
    final jsonPart = body.split('###').first.trim();
    final data = jsonDecode(jsonPart);
    if (data is! Map<String, dynamic>) {
      throw FormatException('${_label(kind)}JSON 格式错误');
    }
    final xAxis = _decodeStringList(data['xaxis']);
    final observed = _decodeValues(data['realvalue']);
    final predicted = _decodeValues(data['futurevalue']);
    if (xAxis.isEmpty) throw FormatException('${_label(kind)}缺少日期轴');
    final length = [xAxis.length, observed.length, predicted.length]
        .reduce((a, b) => a < b ? a : b);
    final points = <SepcForecastPoint>[
      for (var index = 0; index < length; index++)
        SepcForecastPoint(
          dateLabel: xAxis[index],
          observed: observed[index],
          predicted: predicted[index],
        ),
    ];
    if (!points
        .any((point) => point.observed != null || point.predicted != null)) {
      throw FormatException('${_label(kind)}缺少有效数值');
    }
    return SepcLongTermForecast(
      kind: kind,
      sourceName: sourceName,
      sourceUrl: _pageUrl(kind),
      minY: _asDouble(data['min']),
      maxY: _asDouble(data['max']),
      points: points,
    );
  }

  List<String> _decodeStringList(Object? value) {
    if (value is String) {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded.map((item) => item.toString()).toList();
      }
    }
    return const [];
  }

  List<double?> _decodeValues(Object? value) {
    if (value is! String) return const [];
    final decoded = jsonDecode(value);
    if (decoded is! List) return const [];
    return decoded.map(_asDouble).toList();
  }

  double? _asDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final text = value.toString().trim().toLowerCase();
    if (text.isEmpty || text == 'null') return null;
    return double.tryParse(text);
  }

  String _apiUrl(SepcForecastKind kind) {
    return kind == SepcForecastKind.f107 ? _f107ApiUrl : _apApiUrl;
  }

  String _pageUrl(SepcForecastKind kind) {
    return kind == SepcForecastKind.f107 ? f107PageUrl : apPageUrl;
  }

  String _label(SepcForecastKind kind) {
    return kind == SepcForecastKind.f107 ? 'SEPC F10.7 预报' : 'SEPC Ap 预报';
  }

  String _friendlyDioError(SepcForecastKind kind, DioException e) {
    final label = _label(kind);
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
