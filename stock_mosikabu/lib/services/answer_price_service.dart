import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/answer_close.dart';

abstract interface class AnswerPriceService {
  Future<AnswerClose> fetchClose(String stockCode, DateTime date);
}

class AnswerPriceException implements Exception {
  const AnswerPriceException(this.message);
  final String message;
}

class HttpAnswerPriceService implements AnswerPriceService {
  HttpAnswerPriceService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = ApiConfig.resolve(baseUrl);

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<AnswerClose> fetchClose(String stockCode, DateTime date) async {
    final uri = Uri.parse(
      '$_baseUrl/api/stocks/$stockCode/close',
    ).replace(queryParameters: {'date': _formatDate(date)});
    try {
      if (kDebugMode) debugPrint('[AnswerPrice] GET $uri');
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 15));
      if (kDebugMode) {
        final body = response.body;
        debugPrint(
          '[AnswerPrice] Response ${response.statusCode}: '
          '${body.length <= 500 ? body : '${body.substring(0, 500)}…'}',
        );
      }
      if (response.statusCode != 200) {
        throw const AnswerPriceException('この日の株価を取得できませんでした');
      }
      return AnswerClose.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    } on AnswerPriceException {
      rethrow;
    } on Object catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[AnswerPrice] Request failed for $uri: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      throw const AnswerPriceException('答え合わせ価格を取得できませんでした。もう一度お試しください。');
    }
  }

  static String _formatDate(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)}';
  }
}
