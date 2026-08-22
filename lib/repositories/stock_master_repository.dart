import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/stock_candidate.dart';

abstract interface class StockMasterRepository {
  Future<List<StockCandidate>> load();
}

class AssetStockMasterRepository implements StockMasterRepository {
  const AssetStockMasterRepository({this.assetPath = _defaultAssetPath});

  static const _defaultAssetPath = 'assets/stock_master_jpx.json';
  final String assetPath;

  @override
  Future<List<StockCandidate>> load() async {
    final data = await rootBundle.load(assetPath);
    final source = utf8.decode(data.buffer.asUint8List());
    final rows = jsonDecode(source) as List<dynamic>;
    return rows
        .map((row) {
          final values = row as Map<String, dynamic>;
          return StockCandidate(
            code: values['code'] as String,
            name: _normalizeDisplayText(values['name'] as String),
          );
        })
        .toList(growable: false);
  }

  static String _normalizeDisplayText(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      if (rune == 0x3000) {
        buffer.write(' ');
      } else if (rune >= 0xFF01 && rune <= 0xFF5E) {
        buffer.writeCharCode(rune - 0xFEE0);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }
}
