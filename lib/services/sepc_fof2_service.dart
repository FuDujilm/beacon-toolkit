import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../core/configure_dio.dart';
import '../models/sepc_fof2.dart';

class SepcFof2Service {
  static const String sourceName = 'SEPC 电离层临界频率';
  static const String sourceUrl = 'http://www.sepc.ac.cn/cgyFof2.php';
  static const String apiUrl = 'http://www.sepc.ac.cn/getF0F2Data.php';

  static const List<SepcFof2Station> stations = [
    SepcFof2Station(
      code: 'zy',
      name: '张掖',
      longitude: 100.45,
      latitude: 38.93,
    ),
    SepcFof2Station(
      code: 'bj',
      name: '北京',
      longitude: 116.4,
      latitude: 39.90,
    ),
    SepcFof2Station(
      code: 'mh',
      name: '漠河',
      longitude: 122.53,
      latitude: 52.97,
    ),
    SepcFof2Station(
      code: 'wh',
      name: '武汉',
      longitude: 114.3,
      latitude: 30.6,
    ),
    SepcFof2Station(
      code: 'sy',
      name: '三亚',
      longitude: 109.50,
      latitude: 18.2,
    ),
  ];

  final Dio _dio;

  SepcFof2Service({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 20),
                responseType: ResponseType.json,
                headers: const {
                  'Accept': 'application/json,text/plain,*/*',
                  'User-Agent': 'Mozilla/5.0',
                  'Referer': sourceUrl,
                },
              ),
            ) {
    configureDio(_dio);
  }

  Future<SepcFof2Report> fetchRecent({
    required SepcFof2Station station,
    int days = 6,
    DateTime? now,
  }) async {
    final end = now ?? DateTime.now();
    final start = end.subtract(Duration(days: days));
    final formatter = DateFormat('yyyyMMdd');
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        apiUrl,
        queryParameters: {
          'starttime': formatter.format(start),
          'endtime': formatter.format(end),
          'station': station.code,
        },
      );
      final data = response.data;
      if (data == null) {
        throw const FormatException('SEPC foF2 返回空数据');
      }
      return _parseReport(data, station);
    } on DioException catch (e) {
      throw FormatException(_friendlyDioError(e));
    } on FormatException {
      rethrow;
    }
  }

  SepcFof2Report _parseReport(
    Map<String, dynamic> json,
    SepcFof2Station station,
  ) {
    final rawPoints = json['data'];
    if (rawPoints is! List) {
      throw const FormatException('SEPC foF2 缺少 data 字段');
    }
    final points = <SepcFof2Point>[];
    for (final raw in rawPoints) {
      if (raw is! Map) continue;
      final rawTime = raw['DAYSTR']?.toString() ?? '';
      final rawValue = raw['FOF2'];
      final time = _parseTime(rawTime);
      final value = _parseFof2Value(rawValue, station);
      if (time == null || value == null) continue;
      if (value <= 0 || value >= 30) continue;
      points.add(SepcFof2Point(time: time, value: value));
    }
    if (points.isEmpty) {
      throw const FormatException('SEPC foF2 没有有效观测点');
    }

    final rawKpPoints = json['dataKp'];
    final kpPoints = <SepcFof2KpPoint>[];
    if (rawKpPoints is List) {
      for (final raw in rawKpPoints) {
        if (raw is! Map) continue;
        final time = _parseKpTime(raw['DAY_HH']?.toString() ?? '');
        final value = int.tryParse(raw['KP']?.toString() ?? '');
        if (time == null || value == null) continue;
        kpPoints.add(SepcFof2KpPoint(time: time, value: value));
      }
    }

    return SepcFof2Report(
      sourceName: sourceName,
      sourceUrl: sourceUrl,
      station: stations.firstWhere(
        (item) => item.code == (json['staname']?.toString() ?? station.code),
        orElse: () => station,
      ),
      startTime: json['startTime']?.toString() ?? '',
      endTime: json['endTime']?.toString() ?? '',
      points: points,
      kpPoints: kpPoints,
    );
  }

  double? _parseFof2Value(Object? rawValue, SepcFof2Station station) {
    final value = double.tryParse(rawValue?.toString() ?? '');
    if (value == null) return null;
    if (station.code == 'zy') return value;
    return value * 0.1;
  }

  DateTime? _parseTime(String value) {
    if (value.length < 12) return null;
    final padded = value.padRight(14, '0');
    return DateTime.tryParse(
      '${padded.substring(0, 4)}-'
      '${padded.substring(4, 6)}-'
      '${padded.substring(6, 8)} '
      '${padded.substring(8, 10)}:'
      '${padded.substring(10, 12)}:'
      '${padded.substring(12, 14)}',
    );
  }

  DateTime? _parseKpTime(String value) {
    if (value.length < 10) return null;
    return DateTime.tryParse(
      '${value.substring(0, 4)}-'
      '${value.substring(4, 6)}-'
      '${value.substring(6, 8)} '
      '${value.substring(8, 10)}:00:00',
    );
  }

  String _friendlyDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return '连接 SEPC foF2 接口超时';
    }
    if (e.type == DioExceptionType.connectionError) {
      return '无法连接 SEPC foF2 接口，请检查网络';
    }
    final status = e.response?.statusCode;
    if (status != null) return 'SEPC foF2 接口返回 HTTP $status';
    return e.message ?? 'SEPC foF2 请求失败';
  }
}
