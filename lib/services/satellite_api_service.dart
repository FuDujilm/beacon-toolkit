import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/discovery.dart';
import 'app_endpoint_settings_service.dart';

class SatelliteApiService {
  final ApiClient _apiClient;
  final AppEndpointSettingsService _endpointSettingsService;

  SatelliteApiService({
    ApiClient? apiClient,
    AppEndpointSettingsService? endpointSettingsService,
  })  : _apiClient = apiClient ?? ApiClient(),
        _endpointSettingsService =
            endpointSettingsService ?? const AppEndpointSettingsService();

  Future<List<SatelliteCatalogItem>> listSatellites({
    String? query,
    DateTime? updatedSince,
    int page = 1,
    int pageSize = 200,
  }) async {
    final response = await _get<Map<String, dynamic>>(
      'satellites',
      queryParameters: {
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (updatedSince != null)
          'updated_since': updatedSince.toUtc().toIso8601String(),
        'page': page,
        'page_size': pageSize,
      },
    );
    final data = response.data?['data'] as Map<String, dynamic>?;
    final items = data?['items'] as List<dynamic>? ?? const [];
    return items
        .map((item) =>
            SatelliteCatalogItem.fromJson(item as Map<String, dynamic>))
        .where((item) => item.name.isNotEmpty)
        .toList();
  }

  Future<SatelliteApiDetail> getSatelliteDetail(String id) async {
    final response = await _get<Map<String, dynamic>>(
      'satellites/$id',
    );
    final data = response.data?['data'] as Map<String, dynamic>? ?? const {};
    final satellite = SatelliteCatalogItem.fromJson(
      data['satellite'] as Map<String, dynamic>? ?? const {},
    );
    final transponders = (data['transponders'] as List<dynamic>? ?? const [])
        .map((item) => SatelliteTransponder.fromBeaconApiJson(
            item as Map<String, dynamic>))
        .toList();
    final statusSummaries =
        (data['status_summaries'] as List<dynamic>? ?? const [])
            .map((item) =>
                SatelliteStatusSummary.fromJson(item as Map<String, dynamic>))
            .toList();
    return SatelliteApiDetail(
      satellite: satellite,
      transponders: transponders,
      statusSummaries: statusSummaries,
    );
  }

  Future<Response<T>> _get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final url = await _buildDiscoveryApiUrl(path);
    return _apiClient.client.get<T>(
      url,
      queryParameters: queryParameters,
    );
  }

  Future<String> _buildDiscoveryApiUrl(String path) async {
    final baseUrl = await _endpointSettingsService.getBeaconApiBaseUrl();
    final cleanPath = path.replaceFirst(RegExp(r'^/+'), '');
    return '$baseUrl/$cleanPath';
  }
}

class SatelliteApiDetail {
  final SatelliteCatalogItem satellite;
  final List<SatelliteTransponder> transponders;
  final List<SatelliteStatusSummary> statusSummaries;

  const SatelliteApiDetail({
    required this.satellite,
    required this.transponders,
    required this.statusSummaries,
  });
}
