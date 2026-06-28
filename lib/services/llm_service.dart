import 'package:dio/dio.dart';

import '../core/configure_dio.dart';
import 'app_endpoint_settings_service.dart';

class LlmService {
  final AppEndpointSettingsService _settingsService;
  final Dio _dio;

  LlmService({
    AppEndpointSettingsService settingsService =
        const AppEndpointSettingsService(),
    Dio? dio,
  })  : _settingsService = settingsService,
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 90),
                responseType: ResponseType.json,
                headers: const {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            ) {
    configureDio(_dio);
  }

  Future<String> complete({
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.2,
  }) async {
    final settings = await _settingsService.getLlmSettings();
    if (!settings.enabled) {
      throw const FormatException('LLM 未启用，请先在开发者设置中开启');
    }
    if (settings.apiKey.isEmpty) {
      throw const FormatException('LLM API Key 未配置');
    }
    if (settings.model.isEmpty) {
      throw const FormatException('LLM 模型未配置');
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        settings.baseUrl,
        options: Options(
          headers: {'Authorization': 'Bearer ${settings.apiKey}'},
        ),
        data: {
          'model': settings.model,
          'temperature': temperature,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
        },
      );
      final data = response.data;
      final choices = data?['choices'];
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map) {
          final message = first['message'];
          if (message is Map) {
            final content = message['content']?.toString().trim();
            if (content != null && content.isNotEmpty) return content;
          }
          final text = first['text']?.toString().trim();
          if (text != null && text.isNotEmpty) return text;
        }
      }
      throw const FormatException('LLM 返回内容为空');
    } on DioException catch (e) {
      throw FormatException(_friendlyDioError(e));
    }
  }

  String _friendlyDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return '连接 LLM 接口超时';
    }
    if (e.type == DioExceptionType.connectionError) {
      return '无法连接 LLM 接口，请检查地址和网络';
    }
    final status = e.response?.statusCode;
    if (status == 401 || status == 403) return 'LLM 鉴权失败，请检查 API Key';
    if (status != null) return 'LLM 接口返回 HTTP $status';
    return e.message ?? 'LLM 请求失败';
  }
}
