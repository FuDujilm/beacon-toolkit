import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../core/configure_dio.dart';
import '../models/sepc_ionosphere.dart';

class SepcIonosphereService {
  static const String sourceName = 'SEPC 电离层闪烁';
  static const String pageUrl = 'http://www.sepc.ac.cn/ionosphere_chn.php';
  static const String apiUrl = 'http://www.sepc.ac.cn/getHeavisideLayer.php';
  static const String _baseUrl = 'http://www.sepc.ac.cn/';

  static const List<SepcIonosphereStation> stations = [
    SepcIonosphereStation(
      code: 'fz',
      name: '福州',
      longitude: 119.330221,
      latitude: 26.047125,
    ),
    SepcIonosphereStation(
      code: 'gz',
      name: '广州',
      longitude: 113.275995,
      latitude: 23.117055,
    ),
    SepcIonosphereStation(
      code: 'nn',
      name: '南宁',
      longitude: 108.297234,
      latitude: 22.806493,
    ),
    SepcIonosphereStation(
      code: 'xm',
      name: '厦门',
      longitude: 118.11022,
      latitude: 24.490474,
    ),
    SepcIonosphereStation(
      code: 'hn',
      name: '海南',
      longitude: 110.10,
      latitude: 19.03,
    ),
    SepcIonosphereStation(
      code: 'km',
      name: '昆明',
      longitude: 102.852451,
      latitude: 24.873998,
    ),
    SepcIonosphereStation(
      code: 'zy',
      name: '张掖',
      longitude: 100.45,
      latitude: 38.93,
    ),
  ];

  final Dio _dio;

  SepcIonosphereService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 20),
                responseType: ResponseType.plain,
                headers: const {
                  'Accept': 'text/plain,*/*',
                  'User-Agent': 'Mozilla/5.0',
                  'Referer': pageUrl,
                },
              ),
            ) {
    configureDio(_dio);
  }

  Future<SepcIonosphereImage> fetchImage({
    required SepcIonosphereStation station,
    required SepcIonosphereProduct product,
    required DateTime date,
  }) async {
    try {
      final response = await _dio.get<String>(
        apiUrl,
        queryParameters: {
          'flag': station.code,
          'tec': product == SepcIonosphereProduct.scintillation ? '0' : '1',
          'time': DateFormat('yyyyMMdd').format(date),
          'sid': DateTime.now().microsecondsSinceEpoch / 1000000,
        },
      );
      final path = response.data?.trim() ?? '';
      if (path.isEmpty) {
        throw const FormatException('SEPC 电离层接口返回空数据');
      }
      return SepcIonosphereImage(
        sourceName: sourceName,
        sourceUrl: pageUrl,
        station: station,
        product: product,
        date: date,
        imageUrl: _normalizeImageUrl(path),
      );
    } on DioException catch (e) {
      throw FormatException(_friendlyDioError(e));
    } on FormatException {
      rethrow;
    }
  }

  String _normalizeImageUrl(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    final normalized = value.startsWith('./') ? value.substring(2) : value;
    return Uri.parse(_baseUrl).resolve(normalized).toString();
  }

  String _friendlyDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return '连接 SEPC 电离层接口超时';
    }
    if (e.type == DioExceptionType.connectionError) {
      return '无法连接 SEPC 电离层接口，请检查网络';
    }
    final status = e.response?.statusCode;
    if (status != null) return 'SEPC 电离层接口返回 HTTP $status';
    return e.message ?? 'SEPC 电离层请求失败';
  }
}
