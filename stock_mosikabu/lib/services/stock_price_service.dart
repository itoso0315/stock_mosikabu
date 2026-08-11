import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/stock_candidate.dart';
import '../models/stock_quote.dart';

abstract interface class StockPriceService {
  Future<StockQuote> fetchQuote(StockCandidate stock);
}

class StockPriceException implements Exception {
  const StockPriceException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class HttpStockPriceService implements StockPriceService {
  HttpStockPriceService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = ApiConfig.resolve(baseUrl);

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<StockQuote> fetchQuote(StockCandidate stock) async {
    final uri = Uri.parse(
      '$_baseUrl/api/stocks/${stock.code}/quote',
    ).replace(queryParameters: {'name': stock.name});

    try {
      _debugLog('GET $uri');
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 15));
      _debugLog(
        'Response ${response.statusCode}: ${_responsePreview(response.body)}',
      );
      if (response.statusCode != 200) {
        throw StockPriceException(
          '株価を取得できませんでした',
          cause: 'HTTP ${response.statusCode}',
        );
      }
      return StockQuote.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    } on StockPriceException {
      rethrow;
    } on TimeoutException catch (error, stackTrace) {
      _debugError('Timeout while requesting $uri', error, stackTrace);
      throw StockPriceException('株価を取得できませんでした。接続がタイムアウトしました', cause: error);
    } on SocketException catch (error, stackTrace) {
      _debugError('SocketException while requesting $uri', error, stackTrace);
      throw StockPriceException(
        '株価を取得できませんでした。Macとのネットワーク接続を確認してください',
        cause: error,
      );
    } on Object catch (error, stackTrace) {
      _debugError('Request failed for $uri', error, stackTrace);
      throw StockPriceException('株価を取得できませんでした。時間をおいて再度お試しください', cause: error);
    }
  }

  static String _responsePreview(String body) =>
      body.length <= 500 ? body : '${body.substring(0, 500)}…';

  static void _debugLog(String message) {
    if (kDebugMode) debugPrint('[StockPrice] $message');
  }

  static void _debugError(String message, Object error, StackTrace stackTrace) {
    if (!kDebugMode) return;
    debugPrint('[StockPrice] $message: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
