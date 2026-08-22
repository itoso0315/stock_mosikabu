import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moshi_kabu/app.dart';
import 'package:moshi_kabu/models/answer_close.dart';
import 'package:moshi_kabu/models/skip_record.dart';
import 'package:moshi_kabu/models/skip_record_draft.dart';
import 'package:moshi_kabu/repositories/skip_record_repository.dart';
import 'package:moshi_kabu/screens/skip_record_analysis_screen.dart';
import 'package:moshi_kabu/services/answer_price_service.dart';
import 'package:moshi_kabu/services/skip_record_analysis_service.dart';

void main() {
  const service = SkipRecordAnalysisService();

  test('completedかつ結果保存済みの記録だけを正しく集計する', () {
    final analysis = service.analyze([
      _completed('high-up', SkipReason.priceTooHigh, 10),
      _completed('high-down', SkipReason.priceTooHigh, -2),
      _completed('drop', SkipReason.expectingDrop, -4),
      _completed('flat', SkipReason.other, 0),
      _pending('pending', SkipReason.preserveFunds),
      _missingResult('missing', SkipReason.marketConcern),
    ]);

    expect(analysis.totalCount, 4);
    expect(analysis.reasonCounts[SkipReason.priceTooHigh], 2);
    expect(analysis.reasonCounts[SkipReason.preserveFunds], 0);
    expect(analysis.reasonAverageChanges[SkipReason.priceTooHigh], 4);
    expect(analysis.reasonAverageChanges[SkipReason.expectingDrop], -4);
    expect(analysis.reasonAverageChanges[SkipReason.preserveFunds], isNull);
    expect(analysis.averageChange, 1);
    expect(analysis.risingCount, 1);
    expect(analysis.fallingCount, 2);
    expect(analysis.flatCount, 1);
    expect(analysis.mostCommonReasons, [SkipReason.priceTooHigh]);
    expect(analysis.homeInsight, '最近は「高いと思った」で見送ることが多いみたい');
  });

  test('0件と少数データでは断定的なインサイトを返さない', () {
    expect(service.analyze(const []).homeInsight, contains('データがたまると'));
    expect(
      service.analyze([
        _completed('one', SkipReason.priceTooHigh, 3),
        _completed('two', SkipReason.priceTooHigh, 4),
      ]).homeInsight,
      'もう少し答え合わせがたまると、傾向が見えてきます',
    );
  });

  testWidgets('ホームの一言から詳細分析を開き各集計を表示する', (tester) async {
    final repository = _MemoryRepository([
      _completed('high-up', SkipReason.priceTooHigh, 10),
      _completed('high-down', SkipReason.priceTooHigh, -2),
      _completed('drop', SkipReason.expectingDrop, -4),
      _completed('flat', SkipReason.other, 0),
      _pending('pending', SkipReason.preserveFunds),
    ]);
    final priceService = _CountingAnswerPriceService();
    await tester.pumpWidget(
      MoshiKabuApp(
        repository: repository,
        answerPriceService: priceService,
        showDeveloperMenu: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('最近は「高いと思った」で見送ることが多いみたい'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-trend-insight')), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('open-trend-analysis')),
    );
    await tester.tap(find.byKey(const ValueKey('open-trend-analysis')));
    await tester.pumpAndSettle();

    expect(find.text('見送り傾向'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text('いちばん多い見送り理由'), findsOneWidget);
    expect(find.text('高いと思った'), findsNWidgets(2));
    expect(find.text('2件 / 4件  (50%)'), findsOneWidget);
    expect(find.text('理由別の結果'), findsOneWidget);
    expect(find.text('+4.0%'), findsOneWidget);
    expect(find.text('-4.0%'), findsOneWidget);
    expect(find.text('データなし'), findsNWidgets(2));
    await tester.scrollUntilVisible(find.text('見送った株のその後'), 250);
    expect(find.text('上昇'), findsOneWidget);
    expect(find.text('下落'), findsOneWidget);
    expect(find.text('横ばい'), findsOneWidget);
    expect(find.text('25%  1件'), findsNWidgets(2));
    expect(find.text('50%  2件'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('overall-average-change')),
      250,
    );
    final overallAverage = tester.widget<RichText>(
      find.byKey(const ValueKey('overall-average-change')),
    );
    expect(overallAverage.text.toPlainText(), '見送った株は平均 +1.0% でした');
    expect(priceService.calls, 0);

    final positive = tester.widget<Text>(
      find.byKey(const ValueKey('reason-average-priceTooHigh')),
    );
    final negative = tester.widget<Text>(
      find.byKey(const ValueKey('reason-average-expectingDrop')),
    );
    expect(positive.style?.color, const Color(0xFFE15F78));
    expect(negative.style?.color, const Color(0xFF438DCB));

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('買わなかった株の答え合わせアプリ'), findsOneWidget);
  });

  testWidgets('0件の詳細画面と少数データの案内を安全に表示する', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SkipRecordAnalysisScreen(
          analysis: SkipRecordAnalysis(
            totalCount: 0,
            reasonCounts: {},
            reasonAverageChanges: {},
            mostCommonReasons: [],
            averageChange: null,
            risingCount: 0,
            fallingCount: 0,
            flatCount: 0,
          ),
        ),
      ),
    );
    expect(find.text('まだ分析できる記録はありません'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: SkipRecordAnalysisScreen(
          analysis: service.analyze([
            _completed('one', SkipReason.priceTooHigh, 2),
          ]),
        ),
      ),
    );
    expect(find.text('もう少し答え合わせがたまると、傾向が見えてきます'), findsOneWidget);
  });

  testWidgets('新しい答え合わせ完了を再起動なしでホーム分析へ反映する', (tester) async {
    final repository = _MemoryRepository([
      _pending('ready', SkipReason.priceTooHigh),
    ]);
    await tester.pumpWidget(
      MoshiKabuApp(
        repository: repository,
        answerPriceService: _CountingAnswerPriceService(),
        clock: () => DateTime(2026, 10, 20),
        showDeveloperMenu: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('見送りデータがたまると'), findsOneWidget);

    await tester.tap(find.byTooltip('通知'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('もう少し答え合わせがたまると、傾向が見えてきます'), findsOneWidget);
  });
}

SkipRecord _base(String id, SkipReason reason) => SkipRecord(
  id: id,
  stockCode: id,
  stockName: 'テスト$id',
  skippedPrice: 1000,
  recordedAt: DateTime(2026, 8, 1),
  reason: reason,
  reasonLabel: skipReasonLabel(reason),
  answerCheckSetting: const AnswerCheckSetting.oneMonth(),
  answerCheckStatus: AnswerCheckStatus.pending,
);

SkipRecord _pending(String id, SkipReason reason) => _base(id, reason);

SkipRecord _missingResult(String id, SkipReason reason) =>
    _base(id, reason).copyWith(answerCheckStatus: AnswerCheckStatus.completed);

SkipRecord _completed(String id, SkipReason reason, double percent) =>
    _base(id, reason).copyWith(
      answerCheckStatus: AnswerCheckStatus.completed,
      answerPrice: 1000 * (1 + percent / 100),
      answerPriceDate: DateTime(2026, 9, 1),
      answerChangePercent: percent,
      answeredAt: DateTime(2026, 9, 1),
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
