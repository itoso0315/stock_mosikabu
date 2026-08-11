import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/stock_candidate.dart';
import '../models/stock_quote.dart';

abstract interface class StockPriceService {
  Future<StockQuote> fetchQuote(StockCandidate stock);
}

class StockPriceException implements Exception {
  const StockPriceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HttpStockPriceService implements StockPriceService {
  HttpStockPriceService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? _defaultBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  static String get _defaultBaseUrl {
    const configuredUrl = String.fromEnvironment('API_BASE_URL');
    if (configuredUrl.isNotEmpty) {
      return configuredUrl;
    }
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8000'
        : 'http://127.0.0.1:8000';
  }

  @override
  Future<StockQuote> fetchQuote(StockCandidate stock) async {
    final uri = Uri.parse(
      '$_baseUrl/api/stocks/${stock.code}/quote',
    ).replace(queryParameters: {'name': stock.name});

    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw const StockPriceException('株価を取得できませんでした');
      }
      return StockQuote.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    } on StockPriceException {
      rethrow;
    } on Object {
      throw const StockPriceException('株価を取得できませんでした。時間をおいて再度お試しください');
    }
  }
}
