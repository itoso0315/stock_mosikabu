import 'package:flutter/foundation.dart';

/// Single source of truth for the Backend API endpoint.
///
/// Override per run/build when necessary:
/// `--dart-define=API_BASE_URL=http://192.168.11.8:8000`
abstract final class ApiConfig {
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const _developmentLanBaseUrl = 'http://192.168.11.8:8000';

  static String get baseUrl => resolve();

  static String resolve([String? override]) {
    final supplied = override?.trim();
    if (supplied != null && supplied.isNotEmpty) return _normalize(supplied);
    if (_configuredBaseUrl.isNotEmpty) return _normalize(_configuredBaseUrl);
    return defaultForPlatform(defaultTargetPlatform);
  }

  @visibleForTesting
  static String defaultForPlatform(
    TargetPlatform platform,
  ) => switch (platform) {
    // The iOS Simulator can also reach the Mac through its LAN address, while
    // localhost on a physical iPhone points to the iPhone itself.
    TargetPlatform.iOS => _developmentLanBaseUrl,
    TargetPlatform.android => 'http://10.0.2.2:8000',
    _ => 'http://127.0.0.1:8000',
  };

  static String _normalize(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}
