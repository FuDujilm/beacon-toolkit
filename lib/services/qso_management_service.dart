import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../core/api_client.dart';
import '../models/qso_log.dart';
import 'app_endpoint_settings_service.dart';

class QsoManagementService {
  final ApiClient _apiClient;
  final AppEndpointSettingsService _endpointSettingsService;

  QsoManagementService({
    ApiClient? apiClient,
    AppEndpointSettingsService? endpointSettingsService,
  })  : _apiClient = apiClient ?? ApiClient(),
        _endpointSettingsService =
            endpointSettingsService ?? const AppEndpointSettingsService();

  Future<List<QsoLog>> fetchCloudLogs(
      {int page = 1, int pageSize = 200}) async {
    final response = await _apiClient.client.get<Map<String, dynamic>>(
      await _url('qso-logs'),
      queryParameters: {'page': page, 'page_size': pageSize},
      options: Options(headers: const {'Accept': 'application/json'}),
    );
    final pageData = _data(response.data);
    final items = pageData is Map ? pageData['items'] : null;
    if (items is! List) return [];
    return items
        .whereType<Map>()
        .map((item) => QsoLog.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<QsoSyncSummary> syncLogs(List<QsoLog> logs) async {
    final response = await _apiClient.client.post<Map<String, dynamic>>(
      await _url('qso-logs/sync'),
      data: {'logs': logs.map((log) => log.toApiJson()).toList()},
      options: Options(headers: const {'Accept': 'application/json'}),
    );
    final payload = _data(response.data);
    if (payload is! Map) return const QsoSyncSummary();
    final items = payload['items'];
    return QsoSyncSummary(
      inserted: _intValue(payload['inserted']),
      updated: _intValue(payload['updated']),
      skipped: _intValue(payload['skipped']),
      items: items is List
          ? items
              .whereType<Map>()
              .map((item) => QsoLog.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : const [],
    );
  }

  Future<QsoQuickParseResult> quickParse(String text) async {
    final response = await _apiClient.client.post<Map<String, dynamic>>(
      await _url('qso-logs/quick-parse'),
      data: {'text': text},
      options: Options(headers: const {'Accept': 'application/json'}),
    );
    final payload = _data(response.data);
    if (payload is Map) {
      return QsoQuickParseResult.fromJson(Map<String, dynamic>.from(payload));
    }
    return QsoQuickParseResult.empty();
  }

  Future<List<QsoLog>> importAdifFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['adi', 'adif', 'txt'],
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null) return [];

    final raw = await File(path).readAsString();
    final response = await _apiClient.client.post<Map<String, dynamic>>(
      await _url('qso-logs/import/adif'),
      data: {'adif': raw},
      options: Options(headers: const {'Accept': 'application/json'}),
    );
    final payload = _data(response.data);
    final items = payload is Map ? payload['items'] : null;
    if (items is! List) return [];
    return items
        .whereType<Map>()
        .map((item) => QsoLog.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<String> exportAdifToDownloads() async {
    final response = await _apiClient.client.get<Map<String, dynamic>>(
      await _url('qso-logs/export/adif'),
      options: Options(headers: const {'Accept': 'application/json'}),
    );
    final adif = _data(response.data)?.toString() ?? '';
    final directory = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final file = File(
      '${directory.path}${Platform.pathSeparator}beacon-qso-$timestamp.adi',
    );
    await file.writeAsString(adif);
    return file.path;
  }

  Future<QslLink> createStaticQslLink(String qsoId) async {
    final baseUrl = await _endpointSettingsService.getBeaconApiBaseUrl();
    final frontendBaseUrl =
        await _endpointSettingsService.getBeaconFrontendBaseUrl();
    final response = await _apiClient.client.post<Map<String, dynamic>>(
      _joinUrl(baseUrl, 'qso-logs/$qsoId/qsl/static-link'),
      options: Options(headers: const {'Accept': 'application/json'}),
    );
    return _linkFromPayload(
      _data(response.data),
      apiBaseUrl: baseUrl,
      frontendBaseUrl: frontendBaseUrl,
      linkType: 'static',
    );
  }

  Future<void> deleteCloudLog(String qsoId) async {
    await _apiClient.client.delete<void>(
      await _url('qso-logs/$qsoId'),
      options: Options(headers: const {'Accept': 'application/json'}),
    );
  }

  Future<QslLink> upsertDynamicQslLink({
    required bool verifierRequired,
  }) async {
    final baseUrl = await _endpointSettingsService.getBeaconApiBaseUrl();
    final frontendBaseUrl =
        await _endpointSettingsService.getBeaconFrontendBaseUrl();
    final response = await _apiClient.client.post<Map<String, dynamic>>(
      await _url('qso-logs/qsl/dynamic-link'),
      data: {
        'verifier_required': verifierRequired,
        'base_url': frontendBaseUrl,
      },
      options: Options(headers: const {'Accept': 'application/json'}),
    );
    return _linkFromPayload(
      _data(response.data),
      apiBaseUrl: baseUrl,
      frontendBaseUrl: frontendBaseUrl,
      linkType: 'dynamic',
    );
  }

  Future<QslPublicPageData> fetchPublicQslPage({
    required String linkType,
    required String token,
    required String apiBaseUrl,
    String verifierCode = '',
  }) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: _normalizeApiBaseUrl(apiBaseUrl),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: const {'Accept': 'application/json'},
      ),
    );
    final response = await dio.get<Map<String, dynamic>>(
      'qsl/$linkType/$token',
      queryParameters: verifierCode.trim().isEmpty
          ? null
          : {'verifier_code': verifierCode.trim()},
    );
    final payload = _data(response.data);
    if (payload is Map) {
      return QslPublicPageData.fromJson(Map<String, dynamic>.from(payload));
    }
    return const QslPublicPageData(
      linkType: 'static',
      verifierRequired: false,
      items: [],
    );
  }

  Future<int> confirmPublicQsl({
    required String linkType,
    required String token,
    required String apiBaseUrl,
    List<String>? qsoIds,
    String verifierCode = '',
    String confirmerCallsign = '',
    String note = '',
  }) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: _normalizeApiBaseUrl(apiBaseUrl),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
    final response = await dio.post<Map<String, dynamic>>(
      'qsl/$linkType/$token/receipt',
      data: {
        'qso_ids': qsoIds,
        'verifier_code': verifierCode.trim().isEmpty ? null : verifierCode,
        'confirmer_callsign':
            confirmerCallsign.trim().isEmpty ? null : confirmerCallsign.trim(),
        'note': note.trim().isEmpty ? null : note.trim(),
      },
    );
    final payload = _data(response.data);
    if (payload is Map) {
      return _intValue(payload['confirmed']);
    }
    return 0;
  }

  Future<String> _url(String path) async {
    final baseUrl = await _endpointSettingsService.getBeaconApiBaseUrl();
    final cleanBase = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final cleanPath = path.replaceFirst(RegExp(r'^/+'), '');
    return '$cleanBase/$cleanPath';
  }

  String _joinUrl(String baseUrl, String path) {
    final cleanBase = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final cleanPath = path.replaceFirst(RegExp(r'^/+'), '');
    return '$cleanBase/$cleanPath';
  }

  String _normalizeApiBaseUrl(String url) {
    return _endpointSettingsService.normalizeBeaconApiBaseUrl(url);
  }

  Object? _data(Map<String, dynamic>? response) {
    if (response == null) return null;
    return response['data'] ?? response;
  }

  QslLink _linkFromPayload(
    Object? payload, {
    required String apiBaseUrl,
    required String frontendBaseUrl,
    required String linkType,
  }) {
    if (payload is! Map) return const QslLink(url: '', token: '');
    final map = Map<String, dynamic>.from(payload);
    final token = map['token']?.toString() ?? '';
    return QslLink(
      token: token,
      url: token.isEmpty
          ? ''
          : _beaconFrontendRouteUrl(
              frontendBaseUrl: frontendBaseUrl,
              apiBaseUrl: apiBaseUrl,
              route: 'qsl/$linkType/$token',
            ),
      verifierRequired:
          map['verifier_required'] == true || map['verifierRequired'] == true,
      verifierCode:
          map['verifier_code']?.toString() ?? map['verifierCode']?.toString(),
      verifierExpiresAt: DateTime.tryParse(
        map['verifier_expires_at']?.toString() ??
            map['verifierExpiresAt']?.toString() ??
            '',
      ),
      qslStatus: map['qsl_status']?.toString() ?? map['qslStatus']?.toString(),
    );
  }

  String _beaconFrontendRouteUrl({
    required String frontendBaseUrl,
    required String apiBaseUrl,
    required String route,
  }) {
    final cleanBase = frontendBaseUrl.split('#').first.replaceFirst(
          RegExp(r'/+$'),
          '',
        );
    final encodedApi = Uri.encodeComponent(apiBaseUrl);
    final cleanRoute = route.replaceFirst(RegExp(r'^/+'), '');
    return '$cleanBase/#/$cleanRoute?api=$encodedApi';
  }

  int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class QsoSyncSummary {
  final int inserted;
  final int updated;
  final int skipped;
  final List<QsoLog> items;

  const QsoSyncSummary({
    this.inserted = 0,
    this.updated = 0,
    this.skipped = 0,
    this.items = const [],
  });
}

class QsoQuickParseResult {
  final String? date;
  final String? callsign;
  final String? satName;
  final String? propMode;
  final double confidence;

  const QsoQuickParseResult({
    required this.date,
    required this.callsign,
    required this.satName,
    required this.propMode,
    required this.confidence,
  });

  factory QsoQuickParseResult.fromJson(Map<String, dynamic> json) {
    return QsoQuickParseResult(
      date: json['date']?.toString(),
      callsign: json['callsign']?.toString(),
      satName: json['sat_name']?.toString() ?? json['satName']?.toString(),
      propMode: json['prop_mode']?.toString() ?? json['propMode']?.toString(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    );
  }

  factory QsoQuickParseResult.empty() {
    return const QsoQuickParseResult(
      date: null,
      callsign: null,
      satName: null,
      propMode: null,
      confidence: 0,
    );
  }
}

class QslLink {
  final String token;
  final String url;
  final bool verifierRequired;
  final String? verifierCode;
  final DateTime? verifierExpiresAt;
  final String? qslStatus;

  const QslLink({
    required this.token,
    required this.url,
    this.verifierRequired = false,
    this.verifierCode,
    this.verifierExpiresAt,
    this.qslStatus,
  });
}

class QslPublicPageData {
  final String linkType;
  final bool verifierRequired;
  final List<QslPublicQsoItem> items;

  const QslPublicPageData({
    required this.linkType,
    required this.verifierRequired,
    required this.items,
  });

  factory QslPublicPageData.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    return QslPublicPageData(
      linkType: json['link_type']?.toString() ??
          json['linkType']?.toString() ??
          'static',
      verifierRequired:
          json['verifier_required'] == true || json['verifierRequired'] == true,
      items: items is List
          ? items
              .whereType<Map>()
              .map((item) => QslPublicQsoItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList()
          : const [],
    );
  }
}

class QslPublicQsoItem {
  final String id;
  final DateTime? dateTime;
  final String callsign;
  final String band;
  final String mode;
  final String frequency;
  final String satName;
  final String propMode;

  const QslPublicQsoItem({
    required this.id,
    required this.dateTime,
    required this.callsign,
    required this.band,
    required this.mode,
    required this.frequency,
    required this.satName,
    required this.propMode,
  });

  factory QslPublicQsoItem.fromJson(Map<String, dynamic> json) {
    return QslPublicQsoItem(
      id: json['id']?.toString() ?? '',
      dateTime: DateTime.tryParse(json['date_time']?.toString() ?? ''),
      callsign: json['callsign']?.toString() ?? '',
      band: json['band']?.toString() ?? '',
      mode: json['mode']?.toString() ?? '',
      frequency: json['frequency']?.toString() ?? '',
      satName:
          json['sat_name']?.toString() ?? json['satName']?.toString() ?? '',
      propMode:
          json['prop_mode']?.toString() ?? json['propMode']?.toString() ?? '',
    );
  }
}
