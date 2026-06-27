import '../core/api_client.dart';
import '../models/frequency_allocation.dart';
import 'app_endpoint_settings_service.dart';

class FrequencyApiService {
  final ApiClient _apiClient;
  final AppEndpointSettingsService _endpointSettingsService;

  FrequencyApiService({
    ApiClient? apiClient,
    AppEndpointSettingsService? endpointSettingsService,
  })  : _apiClient = apiClient ?? ApiClient(),
        _endpointSettingsService =
            endpointSettingsService ?? const AppEndpointSettingsService();

  Future<List<FrequencyAllocation>> listAllocations({
    String region = 'CN',
    String? service,
    String? query,
    int page = 1,
    int pageSize = 300,
  }) async {
    final url = await _buildDiscoveryApiUrl('frequency/allocations');
    final response = await _apiClient.client.get<Map<String, dynamic>>(
      url,
      queryParameters: {
        'region': region,
        if (service != null && service.trim().isNotEmpty)
          'service': service.trim(),
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        'page': page,
        'page_size': pageSize,
      },
    );
    final data = response.data?['data'] as Map<String, dynamic>? ?? const {};
    final items = data['items'] as List<dynamic>? ?? const [];
    return items
        .map((item) => FrequencyAllocation.fromJson(
              item as Map<String, dynamic>,
            ))
        .toList();
  }

  Future<String> _buildDiscoveryApiUrl(String path) async {
    final baseUrl = await _endpointSettingsService.getBeaconApiBaseUrl();
    final cleanPath = path.replaceFirst(RegExp(r'^/+'), '');
    return '$baseUrl/$cleanPath';
  }
}
