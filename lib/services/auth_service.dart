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

class AuthService {
  final ApiClient _apiClient = ApiClient();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

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

  // OpenOIDC configuration
  static const String _oauthBaseUrl = AppConstants.oauthBaseUrl;
  static const String _clientId = AppConstants.oauthClientId;

  // OIDC standard endpoints
  static String get _authorizeEndpoint => '$_oauthBaseUrl/oauth2/authorize';
  static String get _tokenEndpoint => '$_oauthBaseUrl/oauth2/token';

  /// Desktop (Linux/Windows/macOS) uses an http://localhost callback with
  /// the system browser; mobile uses a custom URL scheme deep link.
  static bool get _isDesktop {
    if (kIsWeb) return false;
    return Platform.isLinux || Platform.isWindows || Platform.isMacOS;
  }

  static String get _redirectUri => _isDesktop
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
      // 1. Generate PKCE code_verifier and code_challenge (S256)
      final codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);
      final state = _generateRandomString(32);

      // 2. Build authorization URL
      final authUrl = Uri.parse(_authorizeEndpoint).replace(queryParameters: {
        'response_type': 'code',
        'client_id': _clientId,
        'redirect_uri': _redirectUri,
        'scope': 'openid profile email',
        'state': state,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
      });

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
        Uri.parse(_tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'client_id': _clientId,
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

      // 8. Return user info
      return {
        'id': claims['sub'],
        'email': claims['email'],
        'name': claims['name'],
      };
    } catch (e) {
      debugPrint('OAuth login error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: AppConstants.tokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
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
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    return jsonDecode(payload) as Map<String, dynamic>;
  }
}
