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
