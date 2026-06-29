class BeaconQslRoute {
  final String linkType;
  final String token;
  final String? apiBaseUrl;

  const BeaconQslRoute({
    required this.linkType,
    required this.token,
    this.apiBaseUrl,
  });
}

BeaconQslRoute? parseBeaconQslRouteFromText(String rawValue) {
  final value = rawValue.trim();
  if (value.isEmpty) return null;

  final uri = Uri.tryParse(value);
  if (uri == null) return null;

  final fragmentRoute = _parseRoute(uri.fragment);
  if (fragmentRoute != null) return fragmentRoute;

  final directRoute = _parseRoute(value);
  if (directRoute != null) return directRoute;

  final apiRoute = _parseApiRoute(uri);
  if (apiRoute != null) return apiRoute;

  return null;
}

BeaconQslRoute? _parseRoute(String rawRoute) {
  final route = rawRoute.trim();
  if (route.isEmpty) return null;
  final uri = Uri.tryParse(route.startsWith('/') ? route : '/$route');
  if (uri == null || uri.pathSegments.length < 3) return null;
  if (uri.pathSegments[0] != 'qsl') return null;
  final linkType = uri.pathSegments[1];
  if (linkType != 'static' && linkType != 'dynamic') return null;
  final token = uri.pathSegments[2].trim();
  if (token.isEmpty) return null;
  return BeaconQslRoute(
    linkType: linkType,
    token: token,
    apiBaseUrl: uri.queryParameters['api'],
  );
}

BeaconQslRoute? _parseApiRoute(Uri uri) {
  final segments = uri.pathSegments;
  final qslIndex = segments.indexOf('qsl');
  if (qslIndex < 0 || segments.length <= qslIndex + 2) return null;

  final linkType = segments[qslIndex + 1];
  if (linkType != 'static' && linkType != 'dynamic') return null;
  final token = segments[qslIndex + 2].trim();
  if (token.isEmpty) return null;

  String? apiBaseUrl;
  if (uri.hasScheme && uri.host.isNotEmpty) {
    final prefixSegments = segments.take(qslIndex).toList();
    final path = prefixSegments.isEmpty ? '/' : '/${prefixSegments.join('/')}/';
    apiBaseUrl = uri.replace(path: path, query: '', fragment: '').toString();
  }

  return BeaconQslRoute(
    linkType: linkType,
    token: token,
    apiBaseUrl: uri.queryParameters['api'] ?? apiBaseUrl,
  );
}
