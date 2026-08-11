import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moshi_kabu/app.dart';
import 'package:moshi_kabu/models/skip_record.dart';
import 'package:moshi_kabu/models/skip_record_draft.dart';
import 'package:moshi_kabu/models/stock_candidate.dart';
import 'package:moshi_kabu/models/stock_quote.dart';
import 'package:moshi_kabu/repositories/skip_record_repository.dart';
import 'package:moshi_kabu/screens/skip_record_screen.dart';
import 'package:moshi_kabu/services/external_stock_link_service.dart';
import 'package:moshi_kabu/services/stock_price_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('記録を永続化し、新しいRepositoryから日時降順で復元できる', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesSkipRecordRepository(
      preferences: preferences,
    );
    await repository.save(_draft(DateTime(2026, 8, 10), code: '9432'));
    await repository.save(_draft(DateTime(2026, 8, 11), code: '6758'));

    final restartedRepository = SharedPreferencesSkipRecordRepository(
      preferences: preferences,
    );
    final records = await restartedRepository.getAll();

    expect(records.map((record) => record.stockCode), ['6758', '9432']);
    expect(records.first.answerCheckStatus, AnswerCheckStatus.pending);
    expect(records.first.answerPrice, isNull);
    expect(records.first.reasonLabel, '高いと思った');
  });

  test('nullable値とカスタム日付をJSON文字列経由で安全に復元できる', () {
    final record = SkipRecord(
      id: 'json-round-trip',
      stockCode: '9432',
      stockName: 'NTT',
      skippedPrice: 123.4,
      recordedAt: DateTime.parse('2026-08-11T11:30:00.000'),
      reason: SkipReason.other,
      reasonLabel: 'その他',
      otherNote: null,
      answerCheckSetting: AnswerCheckSetting(
        period: AnswerCheckPeriod.custom,
        customDate: DateTime(2026, 9, 18),
      ),
      answerCheckStatus: AnswerCheckStatus.pending,
      answerPrice: null,
    );

    final restored = SkipRecord.fromJson(
      jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>,
    );

    expect(restored.recordedAt, record.recordedAt);
    expect(restored.reason, SkipReason.other);
    expect(restored.otherNote, isNull);
    expect(restored.answerCheckSetting.period, AnswerCheckPeriod.custom);
    expect(restored.answerCheckSetting.customDate, DateTime(2026, 9, 18));
    expect(restored.answerPrice, isNull);
  });

  testWidgets('保存後に完了画面を表示し、保存時刻と内容を確認できる', (tester) async {
    final savedAt = DateTime(2026, 8, 11, 11, 22);
    SkipRecordDraft? receivedDraft;
    await _pumpRecord(
      tester,
      clock: () => savedAt,
      onSave: (draft) async {
        receivedDraft = draft;
        return _recordFromDraft(draft);
      },
    );

    await tester.tap(find.text('高いと思った'));
    await tester.pump();
    _submitButton(tester).onPressed!.call();
    await tester.pumpAndSettle();

    expect(receivedDraft?.recordedAt, savedAt);
    expect(find.text('記録しました！'), findsOneWidget);
    expect(find.text('NTT'), findsOneWidget);
    expect(find.text('1,234円'), findsOneWidget);
    expect(find.text('高いと思った'), findsOneWidget);
    expect(find.text('1か月後'), findsOneWidget);
    expect(find.text('2026/08/11 11:22'), findsOneWidget);
  });

  testWidgets('保存中は二重保存せず、失敗時も選択内容を保持する', (tester) async {
    final completer = Completer<SkipRecord>();
    var calls = 0;
    await _pumpRecord(
      tester,
      onSave: (draft) {
        calls++;
        return completer.future;
      },
    );
    await tester.tap(find.text('まだ下がりそう'));
    await tester.pump();
    final submit = _submitButton(tester).onPressed!;
    submit();
    submit();
    expect(calls, 1);

    completer.completeError(Exception('save failed'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('save-error-message')), findsOneWidget);
    expect(_submitButton(tester).onPressed, isNotNull);
    expect(
      tester
          .widget<Material>(find.byKey(const ValueKey('reason-expectingDrop')))
          .color,
      const Color(0xFFE5F5EB),
    );
  });

  testWidgets('Yahoo Financeリンクを銘柄コードで開き、失敗を通知できる', (tester) async {
    final linkService = _FakeLinkService(openResult: false);
    await _pumpRecord(tester, externalLinkService: linkService);

    await tester.tap(find.byKey(const ValueKey('yahoo-finance-link')));
    await tester.pump();

    expect(linkService.openedCode, '9432');
    expect(
      linkService.yahooFinanceUri('9432').toString(),
      'https://finance.yahoo.co.jp/quote/9432.T',
    );
    expect(find.text('リンクを開けませんでした'), findsOneWidget);
  });

  testWidgets('ホームには保存済み記録を新しい順で最大3件表示する', (tester) async {
    final records = [
      _record('1', '一番古い', DateTime(2026, 8, 8)),
      _record('2', '二番目', DateTime(2026, 8, 9)),
      _record('3', '三番目', DateTime(2026, 8, 10)),
      _record('4', '一番新しい', DateTime(2026, 8, 11)),
    ];
    await tester.pumpWidget(
      MoshiKabuApp(repository: _MemoryRepository(records)),
    );
    await tester.pumpAndSettle();

    expect(find.text('一番新しい'), findsOneWidget);
    expect(find.text('三番目'), findsOneWidget);
    expect(find.text('二番目'), findsOneWidget);
    expect(find.text('一番古い'), findsNothing);
    expect(find.byKey(const ValueKey('answer-count-badge')), findsNothing);
  });
}

Future<void> _pumpRecord(
  WidgetTester tester, {
  Future<SkipRecord> Function(SkipRecordDraft)? onSave,
  DateTime Function()? clock,
  ExternalStockLinkService externalLinkService = const _FakeLinkService(),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SkipRecordScreen(
        stock: const StockCandidate(code: '9432', name: 'NTT'),
        stockPriceService: const _PriceService(),
        onSave: onSave,
        clock: clock,
        externalLinkService: externalLinkService,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

SkipRecordDraft _draft(DateTime date, {required String code}) {
  final stock = StockCandidate(code: code, name: '銘柄$code');
  return SkipRecordDraft(
    stock: stock,
    quote: StockQuote(
      code: code,
      name: stock.name,
      price: 1234,
      fetchedAt: date,
    ),
    recordedAt: date,
    reason: SkipReason.priceTooHigh,
    answerCheckSetting: const AnswerCheckSetting.oneMonth(),
  );
}

SkipRecord _recordFromDraft(SkipRecordDraft draft) => SkipRecord(
  id: 'saved-id',
  stockCode: draft.stock.code,
  stockName: draft.stock.name,
  skippedPrice: draft.quote!.price,
  recordedAt: draft.recordedAt,
  reason: draft.reason,
  reasonLabel: skipReasonLabel(draft.reason),
  answerCheckSetting: draft.answerCheckSetting,
  answerCheckStatus: AnswerCheckStatus.pending,
);

SkipRecord _record(String id, String name, DateTime date) => SkipRecord(
  id: id,
  stockCode: id.padLeft(4, '0'),
  stockName: name,
  skippedPrice: 1000,
  recordedAt: date,
  reason: SkipReason.preserveFunds,
  reasonLabel: '資金を温存したい',
  answerCheckSetting: const AnswerCheckSetting.oneMonth(),
  answerCheckStatus: AnswerCheckStatus.pending,
);

FilledButton _submitButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.byKey(const ValueKey('submit-record-button')),
);

class _PriceService implements StockPriceService {
  const _PriceService();

  @override
  Future<StockQuote> fetchQuote(StockCandidate stock) async => StockQuote(
    code: stock.code,
    name: stock.name,
    price: 1234,
    fetchedAt: DateTime(2026, 8, 11, 9, 42),
  );
}

class _FakeLinkService implements ExternalStockLinkService {
  const _FakeLinkService({this.openResult = true});

  final bool openResult;
  static String? lastOpenedCode;
  String? get openedCode => lastOpenedCode;

  @override
  Future<bool> openYahooFinance(String stockCode) async {
    lastOpenedCode = stockCode;
    return openResult;
  }

  @override
  Uri yahooFinanceUri(String stockCode) =>
      Uri.parse('https://finance.yahoo.co.jp/quote/$stockCode.T');
}

class _MemoryRepository implements SkipRecordRepository {
  _MemoryRepository(this.records);

  final List<SkipRecord> records;

  @override
  Future<List<SkipRecord>> getAll() async =>
      [...records]..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

  @override
  Future<SkipRecord> save(SkipRecordDraft draft) async {
    final record = _recordFromDraft(draft);
    records.add(record);
    return record;
  }

  @override
  Future<SkipRecord> update(SkipRecord record) async {
    final index = records.indexWhere((item) => item.id == record.id);
    if (index >= 0) records[index] = record;
    return record;
  }
}
