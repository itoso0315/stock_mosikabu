import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

abstract interface class BackendWarmupService {
  Future<void> warmUp();
}

class HttpBackendWarmupService implements BackendWarmupService {
  HttpBackendWarmupService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = ApiConfig.resolve(baseUrl);

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<void> warmUp() async {
    final uri = Uri.parse('$_baseUrl/health');
    try {
      final response = await _client
          .get(uri)
          .timeout(ApiConfig.healthRequestTimeout);
      if (kDebugMode && response.statusCode != 200) {
        debugPrint('[BackendWarmup] HTTP ${response.statusCode} from $uri');
      }
    } on Object catch (error, stackTrace) {
      // Warm-up is best effort. App startup and user actions must continue even
      // when Render is still waking or the device is offline.
      if (kDebugMode) {
        debugPrint('[BackendWarmup] Request failed for $uri: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }
}
