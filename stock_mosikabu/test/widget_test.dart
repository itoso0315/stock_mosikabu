import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moshi_kabu/app.dart';
import 'package:moshi_kabu/models/home_view_data.dart';
import 'package:moshi_kabu/models/skip_record_draft.dart';
import 'package:moshi_kabu/models/stock_candidate.dart';
import 'package:moshi_kabu/models/stock_quote.dart';
import 'package:moshi_kabu/screens/home_screen.dart';
import 'package:moshi_kabu/screens/skip_record_screen.dart';
import 'package:moshi_kabu/screens/stock_search_screen.dart';
import 'package:moshi_kabu/services/stock_price_service.dart';
import 'package:moshi_kabu/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets('共通テーマで画面タイトルを太めのゴシック調にする', (tester) async {
    await tester.pumpWidget(const MoshiKabuApp());

    final theme = Theme.of(tester.element(find.text('もし株')));
    expect(theme.appBarTheme.titleTextStyle?.fontWeight, FontWeight.w600);
    expect(
      theme.appBarTheme.titleTextStyle?.fontFamilyFallback,
      contains('Hiragino Sans'),
    );
    expect(theme.textTheme.titleMedium?.fontWeight, FontWeight.w700);
  });

  testWidgets('保存データがないホーム画面が表示される', (tester) async {
    await tester.pumpWidget(const MoshiKabuApp());
    await tester.pumpAndSettle();

    expect(find.text('もし株'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-title-paw')), findsOneWidget);
    expect(find.text('買わなかった株の答え合わせアプリ'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(find.byKey(const ValueKey('answer-count-badge')), findsNothing);
    expect(find.text('今日は気になる株あった？'), findsOneWidget);
    expect(find.text('答え合わせ待ち'), findsNothing);
    expect(find.text('記録したもし株がここに表示されます'), findsOneWidget);
    expect(find.bySemanticsLabel('猫キャラクター'), findsOneWidget);
    expect(find.text('あなたの見送り傾向'), findsOneWidget);
    expect(find.text('ホーム'), findsOneWidget);
    expect(find.text('振り返り'), findsOneWidget);
    expect(find.text('設定'), findsOneWidget);
  });

  testWidgets('空状態と通常の吹き出しが表示される', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(data: HomeViewData())),
    );

    expect(find.text('今日は気になる株あった？'), findsOneWidget);
    expect(find.text('記録したもし株がここに表示されます'), findsOneWidget);
    expect(find.byKey(const ValueKey('answer-count-badge')), findsNothing);
    expect(find.text('答え合わせ待ち'), findsNothing);
  });

  testWidgets('答え合わせあり時はベルと吹き出しが導線になる', (tester) async {
    var tapCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          data: HomeViewData.demo,
          onAnswersTap: () => tapCount++,
        ),
      ),
    );

    await tester.tap(find.byTooltip('通知'));
    await tester.tap(find.text('3件、答え合わせできるよ！'));

    expect(tapCount, 2);
  });

  testWidgets('ホームから検索画面へ遷移して戻れる', (tester) async {
    await tester.pumpWidget(const MoshiKabuApp());

    await tester.tap(find.text('もし株を記録する'));
    await tester.pumpAndSettle();
    expect(find.text('迷った株を記録'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('買わなかった株の答え合わせアプリ'), findsOneWidget);
  });

  testWidgets('銘柄名で検索結果を絞り込める', (tester) async {
    await _openSearch(tester);

    await tester.enterText(find.byType(TextField), 'ソニー');
    await tester.pump();

    expect(find.text('ソニーグループ'), findsOneWidget);
    expect(find.text('NTT'), findsNothing);
  });

  testWidgets('銘柄コードで検索結果を絞り込める', (tester) async {
    await _openSearch(tester);

    await tester.enterText(find.byType(TextField), '8306');
    await tester.pump();

    expect(find.text('三菱UFJフィナンシャル・グループ'), findsOneWidget);
    expect(find.text('オリエンタルランド'), findsNothing);
  });

  testWidgets('銘柄選択後にローディングと株価を表示できる', (tester) async {
    final service = _CompletingStockPriceService();
    await tester.pumpWidget(
      MaterialApp(home: StockSearchScreen(stockPriceService: service)),
    );
    await tester.enterText(find.byType(TextField), '9432');
    await tester.pump();

    await tester.tap(find.text('NTT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('株価を取得中…'), findsOneWidget);

    service.complete(
      StockQuote(
        code: '9432',
        name: 'NTT',
        price: 1234,
        fetchedAt: DateTime(2026, 8, 11, 9, 42),
      ),
    );
    await tester.pump();
    expect(find.text('1,234円'), findsOneWidget);
    expect(find.textContaining('2026/08/11 09:42'), findsOneWidget);
  });

  testWidgets('株価取得失敗時にエラーを表示できる', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StockSearchScreen(stockPriceService: _FailingStockPriceService()),
      ),
    );
    await tester.enterText(find.byType(TextField), '6758');
    await tester.pump();

    await tester.tap(find.text('ソニーグループ'));
    await tester.pumpAndSettle();
    expect(find.text('テスト用エラー'), findsOneWidget);
  });

  testWidgets('検索結果から見送り記録画面へ遷移できる', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StockSearchScreen(
          stockPriceService: _SuccessfulStockPriceService(),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '9432');
    await tester.pump();

    await tester.tap(find.text('NTT'));
    await tester.pumpAndSettle();

    expect(find.text('迷った株を記録'), findsOneWidget);
    expect(find.text('9432'), findsOneWidget);
    expect(find.text('NTT'), findsOneWidget);
    expect(find.text('1,234円'), findsOneWidget);
    expect(find.text('なぜ見送った？'), findsOneWidget);
    expect(find.text('高いと思った'), findsOneWidget);
    expect(find.text('まだ下がりそう'), findsOneWidget);
    expect(find.text('材料・地合いが不安'), findsOneWidget);
    expect(find.text('自分側の事情'), findsNothing);
    expect(find.text('資金を温存したい'), findsOneWidget);
    expect(find.text('その他'), findsOneWidget);
    expect(_reasonIcon(tester, 'priceTooHigh').color, const Color(0xFFE85D7B));
    expect(_reasonIcon(tester, 'expectingDrop').color, const Color(0xFF438DCB));
    expect(_reasonIcon(tester, 'marketConcern').color, const Color(0xFFE58B47));
    expect(_reasonIcon(tester, 'preserveFunds').color, const Color(0xFF4F7FB5));
    expect(
      find.byKey(const ValueKey('reason-secondary-icon-marketConcern')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('銘柄名・銘柄コードで検索'), findsOneWidget);
  });

  testWidgets('理由の単一選択と記録ボタンの有効化が連動する', (tester) async {
    SkipRecordDraft? submittedDraft;
    await tester.pumpWidget(
      MaterialApp(
        home: SkipRecordScreen(
          stock: const StockCandidate(code: '9432', name: 'NTT'),
          stockPriceService: const _SuccessfulStockPriceService(),
          recordedAt: DateTime(2026, 8, 11, 10, 25),
          onSubmit: (draft) => submittedDraft = draft,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('記録日時'), findsNothing);
    expect(find.text('1か月後'), findsOneWidget);
    expect(_submitButton(tester).onPressed, isNull);

    await tester.tap(find.text('高いと思った'));
    await tester.pump();
    expect(
      _reasonMaterial(tester, 'priceTooHigh').color,
      const Color(0xFFE5F5EB),
    );
    expect(_submitButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('まだ下がりそう'));
    await tester.pump();
    expect(_reasonMaterial(tester, 'priceTooHigh').color, AppColors.surface);
    expect(
      _reasonMaterial(tester, 'expectingDrop').color,
      const Color(0xFFE5F5EB),
    );

    await _openPeriodSheet(tester);
    await tester.tap(find.byKey(const ValueKey('period-threeDays')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('submit-record-button')));
    expect(submittedDraft?.reason, SkipReason.expectingDrop);
    expect(submittedDraft?.recordedAt, DateTime(2026, 8, 11, 10, 25));
    expect(
      submittedDraft?.answerCheckSetting.period,
      AnswerCheckPeriod.threeDays,
    );
  });

  testWidgets('その他選択時だけ自由記述欄を表示する', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SkipRecordScreen(
          stock: const StockCandidate(code: '9432', name: 'NTT'),
          stockPriceService: const _SuccessfulStockPriceService(),
          recordedAt: DateTime(2026, 8, 11, 10, 25),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('other-reason-field')), findsNothing);
    await tester.ensureVisible(find.text('その他'));
    await tester.tap(find.text('その他'));
    await tester.pump();
    expect(find.byKey(const ValueKey('other-reason-field')), findsOneWidget);

    await tester.tap(find.text('資金を温存したい'));
    await tester.pump();
    expect(find.byKey(const ValueKey('other-reason-field')), findsNothing);
  });

  testWidgets('答え合わせ期間の初期値と各プリセットを反映できる', (tester) async {
    await _pumpRecordScreen(tester);

    expect(find.text('1か月後'), findsOneWidget);
    await _openPeriodSheet(tester);
    expect(find.text('3日後'), findsOneWidget);
    expect(find.text('1週間後'), findsOneWidget);
    expect(find.text('3か月後'), findsOneWidget);
    expect(find.text('カスタム'), findsOneWidget);

    await _selectPeriod(tester, 'oneWeek');
    expect(find.text('1週間後'), findsOneWidget);

    await _openPeriodSheet(tester);
    await _selectPeriod(tester, 'threeMonths');
    expect(find.text('3か月後'), findsOneWidget);

    await _openPeriodSheet(tester);
    await _selectPeriod(tester, 'oneMonth');
    expect(find.text('1か月後'), findsOneWidget);

    await _openPeriodSheet(tester);
    await _selectPeriod(tester, 'threeDays');
    expect(find.text('3日後'), findsOneWidget);
  });

  testWidgets('カスタムは翌日以降を選択してドラフトへ保持できる', (tester) async {
    SkipRecordDraft? submittedDraft;
    await _pumpRecordScreen(
      tester,
      onSubmit: (draft) => submittedDraft = draft,
    );
    await tester.tap(find.text('高いと思った'));
    await _openPeriodSheet(tester);
    final custom = find.byKey(const ValueKey('period-custom'));
    await tester.ensureVisible(custom);
    await tester.tap(custom);
    await tester.pumpAndSettle();

    final picker = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    expect(picker.firstDate, DateTime(2026, 8, 12));
    picker.onDateChanged(DateTime(2026, 9, 18));
    await tester.pump();
    await tester.tap(find.text('決定'));
    await tester.pumpAndSettle();

    expect(find.text('2026/09/18'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('submit-record-button')));
    expect(submittedDraft?.answerCheckSetting.period, AnswerCheckPeriod.custom);
    expect(
      submittedDraft?.answerCheckSetting.customDate,
      DateTime(2026, 9, 18),
    );
  });
}

Future<void> _openSearch(WidgetTester tester) async {
  await tester.pumpWidget(const MoshiKabuApp());
  await tester.tap(find.text('もし株を記録する'));
  await tester.pumpAndSettle();
}

class _CompletingStockPriceService implements StockPriceService {
  final _completer = Completer<StockQuote>();

  @override
  Future<StockQuote> fetchQuote(StockCandidate stock) => _completer.future;

  void complete(StockQuote quote) => _completer.complete(quote);
}

class _FailingStockPriceService implements StockPriceService {
  const _FailingStockPriceService();

  @override
  Future<StockQuote> fetchQuote(StockCandidate stock) async {
    throw const StockPriceException('テスト用エラー');
  }
}

class _SuccessfulStockPriceService implements StockPriceService {
  const _SuccessfulStockPriceService();

  @override
  Future<StockQuote> fetchQuote(StockCandidate stock) async {
    return StockQuote(
      code: stock.code,
      name: stock.name,
      price: 1234,
      fetchedAt: DateTime(2026, 8, 11, 9, 42),
    );
  }
}

FilledButton _submitButton(WidgetTester tester) {
  return tester.widget<FilledButton>(
    find.byKey(const ValueKey('submit-record-button')),
  );
}

Material _reasonMaterial(WidgetTester tester, String reasonName) {
  return tester.widget<Material>(find.byKey(ValueKey('reason-$reasonName')));
}

Icon _reasonIcon(WidgetTester tester, String reasonName) {
  return tester.widget<Icon>(find.byKey(ValueKey('reason-icon-$reasonName')));
}

Future<void> _pumpRecordScreen(
  WidgetTester tester, {
  ValueChanged<SkipRecordDraft>? onSubmit,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: SkipRecordScreen(
        stock: const StockCandidate(code: '9432', name: 'NTT'),
        stockPriceService: const _SuccessfulStockPriceService(),
        recordedAt: DateTime(2026, 8, 11, 10, 25),
        onSubmit: onSubmit,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openPeriodSheet(WidgetTester tester) async {
  final card = find.byKey(const ValueKey('answer-check-setting'));
  await tester.ensureVisible(card);
  await tester.tap(card);
  await tester.pumpAndSettle();
}

Future<void> _selectPeriod(WidgetTester tester, String periodName) async {
  final option = find.byKey(ValueKey('period-$periodName'));
  await tester.ensureVisible(option);
  await tester.tap(option);
  await tester.pumpAndSettle();
}
