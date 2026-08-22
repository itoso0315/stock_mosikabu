import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moshi_kabu/app.dart';
import 'package:moshi_kabu/models/skip_record.dart';
import 'package:moshi_kabu/models/answer_close.dart';
import 'package:moshi_kabu/models/skip_record_draft.dart';
import 'package:moshi_kabu/models/stock_candidate.dart';
import 'package:moshi_kabu/models/stock_quote.dart';
import 'package:moshi_kabu/repositories/skip_record_repository.dart';
import 'package:moshi_kabu/screens/skip_record_screen.dart';
import 'package:moshi_kabu/services/provisional_answer_ready_service.dart';
import 'package:moshi_kabu/services/stock_price_service.dart';
import 'package:moshi_kabu/services/answer_price_service.dart';

void main() {
  const readyService = ProvisionalAnswerReadyService();

  test('未答え合わせかつ予定日到来済みの記録だけを暫定対象にする', () {
    final records = [
      _record(id: 'ready', recordedAt: DateTime(2026, 8, 1)),
      _record(id: 'future', recordedAt: DateTime(2026, 8, 10)),
      _record(
        id: 'completed',
        recordedAt: DateTime(2026, 8, 1),
        status: AnswerCheckStatus.completed,
      ),
    ];

    final ready = readyService.readyRecords(records, DateTime(2026, 8, 8));

    expect(ready.map((record) => record.id), ['ready']);
  });

  testWidgets('0件でもベルから空の答え合わせ待ち一覧へ遷移して戻れる', (tester) async {
    await tester.pumpWidget(
      MoshiKabuApp(
        repository: _MemoryRepository(const []),
        clock: () => DateTime(2026, 8, 11),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('answer-count-badge')), findsNothing);
    expect(find.text('今日は気になる株あった？'), findsOneWidget);
    await tester.tap(find.byTooltip('通知'));
    await tester.pumpAndSettle();

    expect(find.text('答え合わせ'), findsOneWidget);
    expect(find.text('まだ答え合わせできる記録はありません'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('買わなかった株の答え合わせアプリ'), findsOneWidget);
  });

  testWidgets('到来済み件数を表示し、ベルと吹き出しから同じ一覧へ進める', (tester) async {
    final readyRecord = _record(
      id: 'ready',
      recordedAt: DateTime(2026, 8, 1, 10, 30),
      name: 'テスト株式会社',
    );
    await tester.pumpWidget(
      MoshiKabuApp(
        repository: _MemoryRepository([readyRecord]),
        answerPriceService: const _AnswerPriceService(),
        clock: () => DateTime(2026, 8, 11),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1件、答え合わせできるよ！'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('answer-count-badge')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('通知'));
    await tester.pumpAndSettle();
    expect(find.text('テスト株式会社'), findsOneWidget);
    expect(find.text('0001'), findsOneWidget);
    expect(find.text('1,234円'), findsOneWidget);
    expect(find.text('1,234円'), findsOneWidget);
    expect(find.text('1,300円'), findsOneWidget);
    expect(find.text('+5.3%'), findsOneWidget);
    expect(find.text('高いと思った'), findsOneWidget);
  });

  testWidgets('記録理由と答え合わせ期間を同じ見出し階層で表示する', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SkipRecordScreen(
          stock: StockCandidate(code: '9432', name: 'NTT'),
          stockPriceService: _PriceService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final reasonHeading = tester.widget<Text>(
      find.byKey(const ValueKey('reason-section-heading')),
    );
    final answerHeading = tester.widget<Text>(
      find.byKey(const ValueKey('answer-section-heading')),
    );
    expect(reasonHeading.style, answerHeading.style);
    expect(
      find.byKey(const ValueKey('reason-selection-group')),
      findsOneWidget,
    );
    expect(find.text('高いと思った'), findsOneWidget);
    expect(find.text('まだ下がりそう'), findsOneWidget);
    expect(find.text('材料・地合いが不安'), findsOneWidget);
    expect(find.text('資金を温存したい'), findsOneWidget);
    expect(find.text('その他'), findsOneWidget);
    expect(find.text('いつ答え合わせする？'), findsOneWidget);

    final setting = find.byKey(const ValueKey('answer-check-setting'));
    await tester.ensureVisible(setting);
    await tester.tap(setting);
    await tester.pumpAndSettle();
    expect(find.text('答え合わせ期間'), findsOneWidget);
  });
}

SkipRecord _record({
  required String id,
  required DateTime recordedAt,
  String name = 'テスト銘柄',
  AnswerCheckStatus status = AnswerCheckStatus.pending,
}) => SkipRecord(
  id: id,
  stockCode: '0001',
  stockName: name,
  skippedPrice: 1234,
  recordedAt: recordedAt,
  reason: SkipReason.priceTooHigh,
  reasonLabel: '高いと思った',
  answerCheckSetting: const AnswerCheckSetting(
    period: AnswerCheckPeriod.threeDays,
  ),
  answerCheckStatus: status,
);

class _MemoryRepository implements SkipRecordRepository {
  _MemoryRepository(this.records);

  final List<SkipRecord> records;

  @override
  Future<List<SkipRecord>> getAll() async => records;

  @override
  Future<SkipRecord> save(SkipRecordDraft draft) => throw UnimplementedError();

  @override
  Future<SkipRecord> update(SkipRecord record) async => record;
}

class _PriceService implements StockPriceService {
  const _PriceService();

  @override
  Future<StockQuote> fetchQuote(StockCandidate stock) async => StockQuote(
    code: stock.code,
    name: stock.name,
    price: 1234,
    fetchedAt: DateTime(2026, 8, 11),
  );
}

class _AnswerPriceService implements AnswerPriceService {
  const _AnswerPriceService();

  @override
  Future<AnswerClose> fetchClose(String stockCode, DateTime date) async =>
      AnswerClose(code: stockCode, close: 1300, priceDate: date);
}
