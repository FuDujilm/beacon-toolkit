import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

import '../core/api_client.dart';
import '../models/callsign_profile.dart';
import 'app_endpoint_settings_service.dart';

class CallsignLookupService {
  final ApiClient _apiClient;
  final AppEndpointSettingsService _settingsService;

  CallsignLookupService({
    ApiClient? apiClient,
    AppEndpointSettingsService? settingsService,
  })  : _apiClient = apiClient ?? ApiClient(),
        _settingsService =
            settingsService ?? const AppEndpointSettingsService();

  Future<String> verifyQrzLogin(QrzSettings settings) async {
    if (!settings.hasCredentials) {
      throw const FormatException('请填写 QRZ.COM 用户名和密码');
    }
    final sessionKey = await _loginQrz(settings);
    return sessionKey;
  }

  Future<CallsignLookupResult> lookup(String callsign) async {
    final normalized = _normalizeCallsign(callsign);
    final settings = await _settingsService.getQrzSettings();
    final warnings = <String>[];
    final debugLogs = <String>['呼号: $normalized', '模式: ${settings.mode.key}'];
    final items = <CallsignProfile>[];

    if (settings.mode != QrzLookupMode.qrzOnly) {
      try {
        debugLogs.add('beacon-api: 开始查询交换库');
        final beaconItems = await _lookupBeacon(normalized);
        debugLogs.add('beacon-api: 返回 ${beaconItems.length} 条');
        items.addAll(beaconItems);
      } catch (e) {
        final message = _friendlyError(e);
        debugLogs.add('beacon-api: 失败 $message');
        warnings.add('beacon-api 查询失败: $message');
      }
    }

    if (settings.mode == QrzLookupMode.beaconOnly) {
      return CallsignLookupResult(
        items: _dedupe(items),
        warnings: warnings,
        debugLogs: debugLogs,
      );
    }

    final shouldQueryQrz =
        settings.mode == QrzLookupMode.qrzOnly || items.isEmpty;
    if (shouldQueryQrz) {
      if (!settings.hasCredentials) {
        warnings.add('未配置 QRZ.COM 账号密码');
        debugLogs.add('QRZ: 未配置账号密码');
      } else {
        try {
          debugLogs.add('QRZ 代理: 开始查询');
          final proxyItems = await _lookupQrzProxy(normalized, settings);
          debugLogs.add(
            'QRZ 代理: 返回 ${proxyItems.length} 条，Biography 长度 ${_biographyLength(proxyItems)}',
          );
          items.addAll(proxyItems);
          final needsBiography = proxyItems.every(
            (item) => item.biographyHtml?.trim().isNotEmpty != true,
          );
          if (needsBiography) {
            debugLogs.add('QRZ 官方: 代理无 Biography，开始补拉');
            final official = await _lookupQrzOfficial(normalized, settings);
            debugLogs.add(
              'QRZ 官方: 返回 ${official.callsign}，Biography 长度 ${official.biographyHtml?.length ?? 0}',
            );
            items.removeWhere(
              (item) =>
                  item.source == official.source &&
                  item.callsign.toUpperCase() ==
                      official.callsign.toUpperCase(),
            );
            items.add(official);
          }
        } catch (proxyError) {
          final proxyMessage = _friendlyError(proxyError);
          debugLogs.add('QRZ 代理: 失败 $proxyMessage');
          warnings.add('QRZ 代理查询失败: $proxyMessage');
          try {
            debugLogs.add('QRZ 官方: 开始回退查询');
            final official = await _lookupQrzOfficial(normalized, settings);
            debugLogs.add(
              'QRZ 官方: 返回 ${official.callsign}，Biography 长度 ${official.biographyHtml?.length ?? 0}',
            );
            items.add(official);
          } catch (officialError) {
            final officialMessage = _friendlyError(officialError);
            debugLogs.add('QRZ 官方: 失败 $officialMessage');
            warnings.add('QRZ 官方查询失败: $officialMessage');
          }
        }
      }
    }

    final deduped = _dedupe(items);
    return CallsignLookupResult(
      items: deduped,
      warnings: deduped.isEmpty ? warnings : const [],
      debugLogs: [
        ...debugLogs,
        '最终结果: ${deduped.length} 条',
        for (final item in deduped)
          '${item.source}:${item.callsign} Biography 长度 ${item.biographyHtml?.length ?? 0}',
      ],
    );
  }

  Future<List<CallsignProfile>> _lookupBeacon(String callsign) async {
    final baseUrl = await _settingsService.getBeaconApiBaseUrl();
    final response = await _apiClient.client.get<Map<String, dynamic>>(
      _joinUrl(baseUrl, 'callsigns/$callsign'),
    );
    return _profilesFromApiResponse(response.data);
  }

  Future<List<CallsignProfile>> _lookupQrzProxy(
    String callsign,
    QrzSettings settings,
  ) async {
    final baseUrl = await _settingsService.getBeaconApiBaseUrl();
    final response = await _apiClient.client.post<Map<String, dynamic>>(
      _joinUrl(baseUrl, 'callsigns/qrz/lookup'),
      data: {
        'username': settings.username,
        'password': settings.password,
        'callsign': callsign,
      },
    );
    return _profilesFromApiResponse(response.data);
  }

  Future<CallsignProfile> _lookupQrzOfficial(
    String callsign,
    QrzSettings settings,
  ) async {
    var sessionKey = await _settingsService.getQrzSessionKey();
    if (sessionKey.isEmpty) {
      sessionKey = await _loginQrz(settings);
    }
    try {
      return await _fetchQrzProfileWithDxcc(sessionKey, callsign);
    } on QrzSessionExpiredException {
      await _settingsService.updateQrzSessionKey('');
      sessionKey = await _loginQrz(settings);
      return _fetchQrzProfileWithDxcc(sessionKey, callsign);
    }
  }

  Future<CallsignProfile> _fetchQrzProfileWithDxcc(
    String sessionKey,
    String callsign,
  ) async {
    var profile = await _fetchQrzProfile(sessionKey, callsign);
    final dxcc = profile.dxcc?.dxcc;
    if (dxcc != null && dxcc.isNotEmpty) {
      try {
        final dxccInfo = await _fetchQrzDxcc(sessionKey, dxcc);
        profile = profile.copyWith(dxcc: dxccInfo);
      } catch (_) {}
    }
    try {
      final html = await _fetchQrzBiographyHtml(sessionKey, callsign);
      if (html.trim().isNotEmpty) {
        profile = profile.copyWith(biographyHtml: html);
      }
    } on QrzSessionExpiredException {
      rethrow;
    } catch (_) {}
    return profile;
  }

  Future<String> _loginQrz(QrzSettings settings) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ));
    final response = await dio.get<String>(
      _qrzUri({
        'username': settings.username,
        'password': settings.password,
      }),
    );
    final document = XmlDocument.parse(response.data ?? '');
    final error = _firstText(document, 'Error');
    if (error != null && error.isNotEmpty) {
      throw FormatException('QRZ 登录失败: $error');
    }
    final key = _firstText(document, 'Key');
    if (key == null || key.isEmpty) {
      throw const FormatException('QRZ 未返回 session key');
    }
    await _settingsService.updateQrzSessionKey(key);
    return key;
  }

  Future<CallsignProfile> _fetchQrzProfile(
    String sessionKey,
    String callsign,
  ) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ));
    final response = await dio.get<String>(
      _qrzUri({
        's': sessionKey,
        'callsign': callsign,
      }),
    );
    final document = XmlDocument.parse(response.data ?? '');
    final error = _firstText(document, 'Error');
    if (error != null && error.isNotEmpty) {
      if (error.toLowerCase().contains('session')) {
        throw QrzSessionExpiredException(error);
      }
      throw FormatException('QRZ 查询失败: $error');
    }
    final callElement = _firstElement(document.findAllElements('Callsign'));
    if (callElement == null) {
      throw const FormatException('QRZ 未返回该呼号资料');
    }
    return CallsignProfile(
      source: 'qrz',
      callsign: _childText(callElement, 'call')?.toUpperCase() ?? callsign,
      displayName: _displayName(callElement),
      firstName: _childText(callElement, 'fname'),
      lastName: _childText(callElement, 'name'),
      nickname: _childText(callElement, 'nickname'),
      country: _childText(callElement, 'country'),
      address: [
        _childText(callElement, 'addr1'),
        _childText(callElement, 'addr2'),
        _childText(callElement, 'state'),
        _childText(callElement, 'zip'),
      ].whereType<String>().where((item) => item.isNotEmpty).join(', '),
      grid: _childText(callElement, 'grid'),
      latitude: double.tryParse(_childText(callElement, 'lat') ?? ''),
      longitude: double.tryParse(_childText(callElement, 'lon') ?? ''),
      email: _childText(callElement, 'email'),
      url: _childText(callElement, 'url'),
      imageUrl: _childText(callElement, 'image'),
      qsl: _childText(callElement, 'qslmgr'),
      cqZone: _childText(callElement, 'cqzone'),
      ituZone: _childText(callElement, 'ituzone'),
      dxcc: _childText(callElement, 'dxcc') == null
          ? null
          : DxccInfo(dxcc: _childText(callElement, 'dxcc')),
      biographyHtml: _childText(callElement, 'bio'),
      rawUpdatedAt: _childText(callElement, 'moddate'),
    );
  }

  Future<DxccInfo> _fetchQrzDxcc(String sessionKey, String dxcc) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ));
    final response = await dio.get<String>(
      _qrzUri({
        's': sessionKey,
        'dxcc': dxcc,
      }),
    );
    final document = XmlDocument.parse(response.data ?? '');
    final error = _firstText(document, 'Error');
    if (error != null && error.isNotEmpty) {
      if (error.toLowerCase().contains('session')) {
        throw QrzSessionExpiredException(error);
      }
      throw FormatException('QRZ DXCC 查询失败: $error');
    }
    final dxccElement = _firstElement(document.findAllElements('DXCC'));
    if (dxccElement == null) {
      throw const FormatException('QRZ 未返回 DXCC 资料');
    }
    return DxccInfo(
      dxcc: _childText(dxccElement, 'dxcc'),
      name: _childText(dxccElement, 'name'),
      continent: _childText(dxccElement, 'continent') ??
          _childText(dxccElement, 'cont'),
      countryCode: _childText(dxccElement, 'cc'),
      latitude: double.tryParse(_childText(dxccElement, 'lat') ?? ''),
      longitude: double.tryParse(_childText(dxccElement, 'lon') ?? ''),
      timezone:
          _childText(dxccElement, 'timezone') ?? _childText(dxccElement, 'tz'),
      cqZone: _childText(dxccElement, 'cqzone'),
      ituZone: _childText(dxccElement, 'ituzone'),
      notes: _childText(dxccElement, 'notes'),
    );
  }

  Future<String> _fetchQrzBiographyHtml(
    String sessionKey,
    String callsign,
  ) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ));
    final response = await dio.get<String>(
      _qrzUri({
        's': sessionKey,
        'html': callsign,
      }),
    );
    return _extractBiographyHtml(response.data ?? '');
  }

  String _extractBiographyHtml(String payload) {
    final trimmed = payload.trim();
    if (trimmed.isEmpty) return '';
    final doctypeIndex = trimmed.toLowerCase().indexOf('<!doctype html');
    if (doctypeIndex >= 0) {
      return trimmed.substring(doctypeIndex).trim();
    }
    final htmlIndex = trimmed.toLowerCase().indexOf('<html');
    if (htmlIndex >= 0) {
      return trimmed.substring(htmlIndex).trim();
    }
    if (trimmed.contains('<QRZDatabase')) {
      final error = RegExp(
        r'<Error>(.*?)</Error>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(trimmed)?.group(1)?.trim();
      if (error != null && error.isNotEmpty) {
        if (error.toLowerCase().contains('session')) {
          throw QrzSessionExpiredException(error);
        }
        throw FormatException('QRZ Biography 查询失败: $error');
      }
      return '';
    }
    return trimmed;
  }

  List<CallsignProfile> _profilesFromApiResponse(Map<String, dynamic>? data) {
    final payload = data?['data'] as Map<String, dynamic>? ?? const {};
    final items = payload['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(CallsignProfile.fromJson)
        .where((item) => item.callsign.isNotEmpty)
        .toList();
  }

  List<CallsignProfile> _dedupe(List<CallsignProfile> items) {
    final seen = <String>{};
    return items.where((item) {
      final key = '${item.source}:${item.callsign}';
      return seen.add(key);
    }).toList();
  }

  String _normalizeCallsign(String callsign) {
    final normalized = callsign.trim().toUpperCase();
    if (normalized.length < 3 || normalized.length > 16) {
      throw const FormatException('请输入有效呼号');
    }
    final valid = RegExp(r'^[A-Z0-9/-]+$').hasMatch(normalized);
    if (!valid) {
      throw const FormatException('呼号包含非法字符');
    }
    return normalized;
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      final message = error.response?.data is Map
          ? (error.response?.data['message']?.toString())
          : null;
      if (message != null && message.isNotEmpty) return message;
      final statusCode = error.response?.statusCode;
      if (statusCode == 404) return '接口不存在或当前 beacon-api 未更新';
      if (statusCode != null) return 'HTTP $statusCode';
      return message ?? error.message ?? error.toString();
    }
    if (error is FormatException) {
      return error.message;
    }
    return error.toString();
  }

  String _joinUrl(String baseUrl, String path) {
    final cleanBase = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final cleanPath = path.replaceFirst(RegExp(r'^/+'), '');
    return '$cleanBase/$cleanPath';
  }

  String _qrzUri(Map<String, String> params) {
    final query = params.entries
        .map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}')
        .join(';');
    return 'https://xmldata.qrz.com/xml/current/?$query';
  }

  int _biographyLength(List<CallsignProfile> items) {
    return items.fold<int>(
      0,
      (value, item) => value + (item.biographyHtml?.length ?? 0),
    );
  }

  String? _firstText(XmlDocument document, String name) {
    return _firstElement(document.findAllElements(name))?.innerText.trim();
  }

  String? _childText(XmlElement element, String name) {
    final value = _firstElement(element.findElements(name))?.innerText.trim();
    return value == null || value.isEmpty ? null : value;
  }

  XmlElement? _firstElement(Iterable<XmlElement> elements) {
    final iterator = elements.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }

  String? _displayName(XmlElement element) {
    final value = [
      _childText(element, 'fname'),
      _childText(element, 'name'),
    ].whereType<String>().where((item) => item.isNotEmpty).join(' ');
    return value.isEmpty ? null : value;
  }
}

class QrzSessionExpiredException implements Exception {
  final String message;

  const QrzSessionExpiredException(this.message);

  @override
  String toString() => message;
}
