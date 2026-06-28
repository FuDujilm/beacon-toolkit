import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../core/configure_dio.dart';
import '../models/sepc_k_index.dart';

class SepcKIndexService {
  static const String sourceName = 'SEPC K指数现报';
  static const String sourceUrl = 'http://www.sepc.ac.cn/getKIndex_js.php';

  final Dio _dio;

  SepcKIndexService({Dio? dio})
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

  Future<SepcKIndexReport> fetchRecent({
    int days = 3,
    DateTime? now,
  }) async {
    final end = now ?? DateTime.now();
    final start = end.subtract(Duration(days: days));
    final formatter = DateFormat('yyyyMMdd');
    try {
      final response = await _dio.get<String>(
        sourceUrl,
        queryParameters: {
          'starttime': formatter.format(start),
          'endtime': formatter.format(end),
          'sid': DateTime.now().microsecondsSinceEpoch / 1000000,
        },
      );
      final body = response.data;
      if (body == null || body.trim().isEmpty) {
        throw const FormatException('SEPC K 指数返回空数据');
      }
      final data = jsonDecode(body);
      if (data is! Map<String, dynamic>) {
        throw const FormatException('SEPC K 指数 JSON 格式错误');
      }
      return _parseReport(data);
    } on DioException catch (e) {
      throw FormatException(_friendlyDioError(e));
    } on FormatException {
      rethrow;
    }
  }

  SepcKIndexReport _parseReport(Map<String, dynamic> json) {
    final rawSeries = json['data'];
    if (rawSeries is! List) {
      throw const FormatException('SEPC K 指数缺少 data 字段');
    }
    final names = ['北京', '广州', '三亚', '满洲里', 'SEPC 模式'];
    final series = <SepcKIndexSeries>[];
    for (var index = 0; index < rawSeries.length; index++) {
      final rawPoints = rawSeries[index];
      if (rawPoints is! List) continue;
      final points = <SepcKIndexPoint>[];
      for (final rawPoint in rawPoints) {
        if (rawPoint is! List || rawPoint.length < 2) continue;
        final time = rawPoint[0]?.toString() ?? '';
        final value = rawPoint[1];
        points.add(
          SepcKIndexPoint(
            time: time,
            value: value is num ? value.toInt() : null,
          ),
        );
      }
      series.add(
        SepcKIndexSeries(
          name: index < names.length ? names[index] : '序列 ${index + 1}',
          points: points,
        ),
      );
    }
    return SepcKIndexReport(
      sourceName: sourceName,
      sourceUrl: sourceUrl,
      startTime: json['starttime']?.toString() ?? '',
      endTime: json['endtime']?.toString() ?? '',
      series: series,
    );
  }

  String _friendlyDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return '连接 SEPC K 指数接口超时';
    }
    if (e.type == DioExceptionType.connectionError) {
      return '无法连接 SEPC K 指数接口，请检查网络';
    }
    final status = e.response?.statusCode;
    if (status != null) return 'SEPC K 指数接口返回 HTTP $status';
    return e.message ?? 'SEPC K 指数请求失败';
  }
}
