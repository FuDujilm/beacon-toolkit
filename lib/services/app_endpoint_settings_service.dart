import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/configure_dio.dart';
import '../core/constants.dart';

class AppEndpointSettingsService {
  final FlutterSecureStorage _storage;

  const AppEndpointSettingsService({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  Future<String> getBeaconApiBaseUrl() async {
    final stored = await _readStorageValue(AppConstants.beaconApiBaseUrlKey);
    final normalized = normalizeBeaconApiBaseUrl(
      stored == null || stored.trim().isEmpty
          ? AppConstants.beaconApiBaseUrl
          : stored,
    );
    if (stored != null && stored != normalized) {
      await _storage.write(
        key: AppConstants.beaconApiBaseUrlKey,
        value: normalized,
      );
    }
    return normalized;
  }

  Future<void> updateBeaconApiBaseUrl(String url) async {
    final normalized = normalizeBeaconApiBaseUrl(url);
    await _storage.write(
      key: AppConstants.beaconApiBaseUrlKey,
      value: normalized,
    );
  }

  Future<String> getBeaconFrontendBaseUrl() async {
    final stored =
        await _readStorageValue(AppConstants.beaconFrontendBaseUrlKey);
    final normalized = normalizeBeaconFrontendBaseUrl(
      stored == null || stored.trim().isEmpty
          ? _defaultBeaconFrontendBaseUrl()
          : stored,
    );
    if (stored != null && stored != normalized) {
      await _storage.write(
        key: AppConstants.beaconFrontendBaseUrlKey,
        value: normalized,
      );
    }
    return normalized;
  }

  Future<void> updateBeaconFrontendBaseUrl(String url) async {
    final normalized = normalizeBeaconFrontendBaseUrl(url);
    await _storage.write(
      key: AppConstants.beaconFrontendBaseUrlKey,
      value: normalized,
    );
  }

  Future<String> getTiandituToken() async {
    final token = await _readStorageValue(AppConstants.tiandituTokenKey);
    return token?.trim() ?? '';
  }

  Future<void> updateTiandituToken(String token) async {
    final normalized = token.trim();
    if (normalized.isEmpty) {
      await _storage.delete(key: AppConstants.tiandituTokenKey);
      return;
    }
    await _storage.write(
      key: AppConstants.tiandituTokenKey,
      value: normalized,
    );
  }

  Future<OpenOidcSettings> getOpenOidcSettings() async {
    final baseUrl = await _readStorageValue(AppConstants.oauthBaseUrlKey);
    final clientId = await _readStorageValue(AppConstants.oauthClientIdKey);
    return OpenOidcSettings(
      baseUrl: normalizeOpenOidcBaseUrl(
        baseUrl == null || baseUrl.trim().isEmpty
            ? AppConstants.oauthBaseUrl
            : baseUrl,
      ),
      clientId: clientId?.trim().isNotEmpty == true
          ? clientId!.trim()
          : AppConstants.oauthClientId,
    );
  }

  Future<void> updateOpenOidcSettings(OpenOidcSettings settings) async {
    await _writeOrDelete(
      AppConstants.oauthBaseUrlKey,
      normalizeOpenOidcBaseUrl(settings.baseUrl),
    );
    await _writeOrDelete(AppConstants.oauthClientIdKey, settings.clientId);
  }

  Future<void> resetOpenOidcSettings() async {
    await _storage.delete(key: AppConstants.oauthBaseUrlKey);
    await _storage.delete(key: AppConstants.oauthClientIdKey);
  }

  Future<Map<String, dynamic>> testOpenOidcConnection(String url) async {
    final normalized = normalizeOpenOidcBaseUrl(url);
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: const {
          'Accept': 'application/json',
        },
      ),
    );
    configureDio(dio);

    final stopwatch = Stopwatch()..start();
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '$normalized/.well-known/openid-configuration',
      );
      stopwatch.stop();
      final data = response.data ?? {};
      final hasEndpoints = data['authorization_endpoint'] != null &&
          data['token_endpoint'] != null &&
          data['userinfo_endpoint'] != null;
      return {
        'success': hasEndpoints,
        'latency': stopwatch.elapsedMilliseconds,
        'message': hasEndpoints
            ? 'OIDC Discovery OK (${data['issuer'] ?? normalized})'
            : 'OIDC Discovery 返回缺少必要端点',
      };
    } catch (e) {
      stopwatch.stop();
      return {
        'success': false,
        'latency': stopwatch.elapsedMilliseconds,
        'message': _connectionErrorMessage(e),
      };
    }
  }

  Future<QrzSettings> getQrzSettings() async {
    final username = await _readStorageValue(AppConstants.qrzUsernameKey);
    final password = await _readStorageValue(AppConstants.qrzPasswordKey);
    final mode = await _readStorageValue(AppConstants.qrzLookupModeKey);
    final debugEnabled =
        await _readStorageValue(AppConstants.qrzDebugEnabledKey);
    return QrzSettings(
      username: username?.trim() ?? '',
      password: password?.trim() ?? '',
      mode: QrzLookupMode.fromKey(mode),
      debugEnabled: debugEnabled == 'true',
    );
  }

  Future<void> updateQrzSettings(QrzSettings settings) async {
    await _writeOrDelete(AppConstants.qrzUsernameKey, settings.username);
    await _writeOrDelete(AppConstants.qrzPasswordKey, settings.password);
    await _storage.write(
      key: AppConstants.qrzLookupModeKey,
      value: settings.mode.key,
    );
    await _storage.write(
      key: AppConstants.qrzDebugEnabledKey,
      value: settings.debugEnabled.toString(),
    );
  }

  Future<String> getQrzSessionKey() async {
    final key = await _readStorageValue(AppConstants.qrzSessionKey);
    return key?.trim() ?? '';
  }

  Future<void> updateQrzSessionKey(String sessionKey) async {
    await _writeOrDelete(AppConstants.qrzSessionKey, sessionKey);
  }

  Future<LlmSettings> getLlmSettings() async {
    final enabled = await _readStorageValue(AppConstants.llmEnabledKey);
    final baseUrl = await _readStorageValue(AppConstants.llmBaseUrlKey);
    final apiKey = await _readStorageValue(AppConstants.llmApiKeyKey);
    final model = await _readStorageValue(AppConstants.llmModelKey);
    return LlmSettings(
      enabled: enabled == 'true',
      baseUrl: normalizeOpenAiCompatibleBaseUrl(
        baseUrl == null || baseUrl.trim().isEmpty
            ? LlmSettings.defaultBaseUrl
            : baseUrl,
      ),
      apiKey: apiKey?.trim() ?? '',
      model: model?.trim().isNotEmpty == true
          ? model!.trim()
          : LlmSettings.defaultModel,
    );
  }

  Future<void> updateLlmSettings(LlmSettings settings) async {
    await _storage.write(
      key: AppConstants.llmEnabledKey,
      value: settings.enabled.toString(),
    );
    await _writeOrDelete(
      AppConstants.llmBaseUrlKey,
      normalizeOpenAiCompatibleBaseUrl(settings.baseUrl),
    );
    await _writeOrDelete(AppConstants.llmApiKeyKey, settings.apiKey);
    await _writeOrDelete(AppConstants.llmModelKey, settings.model);
  }

  Future<SmtpSettings> getSmtpSettings() async {
    final enabled = await _readStorageValue(AppConstants.smtpEnabledKey);
    final host = await _readStorageValue(AppConstants.smtpHostKey);
    final port = await _readStorageValue(AppConstants.smtpPortKey);
    final username = await _readStorageValue(AppConstants.smtpUsernameKey);
    final password = await _readStorageValue(AppConstants.smtpPasswordKey);
    final fromEmail = await _readStorageValue(AppConstants.smtpFromEmailKey);
    final fromName = await _readStorageValue(AppConstants.smtpFromNameKey);
    return SmtpSettings(
      enabled: enabled == 'true',
      host: host?.trim() ?? '',
      port: int.tryParse(port?.trim() ?? '') ?? 587,
      username: username?.trim() ?? '',
      password: password ?? '',
      fromEmail: fromEmail?.trim() ?? '',
      fromName: fromName?.trim() ?? 'Beacon',
    );
  }

  Future<void> updateSmtpSettings(SmtpSettings settings) async {
    await _storage.write(
      key: AppConstants.smtpEnabledKey,
      value: settings.enabled.toString(),
    );
    await _writeOrDelete(AppConstants.smtpHostKey, settings.host);
    await _writeOrDelete(AppConstants.smtpPortKey, settings.port.toString());
    await _writeOrDelete(AppConstants.smtpUsernameKey, settings.username);
    await _writeOrDelete(AppConstants.smtpPasswordKey, settings.password);
    await _writeOrDelete(AppConstants.smtpFromEmailKey, settings.fromEmail);
    await _writeOrDelete(AppConstants.smtpFromNameKey, settings.fromName);
  }

  Future<Map<String, dynamic>> testBeaconApiConnection(String url) async {
    final normalized = normalizeBeaconApiBaseUrl(url);
    final dio = Dio(
      BaseOptions(
        baseUrl: normalized,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    configureDio(dio);

    final stopwatch = Stopwatch()..start();
    try {
      final response = await dio
          .get<dynamic>('frequency/allocations', queryParameters: const {
        'region': 'CN',
        'page': 1,
        'page_size': 1,
      });
      stopwatch.stop();
      return {
        'success': true,
        'latency': stopwatch.elapsedMilliseconds,
        'message': 'Connected (Status: ${response.statusCode})',
      };
    } catch (e) {
      stopwatch.stop();
      return {
        'success': false,
        'latency': stopwatch.elapsedMilliseconds,
        'message': _connectionErrorMessage(e),
      };
    }
  }

  String normalizeBeaconApiBaseUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return AppConstants.beaconApiBaseUrl;
    }

    final withTrailingSlash = trimmed.endsWith('/') ? trimmed : '$trimmed/';
    final uri = Uri.tryParse(withTrailingSlash);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return withTrailingSlash;
    }

    final normalizedPath = uri.path.replaceFirst(RegExp(r'/+$'), '');
    if (normalizedPath.endsWith('/api/v1')) {
      return uri.replace(path: '$normalizedPath/').toString();
    }
    if (normalizedPath.endsWith('/api')) {
      return uri.replace(path: '$normalizedPath/v1/').toString();
    }
    if (normalizedPath.endsWith('/v1')) {
      return uri.replace(path: '$normalizedPath/').toString();
    }
    return uri.replace(path: '$normalizedPath/api/v1/').toString();
  }

  String normalizeBeaconFrontendBaseUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return _defaultBeaconFrontendBaseUrl();
    final withoutHash = trimmed.split('#').first;
    final withTrailingSlash =
        withoutHash.endsWith('/') ? withoutHash : '$withoutHash/';
    final uri = Uri.tryParse(withTrailingSlash);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return withTrailingSlash;
    }
    return uri.replace(query: '', fragment: '').toString();
  }

  String normalizeOpenOidcBaseUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return AppConstants.oauthBaseUrl;
    final withoutHash = trimmed.split('#').first;
    final withoutTrailingSlash = withoutHash.replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(withoutTrailingSlash);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return withoutTrailingSlash;
    }
    return uri.replace(query: '', fragment: '').toString();
  }

  String _defaultBeaconFrontendBaseUrl() {
    if (kIsWeb) {
      final uri = Uri.base;
      final path = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
      return uri.replace(path: path, query: '', fragment: '').toString();
    }
    return 'http://localhost:5273/';
  }

  String normalizeOpenAiCompatibleBaseUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return LlmSettings.defaultBaseUrl;
    final withTrailingSlash = trimmed.endsWith('/') ? trimmed : '$trimmed/';
    final uri = Uri.tryParse(withTrailingSlash);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return withTrailingSlash;
    }
    final normalizedPath = uri.path.replaceFirst(RegExp(r'/+$'), '');
    if (normalizedPath.endsWith('/chat/completions')) {
      return uri.replace(path: '$normalizedPath/').toString();
    }
    if (normalizedPath.endsWith('/v1')) {
      return uri.replace(path: '$normalizedPath/chat/completions/').toString();
    }
    return uri.replace(path: '$normalizedPath/v1/chat/completions/').toString();
  }

  Future<String?> _readStorageValue(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('Failed to read secure storage key "$key": $e');
      try {
        await _storage.delete(key: key);
      } catch (deleteError) {
        debugPrint('Failed to clear secure storage key "$key": $deleteError');
      }
      return null;
    }
  }

  Future<void> _writeOrDelete(String key, String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      await _storage.delete(key: key);
      return;
    }
    await _storage.write(key: key, value: normalized);
  }

  String _connectionErrorMessage(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return 'Connection Timeout';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Connection Refused (Check IP/Port)';
      }
      return e.message ?? e.toString();
    }
    return e.toString();
  }
}

enum QrzLookupMode {
  automatic('automatic'),
  beaconOnly('beacon_only'),
  qrzOnly('qrz_only');

  final String key;

  const QrzLookupMode(this.key);

  static QrzLookupMode fromKey(String? key) {
    return QrzLookupMode.values.firstWhere(
      (mode) => mode.key == key,
      orElse: () => QrzLookupMode.automatic,
    );
  }
}

class QrzSettings {
  final String username;
  final String password;
  final QrzLookupMode mode;
  final bool debugEnabled;

  const QrzSettings({
    required this.username,
    required this.password,
    required this.mode,
    this.debugEnabled = false,
  });

  bool get hasCredentials => username.isNotEmpty && password.isNotEmpty;
}

class OpenOidcSettings {
  final String baseUrl;
  final String clientId;

  const OpenOidcSettings({
    required this.baseUrl,
    required this.clientId,
  });
}

class LlmSettings {
  static const String defaultBaseUrl =
      'https://api.openai.com/v1/chat/completions/';
  static const String defaultModel = 'gpt-4o-mini';

  final bool enabled;
  final String baseUrl;
  final String apiKey;
  final String model;

  const LlmSettings({
    required this.enabled,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  bool get isUsable => enabled && baseUrl.isNotEmpty && apiKey.isNotEmpty;
}

class SmtpSettings {
  final bool enabled;
  final String host;
  final int port;
  final String username;
  final String password;
  final String fromEmail;
  final String fromName;

  const SmtpSettings({
    required this.enabled,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.fromEmail,
    required this.fromName,
  });

  bool get isUsable => enabled && host.isNotEmpty && fromEmail.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'host': host,
      'port': port,
      'username': username.isEmpty ? null : username,
      'password': password.isEmpty ? null : password,
      'from_email': fromEmail,
      'from_name': fromName.isEmpty ? null : fromName,
    };
  }
}
