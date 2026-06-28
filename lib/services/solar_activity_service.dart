import 'package:dio/dio.dart';

import '../core/configure_dio.dart';
import '../models/solar_activity.dart';

class SolarActivityService {
  static const String sourceUrl = 'https://www.hamqsl.com/solarxml.php';

  final Dio _dio;

  SolarActivityService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 20),
                responseType: ResponseType.plain,
                headers: const {
                  'Accept': 'application/xml,text/xml,*/*',
                },
              ),
            ) {
    configureDio(_dio);
  }

  Future<SolarActivity> fetchSolarActivity() async {
    try {
      final response = await _dio.get<String>(sourceUrl);
      final body = response.data;
      if (body == null || body.trim().isEmpty) {
        throw const FormatException('HamQSL 返回空数据');
      }
      return SolarActivity.fromXml(body);
    } on DioException catch (e) {
      throw FormatException(_friendlyDioError(e));
    }
  }

  String _friendlyDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return '连接 HamQSL 超时';
    }
    if (e.type == DioExceptionType.connectionError) {
      return '无法连接 HamQSL，请检查网络';
    }
    final status = e.response?.statusCode;
    if (status != null) return 'HamQSL 返回 HTTP $status';
    return e.message ?? 'HamQSL 请求失败';
  }
}
