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
  static const String cachedUserInfoKey = 'cached_user_info';
  static const String oauthBaseUrlKey = 'oauth_base_url';
  static const String oauthClientIdKey = 'oauth_client_id';
  static const String beaconApiBaseUrlKey = 'beacon_api_base_url';
  static const String beaconFrontendBaseUrlKey = 'beacon_frontend_base_url';
  static const String tiandituTokenKey = 'tianditu_token';
  static const String qrzUsernameKey = 'qrz_username';
  static const String qrzPasswordKey = 'qrz_password';
  static const String qrzLookupModeKey = 'qrz_lookup_mode';
  static const String qrzDebugEnabledKey = 'qrz_debug_enabled';
  static const String qrzSessionKey = 'qrz_session_key';
  static const String llmEnabledKey = 'llm_enabled';
  static const String llmBaseUrlKey = 'llm_base_url';
  static const String llmApiKeyKey = 'llm_api_key';
  static const String llmModelKey = 'llm_model';
  static const String smtpEnabledKey = 'smtp_enabled';
  static const String smtpHostKey = 'smtp_host';
  static const String smtpPortKey = 'smtp_port';
  static const String smtpUsernameKey = 'smtp_username';
  static const String smtpPasswordKey = 'smtp_password';
  static const String smtpFromEmailKey = 'smtp_from_email';
  static const String smtpFromNameKey = 'smtp_from_name';
}
