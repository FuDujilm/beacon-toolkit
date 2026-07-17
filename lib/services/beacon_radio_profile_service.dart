import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/radio_profile.dart';
import 'app_endpoint_settings_service.dart';

class BeaconRadioProfileService {
  final ApiClient _apiClient;
  final AppEndpointSettingsService _endpointSettingsService;

  BeaconRadioProfileService({
    ApiClient? apiClient,
    AppEndpointSettingsService? endpointSettingsService,
  })  : _apiClient = apiClient ?? ApiClient(),
        _endpointSettingsService =
            endpointSettingsService ?? const AppEndpointSettingsService();

  Future<void> saveRadioProfile(RadioProfile profile) async {
    final baseUrl = await _endpointSettingsService.getBeaconApiBaseUrl();
    await _apiClient.client.put<Map<String, dynamic>>(
      _joinUrl(baseUrl, 'users/me/radio-profile'),
      data: {
        'callsign': _nullable(profile.callsign, RadioProfile.defaults.callsign),
        'qth': _nullable(profile.qth, RadioProfile.defaults.qth),
        'grid': _nullable(profile.grid, RadioProfile.defaults.grid),
        'latitude': profile.latitude,
        'longitude': profile.longitude,
        'altitude_meters': profile.altitudeMeters,
        'license_class': _nullable(
          profile.licenseClass,
          RadioProfile.defaults.licenseClass,
        ),
        'license_expiry': _nullable(
          profile.licenseExpiry,
          RadioProfile.defaults.licenseExpiry,
        ),
      },
      options: Options(headers: const {'Accept': 'application/json'}),
    );
  }

  Future<RadioProfile?> getRadioProfile() async {
    final baseUrl = await _endpointSettingsService.getBeaconApiBaseUrl();
    final response = await _apiClient.client.get<Map<String, dynamic>>(
      _joinUrl(baseUrl, 'users/me/radio-profile'),
      options: Options(headers: const {'Accept': 'application/json'}),
    );
    final data = response.data;
    final payload = data?['data'];
    final profile = payload is Map
        ? payload['radio_profile'] ?? payload['radioProfile'] ?? payload
        : data?['radio_profile'] ?? data?['radioProfile'];
    if (profile is! Map) return null;
    return RadioProfile(
      callsign: _stringField(
        profile,
        const ['callsign'],
        RadioProfile.defaults.callsign,
      ),
      qth: _stringField(profile, const ['qth'], RadioProfile.defaults.qth),
      grid: _stringField(profile, const ['grid'], RadioProfile.defaults.grid),
      latitude: _doubleField(profile, const ['latitude']),
      longitude: _doubleField(profile, const ['longitude']),
      altitudeMeters:
          _doubleField(profile, const ['altitude_meters', 'altitudeMeters']) ??
              0,
      licenseClass: _stringField(
        profile,
        const ['license_class', 'licenseClass'],
        RadioProfile.defaults.licenseClass,
      ),
      licenseExpiry: _stringField(
        profile,
        const ['license_expiry', 'licenseExpiry'],
        RadioProfile.defaults.licenseExpiry,
      ),
    );
  }

  String _joinUrl(String baseUrl, String path) {
    final cleanBase = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final cleanPath = path.replaceFirst(RegExp(r'^/+'), '');
    return '$cleanBase/$cleanPath';
  }

  String? _nullable(String value, String defaultValue) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == defaultValue) return null;
    return trimmed;
  }

  String _stringField(
      Map<dynamic, dynamic> json, List<String> keys, String fallback) {
    for (final key in keys) {
      final value = json[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return fallback;
  }

  double? _doubleField(Map<dynamic, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }
}
