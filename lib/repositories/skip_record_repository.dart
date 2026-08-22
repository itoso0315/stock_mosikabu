import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/skip_record.dart';
import '../models/skip_record_draft.dart';
import '../services/provisional_answer_ready_service.dart';

abstract interface class SkipRecordRepository {
  Future<List<SkipRecord>> getAll();
  Future<SkipRecord> save(SkipRecordDraft draft);
  Future<SkipRecord> update(SkipRecord record);
}

abstract interface class MutableSkipRecordRepository {
  Future<void> delete(String id);
  Future<void> clear();
}

class SharedPreferencesSkipRecordRepository
    implements SkipRecordRepository, MutableSkipRecordRepository {
  SharedPreferencesSkipRecordRepository({
    this.preferences,
    this.answerReadyService = const ProvisionalAnswerReadyService(),
  });

  static const _recordsKey = 'skip_records_v1';
  final SharedPreferences? preferences;
  final ProvisionalAnswerReadyService answerReadyService;

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
    try {
      final baseRecord = SkipRecord(
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
      final requestedDate = answerReadyService.requestedAnswerDate(baseRecord);
      final record = baseRecord.copyWith(
        requestedAnswerDate: requestedDate,
        effectiveAnswerDate: answerReadyService.marketCalendar
            .effectiveAnswerDate(requestedDate),
      );
      final encodedRecord = jsonEncode(record.toJson());
      final preferences = await _store;
      final existing = preferences.getStringList(_recordsKey) ?? [];
      final didSave = await preferences.setStringList(_recordsKey, [
        encodedRecord,
        ...existing,
      ]);
      if (!didSave) {
        throw const SkipRecordSaveException('端末内へ保存できませんでした');
      }
      if (kDebugMode) {
        debugPrint('[SkipRecord] Saved ${record.id}: $encodedRecord');
      }
      return record;
    } on SkipRecordSaveException {
      rethrow;
    } on Object catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[SkipRecord] Save failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      throw SkipRecordSaveException(
        '端末内へ保存できませんでした',
        cause: error,
        stackTrace: stackTrace,
      );
    }
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

  @override
  Future<void> delete(String id) async {
    final preferences = await _store;
    final existing = preferences.getStringList(_recordsKey) ?? [];
    final remaining = existing.where((encoded) {
      final record = SkipRecord.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      return record.id != id;
    }).toList();
    if (remaining.length == existing.length) {
      throw const SkipRecordSaveException('削除対象が見つかりません');
    }
    final didSave = await preferences.setStringList(_recordsKey, remaining);
    if (!didSave) throw const SkipRecordSaveException('端末内から削除できませんでした');
  }

  @override
  Future<void> clear() async {
    final didClear = await (await _store).remove(_recordsKey);
    if (!didClear && (await _store).containsKey(_recordsKey)) {
      throw const SkipRecordSaveException('端末内から削除できませんでした');
    }
  }
}

class SkipRecordSaveException implements Exception {
  const SkipRecordSaveException(this.message, {this.cause, this.stackTrace});
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => cause == null
      ? 'SkipRecordSaveException: $message'
      : 'SkipRecordSaveException: $message (cause: $cause)';
}
