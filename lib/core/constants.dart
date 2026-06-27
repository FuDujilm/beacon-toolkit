import 'package:flutter/foundation.dart';

class AppConstants {
  // ---- API backend (MeowzExam) ----
  // Web: relative path (same origin / proxied).
  // Desktop/Mobile: MeowzExam runs on port 3001.
  // Android emulator must use 10.0.2.2 instead of localhost.
  static const String baseUrl = kIsWeb ? '/api/' : 'http://localhost:3001/api/';

  // ---- beacon-api backend ----
  // Radio toolbox services use /api/v1.
  static const String beaconApiBaseUrl =
      kIsWeb ? '/api/v1/' : 'http://localhost:3002/api/v1/';

  // ---- OpenOIDC authentication server ----
  static const String oauthBaseUrl = 'http://localhost:8080';
  static const String oauthClientId = 'dcb10e397aa21423c695b54967ccdd61';

  // Mobile (Android/iOS): custom URL scheme deep-link callback.
  static const String oauthRedirectScheme = 'com.beacontoolkit';
  static const String oauthMobileRedirectUri =
      'com.beacontoolkit://oauth/callback';

  // Desktop (Linux/Windows/macOS): flutter_web_auth_2 with useWebview:false
  // requires an http://localhost callback on a fixed port.
  static const int desktopCallbackPort = 8000;
  static const String oauthDesktopRedirectUri =
      'http://localhost:8000/oauth/callback';

  // ---- Secure storage keys ----
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String beaconApiBaseUrlKey = 'beacon_api_base_url';
  static const String tiandituTokenKey = 'tianditu_token';
}
