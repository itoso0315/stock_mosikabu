import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moshi_kabu/models/answer_close.dart';
import 'package:moshi_kabu/models/skip_record.dart';
import 'package:moshi_kabu/models/skip_record_draft.dart';
import 'package:moshi_kabu/screens/review_screen.dart';
import 'package:moshi_kabu/services/answer_price_service.dart';
import 'package:moshi_kabu/services/review_filter_service.dart';

void main() {
  const service = ReviewFilterService();
  final records = [
    _record(
      id: 'mufg',
      code: '8306',
      name: '三菱UFJフィナンシャル・グループ',
      reason: SkipReason.priceTooHigh,
      percent: 7.5,
      answeredDay: 12,
    ),
    _record(
      id: 'ntt',
      code: '9432',
      name: 'NTT',
      reason: SkipReason.expectingDrop,
      percent: -8.7,
      answeredDay: 10,
    ),
    _record(
      id: 'alpha',
      code: '285A',
      name: 'キオクシアHD',
      reason: SkipReason.priceTooHigh,
      percent: 0,
      answeredDay: 11,
    ),
    _pending(),
  ];

  test('銘柄名・コード検索と結果・理由フィルターを適用できる', () {
    expect(_ids(service.apply(records, const ReviewFilter(query: '三菱'))), [
      'mufg',
    ]);
    expect(_ids(service.apply(records, const ReviewFilter(query: '83'))), [
      'mufg',
    ]);
    expect(_ids(service.apply(records, const ReviewFilter(query: 'ntt'))), [
      'ntt',
    ]);
    expect(_ids(service.apply(records, const ReviewFilter(query: '285a'))), [
      'alpha',
    ]);
    expect(
      _ids(
        service.apply(
          records,
          const ReviewFilter(result: ReviewResultFilter.positive),
        ),
      ),
      ['mufg'],
    );
    expect(
      _ids(
        service.apply(
          records,
          const ReviewFilter(result: ReviewResultFilter.negative),
        ),
      ),
      ['ntt'],
    );
    expect(
      _ids(
        service.apply(
          records,
          const ReviewFilter(result: ReviewResultFilter.flat),
        ),
      ),
      ['alpha'],
    );
    expect(
      _ids(
        service.apply(
          records,
          const ReviewFilter(reason: SkipReason.priceTooHigh),
        ),
      ),
      ['mufg', 'alpha'],
    );
  });

  test('4種類の並び順と複合条件を適用できる', () {
    expect(_ids(service.apply(records, const ReviewFilter())), [
      'mufg',
      'alpha',
      'ntt',
    ]);
    expect(
      _ids(
        service.apply(
          records,
          const ReviewFilter(sortOrder: ReviewSortOrder.oldest),
        ),
      ),
      ['ntt', 'alpha', 'mufg'],
    );
    expect(
      _ids(
        service.apply(
          records,
          const ReviewFilter(sortOrder: ReviewSortOrder.highestReturn),
        ),
      ),
      ['mufg', 'alpha', 'ntt'],
    );
    expect(
      _ids(
        service.apply(
          records,
          const ReviewFilter(sortOrder: ReviewSortOrder.lowestReturn),
        ),
      ),
      ['ntt', 'alpha', 'mufg'],
    );
    expect(
      _ids(
        service.apply(
          records,
          const ReviewFilter(
            query: '8',
            result: ReviewResultFilter.positive,
            reason: SkipReason.priceTooHigh,
            sortOrder: ReviewSortOrder.highestReturn,
          ),
        ),
      ),
      ['mufg'],
    );
  });

  testWidgets('検索とフィルターを同時適用し詳細から戻っても保持する', (tester) async {
    await _pumpReview(tester, records);

    await tester.enterText(
      find.byKey(const ValueKey('review-search-field')),
      '三菱',
    );
    await tester.pump();
    expect(find.text('三菱UFJフィナンシャル・グループ'), findsOneWidget);
    expect(find.text('NTT'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('open-review-filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('result-filter-positive')));
    await tester.tap(find.byKey(const ValueKey('reason-filter-priceTooHigh')));
    await tester.tap(find.byKey(const ValueKey('apply-review-filters')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('review-filter-active')), findsOneWidget);
    expect(find.text('三菱UFJフィナンシャル・グループ'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('review-record-mufg')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('review-search-field')))
          .controller
          ?.text,
      '三菱',
    );
    expect(find.byKey(const ValueKey('review-filter-active')), findsOneWidget);
    expect(find.text('NTT'), findsNothing);
  });

  testWidgets('検索クリア・条件0件・リセットを区別して表示する', (tester) async {
    await _pumpReview(tester, records);
    final search = find.byKey(const ValueKey('review-search-field'));
    await tester.enterText(search, '存在しない銘柄');
    await tester.pump();
    expect(find.text('条件に合う振り返りがありません'), findsOneWidget);
    expect(find.text('検索条件やフィルターを変えてみてください'), findsOneWidget);

    await tester.tap(find.text('条件をリセット'));
    await tester.pump();
    expect(find.text('三菱UFJフィナンシャル・グループ'), findsOneWidget);
    expect(tester.widget<TextField>(search).controller?.text, isEmpty);

    await tester.enterText(search, 'NTT');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('clear-review-search')));
    await tester.pump();
    expect(find.text('三菱UFJフィナンシャル・グループ'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('open-review-filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('result-filter-negative')));
    await tester.tap(find.byKey(const ValueKey('apply-review-filters')));
    await tester.pumpAndSettle();
    expect(find.text('NTT'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('open-review-filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reset-review-filters')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('review-filter-active')), findsNothing);
    expect(find.text('三菱UFJフィナンシャル・グループ'), findsOneWidget);
  });

  testWidgets('completed記録0件では通常の空状態を表示する', (tester) async {
    await _pumpReview(tester, [_pending()]);
    expect(find.text('まだ振り返れる記録はありません'), findsOneWidget);
    expect(find.text('条件に合う振り返りがありません'), findsNothing);
  });

  testWidgets('小さい画面のBottomSheetから並び順を変更できる', (tester) async {
    tester.view.physicalSize = const Size(390, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpReview(tester, records);

    await tester.tap(find.byKey(const ValueKey('open-review-filters')));
    await tester.pumpAndSettle();
    await tester.drag(find.text('見送り理由'), const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('review-sort-order')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('古い順').last);
    await tester.pumpAndSettle();
    await tester.drag(find.text('並び順'), const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apply-review-filters')));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('NTT')).dy,
      lessThan(tester.getTopLeft(find.text('キオクシアHD')).dy),
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpReview(WidgetTester tester, List<SkipRecord> records) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ReviewScreen(
          records: records,
          answerPriceService: const _NoFetchAnswerPriceService(),
          onComplete: (record, close) async => record,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<String> _ids(List<SkipRecord> records) =>
    records.map((record) => record.id).toList();

SkipRecord _record({
  required String id,
  required String code,
  required String name,
  required SkipReason reason,
  required double percent,
  required int answeredDay,
}) => SkipRecord(
  id: id,
  stockCode: code,
  stockName: name,
  skippedPrice: 1000,
  recordedAt: DateTime(2026, 8, answeredDay),
  reason: reason,
  reasonLabel: skipReasonLabel(reason),
  answerCheckSetting: const AnswerCheckSetting.oneMonth(),
  answerCheckStatus: AnswerCheckStatus.completed,
  answerPrice: 1000 * (1 + percent / 100),
  answerPriceDate: DateTime(2026, 9, answeredDay),
  answerChangePercent: percent,
  answeredAt: DateTime(2026, 9, answeredDay),
);

SkipRecord _pending() => SkipRecord(
  id: 'pending',
  stockCode: '9999',
  stockName: '未完了',
  skippedPrice: 1000,
  recordedAt: DateTime(2026, 8, 13),
  reason: SkipReason.other,
  reasonLabel: 'その他',
  answerCheckSetting: const AnswerCheckSetting.oneMonth(),
  answerCheckStatus: AnswerCheckStatus.pending,
);

class _NoFetchAnswerPriceService implements AnswerPriceService {
  const _NoFetchAnswerPriceService();

  @override
  Future<AnswerClose> fetchClose(String stockCode, DateTime date) =>
      throw StateError('保存済み結果を再取得してはいけません');
}
