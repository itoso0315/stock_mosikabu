import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/skip_record.dart';
import '../models/skip_record_draft.dart';

abstract interface class SkipRecordRepository {
  Future<List<SkipRecord>> getAll();
  Future<SkipRecord> save(SkipRecordDraft draft);
  Future<SkipRecord> update(SkipRecord record);
}

class SharedPreferencesSkipRecordRepository implements SkipRecordRepository {
  SharedPreferencesSkipRecordRepository({this.preferences});

  static const _recordsKey = 'skip_records_v1';
  final SharedPreferences? preferences;

  Future<SharedPreferences> get _store async =>
      preferences ?? await SharedPreferences.getInstance();

  @override
  Future<List<SkipRecord>> getAll() async {
    final preferences = await _store;
    final encodedRecords = preferences.getStringList(_recordsKey) ?? [];
    final records = encodedRecords.map((encoded) {
      return SkipRecord.fromJson(jsonDecode(encoded) as Map<String, dynamic>);
    }).toList();
    records.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return records;
  }

  @override
  Future<SkipRecord> save(SkipRecordDraft draft) async {
    final quote = draft.quote;
    if (quote == null) {
      throw const SkipRecordSaveException('株価が取得できていません');
    }
    final record = SkipRecord(
      id: '${draft.recordedAt.microsecondsSinceEpoch}-${draft.stock.code}',
      stockCode: draft.stock.code,
      stockName: draft.stock.name,
      skippedPrice: quote.price,
      recordedAt: draft.recordedAt,
      reason: draft.reason,
      reasonLabel: skipReasonLabel(draft.reason),
      otherNote: draft.otherNote,
      answerCheckSetting: draft.answerCheckSetting,
      answerCheckStatus: AnswerCheckStatus.pending,
      answerPrice: null,
    );

    final preferences = await _store;
    final existing = preferences.getStringList(_recordsKey) ?? [];
    final didSave = await preferences.setStringList(_recordsKey, [
      jsonEncode(record.toJson()),
      ...existing,
    ]);
    if (!didSave) {
      throw const SkipRecordSaveException('端末内へ保存できませんでした');
    }
    return record;
  }

  @override
  Future<SkipRecord> update(SkipRecord record) async {
    final preferences = await _store;
    final encodedRecords = preferences.getStringList(_recordsKey) ?? [];
    var didFindRecord = false;
    final updated = encodedRecords.map((encoded) {
      final existing = SkipRecord.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      if (existing.id != record.id) return encoded;
      didFindRecord = true;
      return jsonEncode(record.toJson());
    }).toList();
    if (!didFindRecord) throw const SkipRecordSaveException('更新対象が見つかりません');
    final didSave = await preferences.setStringList(_recordsKey, updated);
    if (!didSave) throw const SkipRecordSaveException('端末内へ保存できませんでした');
    return record;
  }
}

class SkipRecordSaveException implements Exception {
  const SkipRecordSaveException(this.message);
  final String message;
}
