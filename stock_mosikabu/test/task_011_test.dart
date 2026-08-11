import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moshi_kabu/app.dart';
import 'package:moshi_kabu/models/answer_close.dart';
import 'package:moshi_kabu/models/skip_record.dart';
import 'package:moshi_kabu/models/skip_record_draft.dart';
import 'package:moshi_kabu/repositories/skip_record_repository.dart';
import 'package:moshi_kabu/screens/answer_result_screen.dart';
import 'package:moshi_kabu/services/answer_price_service.dart';
import 'package:moshi_kabu/models/stock_candidate.dart';
import 'package:moshi_kabu/models/stock_quote.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('指定日終値APIのレスポンスを復元できる', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/stocks/8306/close');
      expect(request.url.queryParameters['date'], '2026-09-11');
      return http.Response(
        jsonEncode({
          'code': '8306',
          'date': '2026-09-11',
          'close': 3780.0,
          'priceDate': '2026-09-11',
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final result = await HttpAnswerPriceService(
      client: client,
      baseUrl: 'http://example.test',
    ).fetchClose('8306', DateTime(2026, 9, 11));
    expect(result.close, 3780);
    expect(result.priceDate, DateTime(2026, 9, 11));
  });

  test('古い保存データは結果フィールドなしでも読み込める', () {
    final record = SkipRecord.fromJson({
      'id': 'old',
      'stockCode': '8306',
      'stockName': '三菱UFJ',
      'skippedPrice': 3515,
      'recordedAt': '2026-08-11T10:00:00.000',
      'reason': 'priceTooHigh',
      'reasonLabel': '高いと思った',
      'otherNote': null,
      'answerPeriod': 'oneMonth',
      'customAnswerDate': null,
      'answerCheckStatus': 'pending',
      'answerPrice': null,
    });
    expect(record.answerPriceDate, isNull);
    expect(record.answerChangePercent, isNull);
    expect(record.answeredAt, isNull);
  });

  test('答え合わせ結果を端末保存し再起動後に復元できる', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesSkipRecordRepository(
      preferences: preferences,
    );
    final saved = await repository.save(
      SkipRecordDraft(
        stock: const StockCandidate(code: '8306', name: '三菱UFJ'),
        quote: StockQuote(
          code: '8306',
          name: '三菱UFJ',
          price: 3515,
          fetchedAt: DateTime(2026, 8, 11),
        ),
        recordedAt: DateTime(2026, 8, 11),
        reason: SkipReason.priceTooHigh,
        answerCheckSetting: const AnswerCheckSetting.oneMonth(),
      ),
    );
    final completed = saved.copyWith(
      answerCheckStatus: AnswerCheckStatus.completed,
      answerPrice: 3780,
      answerPriceDate: DateTime(2026, 9, 11),
      answerChangePercent: 7.539118,
      answeredAt: DateTime(2026, 9, 12),
    );
    await repository.update(completed);

    final restored = (await SharedPreferencesSkipRecordRepository(
      preferences: preferences,
    ).getAll()).single;
    expect(restored.answerCheckStatus, AnswerCheckStatus.completed);
    expect(restored.answerPrice, 3780);
    expect(restored.answerPriceDate, DateTime(2026, 9, 11));
    expect(restored.answerChangePercent, closeTo(7.539118, 0.000001));
    expect(restored.answeredAt, DateTime(2026, 9, 12));
  });

  testWidgets('結果画面でプラス騰落率と保存情報を表示する', (tester) async {
    final record = _record(skippedPrice: 3515);
    await tester.pumpWidget(
      MaterialApp(
        home: AnswerResultScreen(
          record: record,
          answerDate: DateTime(2026, 9, 11),
          answerPriceService: const _FixedAnswerPriceService(3780),
          onComplete: (record, close) async => _complete(record, close),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('もし買っていたら +7.5%'), findsOneWidget);
    expect(find.text('3,515円'), findsOneWidget);
    expect(find.text('3,780円'), findsOneWidget);
    expect(find.text('高いと思った'), findsOneWidget);
    expect(find.text('1か月後'), findsOneWidget);
    expect(find.text('2026/09/11'), findsOneWidget);
    expect(find.textContaining('正解'), findsNothing);
    expect(find.textContaining('不正解'), findsNothing);
    final percent = tester.widget<Text>(
      find.byKey(const ValueKey('answer-result-percent')),
    );
    expect(percent.style?.color, const Color(0xFFE15F78));
  });

  testWidgets('マイナス結果を青で表示する', (tester) async {
    final record = _record(skippedPrice: 1000);
    await tester.pumpWidget(
      MaterialApp(
        home: AnswerResultScreen(
          record: record,
          answerDate: DateTime(2026, 9, 11),
          answerPriceService: const _FixedAnswerPriceService(913),
          onComplete: (record, close) async => _complete(record, close),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('もし買っていたら -8.7%'), findsOneWidget);
    final percent = tester.widget<Text>(
      find.byKey(const ValueKey('answer-result-percent')),
    );
    expect(percent.style?.color, const Color(0xFF438DCB));
  });

  testWidgets('取得失敗時は完了せず再試行できる', (tester) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AnswerResultScreen(
          record: _record(),
          answerDate: DateTime(2026, 9, 11),
          answerPriceService: const _FailingAnswerPriceService(),
          onComplete: (record, close) async {
            completed = true;
            return record;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('この日の株価を取得できませんでした'), findsOneWidget);
    expect(find.byKey(const ValueKey('retry-answer-price')), findsOneWidget);
    expect(completed, isFalse);
  });

  testWidgets('待ちカードの結果確認後にバッジと吹き出しを消化する', (tester) async {
    final repository = _MemoryRepository([_record()]);
    await tester.pumpWidget(
      MoshiKabuApp(
        repository: repository,
        answerPriceService: const _FixedAnswerPriceService(1500),
        clock: () => DateTime(2026, 9, 12, 12),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1件、答え合わせできるよ！'), findsOneWidget);

    await tester.tap(find.byTooltip('通知'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('answer-waiting-record-record')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('もし買っていたら +'), findsOneWidget);
    expect(
      repository.records.single.answerCheckStatus,
      AnswerCheckStatus.completed,
    );

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('まだ答え合わせできる記録はありません'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('answer-count-badge')), findsNothing);
    expect(find.text('今日は気になる株あった？'), findsOneWidget);

    await tester.pumpWidget(
      MoshiKabuApp(
        repository: repository,
        answerPriceService: const _FixedAnswerPriceService(9999),
        clock: () => DateTime(2026, 9, 13),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('answer-count-badge')), findsNothing);
  });
}

SkipRecord _record({double skippedPrice = 1234}) => SkipRecord(
  id: 'record',
  stockCode: '8306',
  stockName: '三菱UFJフィナンシャル・グループ',
  skippedPrice: skippedPrice,
  recordedAt: DateTime(2026, 8, 11, 10),
  reason: SkipReason.priceTooHigh,
  reasonLabel: '高いと思った',
  answerCheckSetting: const AnswerCheckSetting.oneMonth(),
  answerCheckStatus: AnswerCheckStatus.pending,
);

SkipRecord _complete(SkipRecord record, AnswerClose close) {
  final percent =
      (close.close - record.skippedPrice) / record.skippedPrice * 100;
  return record.copyWith(
    answerCheckStatus: AnswerCheckStatus.completed,
    answerPrice: close.close,
    answerPriceDate: close.priceDate,
    answerChangePercent: percent,
    answeredAt: DateTime(2026, 9, 12),
  );
}

class _FixedAnswerPriceService implements AnswerPriceService {
  const _FixedAnswerPriceService(this.price);
  final double price;

  @override
  Future<AnswerClose> fetchClose(String stockCode, DateTime date) async =>
      AnswerClose(code: stockCode, close: price, priceDate: date);
}

class _FailingAnswerPriceService implements AnswerPriceService {
  const _FailingAnswerPriceService();

  @override
  Future<AnswerClose> fetchClose(String stockCode, DateTime date) async {
    throw const AnswerPriceException('この日の株価を取得できませんでした');
  }
}

class _MemoryRepository implements SkipRecordRepository {
  _MemoryRepository(this.records);
  final List<SkipRecord> records;

  @override
  Future<List<SkipRecord>> getAll() async => [...records];

  @override
  Future<SkipRecord> save(SkipRecordDraft draft) => throw UnimplementedError();

  @override
  Future<SkipRecord> update(SkipRecord record) async {
    records[records.indexWhere((item) => item.id == record.id)] = record;
    return record;
  }
}
