import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moshi_kabu/models/answer_close.dart';
import 'package:moshi_kabu/models/skip_record.dart';
import 'package:moshi_kabu/models/skip_record_draft.dart';
import 'package:moshi_kabu/models/stock_candidate.dart';
import 'package:moshi_kabu/models/stock_quote.dart';
import 'package:moshi_kabu/screens/answer_waiting_screen.dart';
import 'package:moshi_kabu/screens/record_completion_screen.dart';
import 'package:moshi_kabu/screens/skip_record_screen.dart';
import 'package:moshi_kabu/services/answer_price_service.dart';
import 'package:moshi_kabu/services/stock_price_service.dart';

void main() {
  testWidgets('iPhone SE相当幅で長い銘柄名と大きな価格を答え合わせ一覧に表示できる', (tester) async {
    _useSmallPhone(tester);
    final record = _completedRecord(
      stockName: 'キオクシアホールディングス株式会社とても長い銘柄名',
      skippedPrice: 99999999,
      answerPrice: 123456789,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AnswerWaitingScreen(
          records: [record],
          answerPriceService: const _UnusedAnswerPriceService(),
          onComplete: (record, close) async => record,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('キオクシアホールディングス株式会社とても長い銘柄名'), findsOneWidget);
    expect(find.text('99,999,999円'), findsOneWidget);
    expect(find.text('123,456,789円'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iPhone SE相当幅で見送り理由2列カードと保存ボタンが崩れない', (tester) async {
    _useSmallPhone(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: SkipRecordScreen(
          stock: StockCandidate(code: '285A', name: 'キオクシアホールディングス'),
          stockPriceService: _FixedStockPriceService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('材料・地合いが不安'), findsOneWidget);
    expect(find.text('資金を温存したい'), findsOneWidget);
    expect(find.byKey(const ValueKey('submit-record-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('小画面の記録完了カードで長い銘柄名を最大2行に制限する', (tester) async {
    _useSmallPhone(tester);
    final record = _completedRecord(
      stockName: '非常に長い銘柄名ホールディングスフィナンシャルグループ株式会社',
      skippedPrice: 1000,
      answerPrice: 1100,
    );
    await tester.pumpWidget(
      MaterialApp(home: RecordCompletionScreen(record: record)),
    );
    await tester.pumpAndSettle();

    final name = tester.widget<Text>(find.text(record.stockName));
    expect(name.maxLines, 2);
    expect(name.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });
}

void _useSmallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

SkipRecord _completedRecord({
  required String stockName,
  required double skippedPrice,
  required double answerPrice,
}) => SkipRecord(
  id: 'task-017',
  stockCode: '285A',
  stockName: stockName,
  skippedPrice: skippedPrice,
  recordedAt: DateTime(2026, 8, 11, 10),
  reason: SkipReason.marketConcern,
  reasonLabel: '材料・地合いが不安',
  answerCheckSetting: const AnswerCheckSetting.oneMonth(),
  answerCheckStatus: AnswerCheckStatus.completed,
  answerPrice: answerPrice,
  answerPriceDate: DateTime(2026, 9, 11),
  answerChangePercent: (answerPrice - skippedPrice) / skippedPrice * 100,
  answeredAt: DateTime(2026, 9, 11, 17),
);

class _FixedStockPriceService implements StockPriceService {
  const _FixedStockPriceService();

  @override
  Future<StockQuote> fetchQuote(StockCandidate stock) async => StockQuote(
    code: stock.code,
    name: stock.name,
    price: 48240,
    fetchedAt: DateTime(2026, 8, 11, 10),
  );
}

class _UnusedAnswerPriceService implements AnswerPriceService {
  const _UnusedAnswerPriceService();

  @override
  Future<AnswerClose> fetchClose(String stockCode, DateTime date) =>
      throw StateError('保存済み結果では呼ばれません');
}
