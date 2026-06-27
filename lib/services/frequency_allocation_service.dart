import '../models/frequency_allocation.dart';
import 'frequency_api_service.dart';
import 'local_database_service.dart';

class FrequencyAllocationService {
  final FrequencyApiService _apiService;
  final LocalDatabaseService _databaseService;

  FrequencyAllocationService({
    FrequencyApiService? apiService,
    LocalDatabaseService? databaseService,
  })  : _apiService = apiService ?? FrequencyApiService(),
        _databaseService = databaseService ?? LocalDatabaseService();

  Future<List<FrequencyAllocation>> getAllocations({
    String region = 'CN',
    String? service,
    String? query,
    bool forceRefresh = false,
  }) async {
    Object? syncError;
    if (forceRefresh || await _needsInitialSync(region: region)) {
      try {
        await syncAllocations(region: region);
      } catch (e) {
        syncError = e;
      }
    }
    final local = await _databaseService.getFrequencyAllocations(
      region: region,
      service: service,
      query: query,
    );
    if (local.isNotEmpty) return local;
    final fallback = _fallbackAllocations.where((item) {
      final serviceMatch = service == null ||
          item.services.any((value) => value.contains(service));
      final queryMatch = query == null ||
          query.trim().isEmpty ||
          item.services.any((value) => value.contains(query.trim())) ||
          item.rangeLabel.contains(query.trim());
      return serviceMatch && queryMatch;
    }).toList();
    if (fallback.isNotEmpty || syncError != null) return fallback;
    return local;
  }

  Future<void> syncAllocations({String region = 'CN'}) async {
    final all = <FrequencyAllocation>[];
    var page = 1;
    const pageSize = 300;
    while (true) {
      final items = await _apiService.listAllocations(
        region: region,
        page: page,
        pageSize: pageSize,
      );
      all.addAll(items);
      if (items.length < pageSize) break;
      page += 1;
    }
    if (all.isNotEmpty) {
      await _databaseService.replaceFrequencyAllocations(all);
    }
  }

  Future<bool> _needsInitialSync({String region = 'CN'}) async {
    final syncedAt = await _databaseService
        .getSetting('frequency_allocations_synced_at_$region');
    if (syncedAt == null || syncedAt.isEmpty) return true;
    final existing =
        await _databaseService.getFrequencyAllocations(region: region);
    return existing.isEmpty;
  }
}

const _fallbackAllocations = [
  FrequencyAllocation(
    region: 'CN',
    lowerMhz: 1.8,
    upperMhz: 2.0,
    unit: 'MHz',
    services: ['业余'],
    footnotes: [],
    source: '内置基础频段',
    sortOrder: 10,
  ),
  FrequencyAllocation(
    region: 'CN',
    lowerMhz: 3.5,
    upperMhz: 3.9,
    unit: 'MHz',
    services: ['业余'],
    footnotes: [],
    source: '内置基础频段',
    sortOrder: 20,
  ),
  FrequencyAllocation(
    region: 'CN',
    lowerMhz: 7.0,
    upperMhz: 7.2,
    unit: 'MHz',
    services: ['业余', '卫星业余'],
    footnotes: [],
    source: '内置基础频段',
    sortOrder: 30,
  ),
  FrequencyAllocation(
    region: 'CN',
    lowerMhz: 14.0,
    upperMhz: 14.35,
    unit: 'MHz',
    services: ['业余', '卫星业余'],
    footnotes: [],
    source: '内置基础频段',
    sortOrder: 40,
  ),
  FrequencyAllocation(
    region: 'CN',
    lowerMhz: 21.0,
    upperMhz: 21.45,
    unit: 'MHz',
    services: ['业余', '卫星业余'],
    footnotes: [],
    source: '内置基础频段',
    sortOrder: 50,
  ),
  FrequencyAllocation(
    region: 'CN',
    lowerMhz: 28.0,
    upperMhz: 29.7,
    unit: 'MHz',
    services: ['业余', '卫星业余'],
    footnotes: [],
    source: '内置基础频段',
    sortOrder: 60,
  ),
  FrequencyAllocation(
    region: 'CN',
    lowerMhz: 144.0,
    upperMhz: 148.0,
    unit: 'MHz',
    services: ['业余', '卫星业余'],
    footnotes: [],
    source: '内置基础频段',
    sortOrder: 70,
  ),
  FrequencyAllocation(
    region: 'CN',
    lowerMhz: 430.0,
    upperMhz: 440.0,
    unit: 'MHz',
    services: ['业余', '卫星业余'],
    footnotes: [],
    source: '内置基础频段',
    sortOrder: 80,
  ),
];
