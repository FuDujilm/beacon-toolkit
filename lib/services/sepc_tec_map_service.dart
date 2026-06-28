import 'package:charset/charset.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../core/configure_dio.dart';
import '../models/sepc_tec_map.dart';

class SepcTecMapService {
  static const String sourceName = 'SEPC 电离层TEC同化模型';
  static const String sourceUrl = 'http://www.sepc.ac.cn/TEC_chn.php';
  static const String animationUrl = 'http://www.sepc.ac.cn/getTECPath.php';
  static const String _baseUrl = 'http://www.sepc.ac.cn/';

  final Dio _dio;

  SepcTecMapService({Dio? dio})
      : _dio = dio ??
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
            ) {
    configureDio(_dio);
  }

  Future<SepcTecMapReport> fetchLatest() async {
    try {
      final response = await _dio.get<List<int>>(sourceUrl);
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException('SEPC TEC 同化模型返回空数据');
      }
      return _parse(gbk.decode(bytes));
    } on DioException catch (e) {
      throw FormatException(_friendlyDioError(e));
    } on FormatException {
      rethrow;
    }
  }

  SepcTecMapReport _parse(String html) {
    final document = html_parser.parse(html);
    final rawImages = <String>{
      ...document
          .querySelectorAll('img')
          .map((element) => element.attributes['src']?.trim() ?? '')
          .where(_isTecMapImage),
      ...RegExp(r'''(?:src\s*=\s*["'])?([^"'\s<>]+TECMap/[^"'\s<>]+\.png)''')
          .allMatches(html)
          .map((match) => match.group(1)?.trim() ?? '')
          .where(_isTecMapImage),
    }.toList();
    if (rawImages.isEmpty) {
      throw const FormatException('SEPC TEC 同化模型页面缺少产品图');
    }

    final images = <SepcTecMapImage>[];
    for (final src in rawImages) {
      final product = _productFromPath(src);
      images.add(
        SepcTecMapImage(
          product: product,
          title: _titleForProduct(product),
          imageUrl: _normalizeUrl(src),
        ),
      );
    }

    return SepcTecMapReport(
      sourceName: sourceName,
      sourceUrl: sourceUrl,
      images: images,
    );
  }

  bool _isTecMapImage(String src) {
    return src.contains('TECMap/') && src.toLowerCase().endsWith('.png');
  }

  SepcTecMapProduct _productFromPath(String path) {
    if (path.contains('/ROTI/')) return SepcTecMapProduct.roti;
    if (path.contains('/extra/')) return SepcTecMapProduct.deltaTec;
    return SepcTecMapProduct.tec;
  }

  String _titleForProduct(SepcTecMapProduct product) {
    switch (product) {
      case SepcTecMapProduct.tec:
        return 'TEC 总电子含量';
      case SepcTecMapProduct.roti:
        return 'ROTI 变化率指数';
      case SepcTecMapProduct.deltaTec:
        return '相对过去一周 TEC 变化';
    }
  }

  String _normalizeUrl(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    final normalized = value.startsWith('./') ? value.substring(2) : value;
    return Uri.parse(_baseUrl).resolve(normalized).toString();
  }

  String _friendlyDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return '连接 SEPC TEC 同化模型超时';
    }
    if (e.type == DioExceptionType.connectionError) {
      return '无法连接 SEPC TEC 同化模型，请检查网络';
    }
    final status = e.response?.statusCode;
    if (status != null) return 'SEPC TEC 同化模型返回 HTTP $status';
    return e.message ?? 'SEPC TEC 同化模型请求失败';
  }
}
