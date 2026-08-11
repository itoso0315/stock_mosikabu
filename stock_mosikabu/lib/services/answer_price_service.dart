import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
      _baseUrl = baseUrl ?? _defaultBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  static String get _defaultBaseUrl {
    const configuredUrl = String.fromEnvironment('API_BASE_URL');
    if (configuredUrl.isNotEmpty) return configuredUrl;
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8000'
        : 'http://127.0.0.1:8000';
  }

  @override
  Future<AnswerClose> fetchClose(String stockCode, DateTime date) async {
    final uri = Uri.parse(
      '$_baseUrl/api/stocks/$stockCode/close',
    ).replace(queryParameters: {'date': _formatDate(date)});
    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw const AnswerPriceException('この日の株価を取得できませんでした');
      }
      return AnswerClose.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    } on AnswerPriceException {
      rethrow;
    } on Object {
      throw const AnswerPriceException('答え合わせ価格を取得できませんでした。もう一度お試しください。');
    }
  }

  static String _formatDate(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)}';
  }
}
