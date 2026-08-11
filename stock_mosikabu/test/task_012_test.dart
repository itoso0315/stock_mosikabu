import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moshi_kabu/app.dart';
import 'package:moshi_kabu/models/answer_close.dart';
import 'package:moshi_kabu/models/skip_record.dart';
import 'package:moshi_kabu/models/skip_record_draft.dart';
import 'package:moshi_kabu/repositories/skip_record_repository.dart';
import 'package:moshi_kabu/screens/review_screen.dart';
import 'package:moshi_kabu/services/answer_price_service.dart';
import 'package:moshi_kabu/widgets/stock_icon.dart';

void main() {
  testWidgets('振り返りタブは完了記録だけを新しい順に表示する', (tester) async {
    final service = _CountingAnswerPriceService();
    final records = [
      _completed(id: 'older', name: '古い完了', percent: 8, answeredDay: 10),
      _pending(id: 'pending', name: '未答え合わせ'),
      _completed(id: 'newer', name: '新しい完了', percent: -5, answeredDay: 12),
      _incompleteCompleted(id: 'missing', name: '結果欠損'),
      _completed(id: 'neutral', name: '横ばい', percent: 0, answeredDay: 11),
    ];
    await tester.pumpWidget(
      MoshiKabuApp(
        repository: _MemoryRepository(records),
        answerPriceService: service,
        showDeveloperMenu: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('振り返り'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('review-list')), findsOneWidget);
    expect(find.byType(StockIcon), findsNWidgets(3));
    expect(
      find.byKey(const ValueKey('review-stock-icon-newer')),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('review-title'))).textAlign,
      TextAlign.center,
    );
    expect(find.text('未答え合わせ'), findsNothing);
    expect(find.text('結果欠損'), findsNothing);
    expect(find.text('1,000円'), findsNWidgets(4));
    expect(find.text('1,080円'), findsOneWidget);
    expect(find.text('+8.0%'), findsOneWidget);
    expect(find.text('-5.0%'), findsOneWidget);
    expect(find.text('+0.0%'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('answer-percent-pill-positive')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('answer-percent-pill-negative')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('answer-percent-pill-neutral')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('新しい完了')).dy,
      lessThan(tester.getTopLeft(find.text('横ばい')).dy),
    );
    expect(
      tester.getTopLeft(find.text('横ばい')).dy,
      lessThan(tester.getTopLeft(find.text('古い完了')).dy),
    );
    expect(service.calls, 0);

    await tester.tap(find.byKey(const ValueKey('review-record-newer')));
    await tester.pumpAndSettle();
    expect(find.text('もし買っていたら -5.0%'), findsOneWidget);
    expect(service.calls, 0);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('review-list')), findsOneWidget);

    await tester.tap(find.text('ホーム'));
    await tester.pumpAndSettle();
    expect(find.text('買わなかった株の答え合わせアプリ'), findsOneWidget);
  });

  testWidgets('完了記録がないとき空状態を表示する', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewScreen(
            records: [_pending(id: 'pending', name: '未答え合わせ')],
            answerPriceService: _CountingAnswerPriceService(),
            onComplete: (record, close) async => record,
          ),
        ),
      ),
    );
    expect(find.text('まだ振り返れる記録はありません'), findsOneWidget);
    expect(find.text('答え合わせが終わると、ここに記録が並びます'), findsOneWidget);
  });

  testWidgets('長い銘柄名でもロゴと騰落率がオーバーフローしない', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final record = _completed(
      id: 'long',
      name: 'とても長い会社名フィナンシャルグループホールディングス株式会社',
      percent: 12.6,
      answeredDay: 12,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewScreen(
            records: [record],
            answerPriceService: _CountingAnswerPriceService(),
            onComplete: (record, close) async => record,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('review-stock-icon-long')),
      findsOneWidget,
    );
    expect(find.text('+12.6%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('答え合わせ完了後は再起動せず振り返りへ反映する', (tester) async {
    final repository = _MemoryRepository([
      _pending(id: 'ready', name: '今回の完了'),
    ]);
    final service = _CountingAnswerPriceService();
    await tester.pumpWidget(
      MoshiKabuApp(
        repository: repository,
        answerPriceService: service,
        clock: () => DateTime(2026, 10, 20),
        showDeveloperMenu: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('通知'));
    await tester.pumpAndSettle();
    expect(
      repository.records.single.answerCheckStatus,
      AnswerCheckStatus.completed,
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('振り返り'));
    await tester.pumpAndSettle();

    expect(find.text('今回の完了'), findsOneWidget);
    expect(find.text('+10.0%'), findsOneWidget);
  });
}

SkipRecord _pending({required String id, required String name}) => SkipRecord(
  id: id,
  stockCode: '1000',
  stockName: name,
  skippedPrice: 1000,
  recordedAt: DateTime(2026, 8, 1),
  reason: SkipReason.priceTooHigh,
  reasonLabel: '高いと思った',
  answerCheckSetting: const AnswerCheckSetting.oneMonth(),
  answerCheckStatus: AnswerCheckStatus.pending,
);

SkipRecord _incompleteCompleted({required String id, required String name}) =>
    _pending(id: id, name: name).copyWith(
      answerCheckStatus: AnswerCheckStatus.completed,
      answerPrice: 1100,
    );

SkipRecord _completed({
  required String id,
  required String name,
  required double percent,
  required int answeredDay,
}) => _pending(id: id, name: name).copyWith(
  answerCheckStatus: AnswerCheckStatus.completed,
  answerPrice: 1000 * (1 + percent / 100),
  answerPriceDate: DateTime(2026, 9, answeredDay),
  answerChangePercent: percent,
  answeredAt: DateTime(2026, 9, answeredDay, 16),
);

class _CountingAnswerPriceService implements AnswerPriceService {
  int calls = 0;

  @override
  Future<AnswerClose> fetchClose(String stockCode, DateTime date) async {
    calls++;
    return AnswerClose(code: stockCode, close: 1100, priceDate: date);
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
    final index = records.indexWhere((item) => item.id == record.id);
    records[index] = record;
    return record;
  }
}
