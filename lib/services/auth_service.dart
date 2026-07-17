import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import '../core/api_client.dart';
import '../core/constants.dart';
import 'app_endpoint_settings_service.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final AppEndpointSettingsService _endpointSettingsService =
      const AppEndpointSettingsService();

  // Expose API URL configuration
  Future<void> updateApiUrl(String url) async {
    await _apiClient.updateBaseUrl(url);
  }

  Future<String> getApiUrl() async {
    return await _apiClient.getBaseUrl();
  }

  Future<Map<String, dynamic>> checkConnectivity() async {
    return await _apiClient.testConnection();
  }

  /// Desktop (Linux/Windows/macOS) uses an http://localhost callback with
  /// the system browser; Android/iOS always use a custom URL scheme deep link.
  static bool get _isMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  static bool get _isDesktop {
    if (kIsWeb || _isMobile) return false;
    return Platform.isLinux || Platform.isWindows || Platform.isMacOS;
  }

  static bool get _usesNativeRedirectBridge => _isMobile;

  static String get _redirectUri => _usesNativeRedirectBridge
      ? AppConstants.oauthMobileHttpsRedirectUri
      : _isDesktop
          ? AppConstants.oauthDesktopRedirectUri
          : AppConstants.oauthMobileRedirectUri;

  /// Callback scheme handed to flutter_web_auth_2.
  /// Desktop non-webview mode expects the literal "http://localhost:{port}".
  static String get _callbackUrlScheme => _isDesktop
      ? 'http://localhost:${AppConstants.desktopCallbackPort}'
      : AppConstants.oauthRedirectScheme;

  Future<void> sendCode(String email) async {
    try {
      final response = await _apiClient.client.post(
        'auth/send-code',
        data: {'email': email},
      );

      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Failed to send code');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> login(String email, String code) async {
    try {
      final response = await _apiClient.client.post(
        'auth/login',
        data: {
          'email': email,
          'code': code,
        },
      );

      final data = response.data;
      if (data['success'] == true) {
        final token = data['data']['token'];
        final user = data['data']['user'];

        await _storage.write(key: AppConstants.tokenKey, value: token);
        return user;
      } else {
        throw Exception(data['message'] ?? 'Login failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// OpenOIDC login using Authorization Code Flow + PKCE.
  ///
  /// Public mobile client — no client secret. PKCE protects the code exchange.
  Future<Map<String, dynamic>> loginWithOAuth() async {
    try {
      final oidcSettings = await _endpointSettingsService.getOpenOidcSettings();
      final oauthBaseUrl = oidcSettings.baseUrl;
      final clientId = oidcSettings.clientId;
      final endpoints = await _loadOpenOidcEndpoints(oauthBaseUrl);

      // 1. Generate PKCE code_verifier and code_challenge (S256)
      final codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);
      final state = _generateRandomString(32);

      // 2. Build authorization URL
      final authUrl =
          Uri.parse(endpoints.authorizationEndpoint).replace(queryParameters: {
        'response_type': 'code',
        'client_id': clientId,
        'redirect_uri': _redirectUri,
        'scope': 'openid profile email',
        'state': state,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
      });
      debugPrint(
        'OAuth authorize: endpoint=${endpoints.authorizationEndpoint}, '
        'redirect_uri=$_redirectUri, callback_scheme=$_callbackUrlScheme, '
        'platform=${_platformLabel()}',
      );

      // 3. Open browser for user authentication.
      //    Desktop: system browser + local http callback (no embedded webview).
      //    Mobile: in-app browser tab + custom scheme deep link.
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: _callbackUrlScheme,
        options: FlutterWebAuth2Options(
          useWebview: !_isDesktop,
        ),
      );

      // 4. Validate callback and extract code
      final callbackUri = Uri.parse(result);
      final error = callbackUri.queryParameters['error'];
      if (error != null) {
        final desc = callbackUri.queryParameters['error_description'] ?? error;
        throw Exception('Authorization failed: $desc');
      }

      final returnedState = callbackUri.queryParameters['state'];
      if (returnedState != state) {
        throw Exception('State mismatch — possible CSRF attack');
      }

      final code = callbackUri.queryParameters['code'];
      if (code == null) {
        throw Exception('No authorization code received from OpenOIDC');
      }

      // 5. Exchange code for tokens (with PKCE verifier)
      final tokenResponse = await http.post(
        Uri.parse(endpoints.tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'client_id': clientId,
          'code': code,
          'redirect_uri': _redirectUri,
          'code_verifier': codeVerifier,
        },
      );

      if (tokenResponse.statusCode != 200) {
        throw Exception('Token exchange failed: ${tokenResponse.body}');
      }

      final tokenData = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
      final accessToken = tokenData['access_token'] as String?;
      final idToken = tokenData['id_token'] as String?;
      final refreshToken = tokenData['refresh_token'] as String?;

      if (accessToken == null) {
        throw Exception('No access token received');
      }

      // 6. Decode ID token to get user info
      final claims = _decodeJwtPayload(idToken ?? accessToken);

      // 7. Persist tokens
      await _storage.write(key: AppConstants.tokenKey, value: accessToken);
      if (refreshToken != null) {
        await _storage.write(
            key: AppConstants.refreshTokenKey, value: refreshToken);
      }

      final userInfo = {
        'id': claims['sub'],
        'email': claims['email'],
        'name': claims['name'] ?? claims['display_name'],
        'image': claims['picture'] ?? claims['avatar_url'],
      };
      final remoteUserInfo = await _fetchUserInfo(accessToken);
      final mergedUserInfo = {
        ...userInfo,
        ...remoteUserInfo,
        'id': remoteUserInfo['id'] ?? remoteUserInfo['sub'] ?? userInfo['id'],
        'name': remoteUserInfo['name'] ??
            remoteUserInfo['display_name'] ??
            userInfo['name'],
        'image': remoteUserInfo['image'] ??
            remoteUserInfo['picture'] ??
            remoteUserInfo['avatar_url'] ??
            userInfo['image'],
      };
      await _cacheUserInfo(mergedUserInfo);

      // 8. Return user info
      return mergedUserInfo;
    } catch (e) {
      debugPrint('OAuth login error: $e');
      rethrow;
    }
  }

  static String _platformLabel() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isLinux) return 'linux';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    return 'unknown';
  }

  Future<void> logout() async {
    await _storage.delete(key: AppConstants.tokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
    await _storage.delete(key: AppConstants.cachedUserInfoKey);
  }

  Future<bool> isLoggedIn() async {
    String? token;
    try {
      token = await _storage.read(key: AppConstants.tokenKey);
    } catch (e) {
      debugPrint('Failed to read auth token: $e');
      try {
        await _storage.delete(key: AppConstants.tokenKey);
      } catch (deleteError) {
        debugPrint('Failed to clear auth token: $deleteError');
      }
      return false;
    }
    return token != null;
  }

  Future<Map<String, dynamic>?> getCurrentUserInfo({
    bool refresh = true,
  }) async {
    final cached = await _readCachedUserInfo();
    if (!refresh) return cached;

    final token = await _readToken();
    if (token == null) return cached;
    final tokenClaims = _decodeJwtPayloadOrEmpty(token);
    final remote = await _fetchUserInfo(token);
    final merged = {
      ...?cached,
      ...tokenClaims,
      ...remote,
      'id':
          remote['id'] ?? remote['sub'] ?? tokenClaims['sub'] ?? cached?['id'],
      'email': remote['email'] ?? tokenClaims['email'] ?? cached?['email'],
      'name': remote['name'] ??
          remote['display_name'] ??
          tokenClaims['name'] ??
          tokenClaims['display_name'] ??
          cached?['name'],
      'image': remote['image'] ??
          remote['picture'] ??
          remote['avatar_url'] ??
          tokenClaims['picture'] ??
          tokenClaims['avatar_url'] ??
          cached?['image'],
    };
    if (merged.values.every((value) => value == null || value == '')) {
      return cached;
    }
    await _cacheUserInfo(merged);
    return merged;
  }

  Future<String?> _readToken() async {
    try {
      return await _storage.read(key: AppConstants.tokenKey);
    } catch (e) {
      debugPrint('Failed to read auth token: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> _fetchUserInfo(String accessToken) async {
    try {
      final oidcSettings = await _endpointSettingsService.getOpenOidcSettings();
      final oauthBaseUrl = oidcSettings.baseUrl;
      final oidcEndpoints = await _loadOpenOidcEndpoints(oauthBaseUrl);
      final userInfoEndpoints = [
        oidcEndpoints.userInfoEndpoint,
        '$oauthBaseUrl/api/v1/me',
      ];
      for (final endpoint in userInfoEndpoints) {
        final response = await http.get(
          Uri.parse(endpoint),
          headers: {'Authorization': 'Bearer $accessToken'},
        ).timeout(const Duration(seconds: 8));
        if (response.statusCode != 200) continue;
        final data = jsonDecode(response.body);
        if (data is! Map<String, dynamic>) continue;
        return _normalizeUserInfo(data);
      }
      return {};
    } catch (e) {
      debugPrint('Failed to fetch OIDC userinfo: $e');
      return {};
    }
  }

  Future<_OpenOidcEndpoints> _loadOpenOidcEndpoints(String baseUrl) async {
    final discoveryUrl = Uri.parse('$baseUrl/.well-known/openid-configuration');
    try {
      final response = await http
          .get(discoveryUrl, headers: {'Accept': 'application/json'}).timeout(
        const Duration(seconds: 8),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return _OpenOidcEndpoints.fromDiscovery(data, baseUrl);
        }
      }
    } catch (e) {
      debugPrint('Failed to load OIDC discovery: $e');
    }
    return _OpenOidcEndpoints.fallback(baseUrl);
  }

  Map<String, dynamic> _normalizeUserInfo(Map<String, dynamic> data) {
    final nested = data['data'];
    final source = nested is Map<String, dynamic> ? nested : data;
    return {
      ...source,
      'id': source['id'] ?? source['sub'],
      'email': source['email'],
      'name': source['name'] ?? source['display_name'],
      'image': source['image'] ?? source['picture'] ?? source['avatar_url'],
    };
  }

  Future<void> _cacheUserInfo(Map<String, dynamic> userInfo) async {
    await _storage.write(
      key: AppConstants.cachedUserInfoKey,
      value: jsonEncode(userInfo),
    );
  }

  Future<Map<String, dynamic>?> _readCachedUserInfo() async {
    try {
      final raw = await _storage.read(key: AppConstants.cachedUserInfoKey);
      if (raw == null || raw.isEmpty) return null;
      final data = jsonDecode(raw);
      return data is Map<String, dynamic> ? data : null;
    } catch (e) {
      debugPrint('Failed to read cached user info: $e');
      return null;
    }
  }

  // ---- PKCE helpers ----

  /// Generate a cryptographically random code_verifier (43-128 chars).
  String _generateCodeVerifier() {
    return _generateRandomString(64);
  }

  /// Derive code_challenge = BASE64URL(SHA256(code_verifier)).
  String _generateCodeChallenge(String verifier) {
    final bytes = ascii.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  /// Generate a URL-safe random string for verifier/state.
  String _generateRandomString(int length) {
    const charset =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  /// Decode the payload section of a JWT without verifying signature
  /// (token came directly from the trusted OIDC server over TLS).
  Map<String, dynamic> _decodeJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw Exception('Invalid JWT format');
    }
    final payload =
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    return jsonDecode(payload) as Map<String, dynamic>;
  }

  Map<String, dynamic> _decodeJwtPayloadOrEmpty(String token) {
    try {
      final payload = _decodeJwtPayload(token);
      return {
        ...payload,
        'id': payload['id'] ?? payload['sub'],
        'email': payload['email'],
        'name': payload['name'] ?? payload['display_name'],
        'image':
            payload['image'] ?? payload['picture'] ?? payload['avatar_url'],
      };
    } catch (_) {
      return {};
    }
  }
}

class _OpenOidcEndpoints {
  final String authorizationEndpoint;
  final String tokenEndpoint;
  final String userInfoEndpoint;

  const _OpenOidcEndpoints({
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.userInfoEndpoint,
  });

  factory _OpenOidcEndpoints.fromDiscovery(
    Map<String, dynamic> data,
    String fallbackBaseUrl,
  ) {
    final fallback = _OpenOidcEndpoints.fallback(fallbackBaseUrl);
    return _OpenOidcEndpoints(
      authorizationEndpoint: _stringOrFallback(
        data['authorization_endpoint'],
        fallback.authorizationEndpoint,
      ),
      tokenEndpoint: _stringOrFallback(
        data['token_endpoint'],
        fallback.tokenEndpoint,
      ),
      userInfoEndpoint: _stringOrFallback(
        data['userinfo_endpoint'],
        fallback.userInfoEndpoint,
      ),
    );
  }

  factory _OpenOidcEndpoints.fallback(String baseUrl) {
    return _OpenOidcEndpoints(
      authorizationEndpoint: '$baseUrl/oauth2/authorize',
      tokenEndpoint: '$baseUrl/oauth2/token',
      userInfoEndpoint: '$baseUrl/oauth2/userinfo',
    );
  }

  static String _stringOrFallback(Object? value, String fallback) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }
}
