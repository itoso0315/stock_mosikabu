import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moshi_kabu/app.dart';
import 'package:moshi_kabu/models/answer_close.dart';
import 'package:moshi_kabu/models/skip_record.dart';
import 'package:moshi_kabu/models/skip_record_draft.dart';
import 'package:moshi_kabu/models/stock_candidate.dart';
import 'package:moshi_kabu/models/stock_quote.dart';
import 'package:moshi_kabu/repositories/developer_answer_override_repository.dart';
import 'package:moshi_kabu/repositories/skip_record_repository.dart';
import 'package:moshi_kabu/screens/settings_screen.dart';
import 'package:moshi_kabu/services/answer_notification_service.dart';
import 'package:moshi_kabu/services/answer_price_service.dart';
import 'package:moshi_kabu/services/market_calendar_service.dart';
import 'package:moshi_kabu/services/provisional_answer_ready_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const calendar = MarketCalendarService();

  test('平日・土日・祝日・年末年始を次の取引日へ補正する', () {
    expect(
      calendar.effectiveAnswerDate(DateTime(2026, 8, 11)),
      DateTime(2026, 8, 12),
    );
    expect(
      calendar.effectiveAnswerDate(DateTime(2026, 8, 15)),
      DateTime(2026, 8, 17),
    );
    expect(
      calendar.effectiveAnswerDate(DateTime(2026, 8, 16)),
      DateTime(2026, 8, 17),
    );
    expect(
      calendar.effectiveAnswerDate(DateTime(2026, 2, 11)),
      DateTime(2026, 2, 12),
    );
    expect(
      calendar.effectiveAnswerDate(DateTime(2026, 12, 31)),
      DateTime(2027, 1, 4),
    );
    expect(
      calendar.effectiveAnswerDate(DateTime(2026, 8, 10)),
      DateTime(2026, 8, 10),
    );
  });

  test('保存時にrequestedAnswerDateを維持してeffectiveAnswerDateを保存する', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SharedPreferencesSkipRecordRepository(
      preferences: await SharedPreferences.getInstance(),
    );
    final record = await repository.save(
      SkipRecordDraft(
        stock: const StockCandidate(code: '8306', name: '三菱UFJ'),
        quote: StockQuote(
          code: '8306',
          name: '三菱UFJ',
          price: 1000,
          fetchedAt: DateTime(2026, 8, 1),
        ),
        recordedAt: DateTime(2026, 8, 1),
        reason: SkipReason.priceTooHigh,
        answerCheckSetting: AnswerCheckSetting(
          period: AnswerCheckPeriod.custom,
          customDate: DateTime(2026, 8, 16),
        ),
      ),
    );
    expect(record.requestedAnswerDate, DateTime(2026, 8, 16));
    expect(record.effectiveAnswerDate, DateTime(2026, 8, 17));
    final restored = (await repository.getAll()).single;
    expect(restored.requestedAnswerDate, DateTime(2026, 8, 16));
    expect(restored.effectiveAnswerDate, DateTime(2026, 8, 17));
  });

  test('Repositoryで1件削除と全件リセットができる', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SharedPreferencesSkipRecordRepository(
      preferences: await SharedPreferences.getInstance(),
    );
    await repository.save(_draft('1001'));
    await repository.save(_draft('1002'));
    final records = await repository.getAll();
    await repository.delete(records.first.id);
    expect((await repository.getAll()).length, 1);
    await repository.clear();
    expect(await repository.getAll(), isEmpty);
  });

  test('保存例外はunderlying causeを開発ログ向けに保持する', () {
    final cause = FormatException('invalid record');
    final error = SkipRecordSaveException(
      '端末内へ保存できませんでした',
      cause: cause,
      stackTrace: StackTrace.current,
    );
    expect(error.cause, same(cause));
    expect(error.stackTrace, isNotNull);
    expect(error.toString(), contains('invalid record'));
  });

  testWidgets('未完了だけを最大3件表示し、すべて見るで状態を確認できる', (tester) async {
    final repository = _MutableMemoryRepository([
      _pending('1', '一番古い', DateTime(2026, 8, 1)),
      _pending('2', '二番目', DateTime(2026, 8, 2)),
      _pending('3', '三番目', DateTime(2026, 8, 3)),
      _pending('4', '一番新しい', DateTime(2026, 8, 4)),
      _completed('done', '完了済み', DateTime(2026, 8, 5)),
    ]);
    await tester.pumpWidget(
      MoshiKabuApp(
        repository: repository,
        notificationService: _FakeNotificationService(),
        clock: () => DateTime(2026, 8, 5),
        showDeveloperMenu: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('完了済み'), findsNothing);
    expect(find.text('一番新しい'), findsOneWidget);
    expect(find.text('一番古い'), findsNothing);
    await tester.ensureVisible(
      find.byKey(const ValueKey('open-all-pending-records')),
    );
    await tester.tap(find.byKey(const ValueKey('open-all-pending-records')));
    await tester.pumpAndSettle();
    expect(find.text('見送り記録'), findsOneWidget);
    expect(find.text('一番古い'), findsOneWidget);
    expect(find.text('完了済み'), findsNothing);
    expect(find.textContaining('答え合わせまであと'), findsWidgets);
  });

  testWidgets('ホームから確認付きで1件削除しベル件数へ即時反映する', (tester) async {
    final repository = _MutableMemoryRepository([
      _pending('ready', '削除対象', DateTime(2026, 7, 1)),
      _pending('keep', '残す記録', DateTime(2026, 8, 10)),
    ]);
    final notifications = _FakeNotificationService(
      showFirstRecordPrompt: false,
    );
    await tester.pumpWidget(
      MoshiKabuApp(
        repository: repository,
        notificationService: notifications,
        clock: () => DateTime(2026, 8, 11),
        showDeveloperMenu: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1件、答え合わせできるよ！'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('delete-recent-ready')),
    );
    await tester.tap(find.byKey(const ValueKey('delete-recent-ready')));
    await tester.pumpAndSettle();
    expect(find.text('この記録を削除しますか？'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-delete-record')));
    await tester.pumpAndSettle();

    expect(repository.records.map((record) => record.id), ['keep']);
    expect(notifications.cancelledIds, ['ready']);
    expect(find.byKey(const ValueKey('answer-count-badge')), findsNothing);
    expect(find.text('今日は気になる株あった？'), findsOneWidget);
  });

  testWidgets('設定から確認付きで全記録・通知・overrideをリセットする', (tester) async {
    final repository = _MutableMemoryRepository([
      _pending('pending', '未完了', DateTime(2026, 7, 1)),
      _completed('done', '完了', DateTime(2026, 7, 2)),
    ]);
    final notifications = _FakeNotificationService();
    final overrides = _MemoryOverrideRepository({
      'pending': DateTime(2026, 7, 1),
    });
    await tester.pumpWidget(
      MoshiKabuApp(
        repository: repository,
        notificationService: notifications,
        developerOverrideRepository: overrides,
        clock: () => DateTime(2026, 8, 11),
        showDeveloperMenu: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('設定'));
    await tester.pumpAndSettle();
    expect(find.text('答え合わせ通知'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reset-all-records')));
    await tester.pumpAndSettle();
    expect(find.text('すべての記録を削除しますか？'), findsOneWidget);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(repository.records.length, 2);

    await tester.tap(find.byKey(const ValueKey('reset-all-records')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-reset-all-records')));
    await tester.pumpAndSettle();
    expect(repository.records, isEmpty);
    expect(overrides.values, isEmpty);
    expect(notifications.cancelAllCount, greaterThan(0));
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('answer-count-badge')), findsNothing);
    expect(find.text('記録したもし株がここに表示されます'), findsOneWidget);
  });

  testWidgets('通知OFFでもアプリ内答え合わせは動作し、通知タップで一覧を開く', (tester) async {
    final notifications = _FakeNotificationService(enabled: false);
    await tester.pumpWidget(
      MoshiKabuApp(
        repository: _MutableMemoryRepository([
          _pending('ready', '通知テスト', DateTime(2026, 7, 1)),
        ]),
        notificationService: notifications,
        answerPriceService: const _FixedAnswerPriceService(),
        clock: () => DateTime(2026, 8, 11),
        showDeveloperMenu: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1件、答え合わせできるよ！'), findsOneWidget);
    expect(notifications.rebuildCount, greaterThan(0));

    notifications.tap();
    await tester.pumpAndSettle();
    expect(find.text('答え合わせ'), findsOneWidget);
    expect(find.text('通知テスト'), findsOneWidget);
  });

  testWidgets('通知権限拒否時は設定をOFF表示にしてクラッシュしない', (tester) async {
    final notifications = _FakeNotificationService(
      enabled: false,
      permissionGranted: false,
    );
    await tester.pumpWidget(
      MoshiKabuApp(
        repository: _MutableMemoryRepository(const []),
        notificationService: notifications,
        showDeveloperMenu: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('設定'));
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('answer-notification-switch'));
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    expect(find.text('端末の通知権限が許可されていません'), findsOneWidget);
  });

  testWidgets('未要求時は説明後にだけ通知許可処理へ進む', (tester) async {
    var requestCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          notificationEnabled: false,
          notificationPermission: NotificationPermissionState.notRequested,
          onNotificationChanged: (enabled) async {
            requestCount++;
            return NotificationPermissionState.granted;
          },
          onOpenNotificationSettings: () async => true,
          onResetAllRecords: () async {},
        ),
      ),
    );

    final toggle = find.byKey(const ValueKey('answer-notification-switch'));
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('答え合わせの日にお知らせしますか？'), findsOneWidget);
    expect(requestCount, 0);
    await tester.tap(find.text('あとで'));
    await tester.pumpAndSettle();
    expect(requestCount, 0);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('request-notification-permission')),
    );
    await tester.pumpAndSettle();
    expect(requestCount, 1);
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
  });

  testWidgets('拒否済みはOFF表示と端末設定への導線を表示する', (tester) async {
    var openCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          notificationEnabled: false,
          notificationPermission: NotificationPermissionState.denied,
          onNotificationChanged: (_) async =>
              NotificationPermissionState.denied,
          onOpenNotificationSettings: () async {
            openCount++;
            return true;
          },
          onResetAllRecords: () async {},
        ),
      ),
    );

    expect(find.text('端末の設定で通知がオフになっています'), findsOneWidget);
    final toggle = find.byKey(const ValueKey('answer-notification-switch'));
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    await tester.tap(find.byKey(const ValueKey('open-notification-settings')));
    expect(openCount, 1);
  });

  testWidgets('端末設定で許可後、foreground復帰時に状態と予約を再構築する', (tester) async {
    final notifications = _FakeNotificationService(
      enabled: true,
      permissionGranted: false,
    );
    await tester.pumpWidget(
      MoshiKabuApp(
        repository: _MutableMemoryRepository([
          _pending('resume', '復帰テスト', DateTime(2026, 8, 1)),
        ]),
        notificationService: notifications,
        showDeveloperMenu: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('設定'));
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('answer-notification-switch'));
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);

    final rebuildsBeforeResume = notifications.rebuildCount;
    notifications.permissionGranted = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    expect(notifications.rebuildCount, greaterThan(rebuildsBeforeResume));
  });
}

SkipRecordDraft _draft(String code) => SkipRecordDraft(
  stock: StockCandidate(code: code, name: '銘柄$code'),
  quote: StockQuote(
    code: code,
    name: '銘柄$code',
    price: 1000,
    fetchedAt: DateTime(2026, 8, 1),
  ),
  recordedAt: DateTime(2026, 8, int.parse(code.substring(code.length - 1))),
  reason: SkipReason.priceTooHigh,
  answerCheckSetting: const AnswerCheckSetting.oneMonth(),
);

SkipRecord _pending(String id, String name, DateTime date) => SkipRecord(
  id: id,
  stockCode: '8306',
  stockName: name,
  skippedPrice: 1000,
  recordedAt: date,
  reason: SkipReason.priceTooHigh,
  reasonLabel: '高いと思った',
  answerCheckSetting: const AnswerCheckSetting.oneMonth(),
  answerCheckStatus: AnswerCheckStatus.pending,
);

SkipRecord _completed(String id, String name, DateTime date) =>
    _pending(id, name, date).copyWith(
      answerCheckStatus: AnswerCheckStatus.completed,
      answerPrice: 1100,
      answerPriceDate: date.add(const Duration(days: 30)),
      answerChangePercent: 10,
      answeredAt: date.add(const Duration(days: 31)),
    );

class _MutableMemoryRepository
    implements SkipRecordRepository, MutableSkipRecordRepository {
  _MutableMemoryRepository(this.records);
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

  @override
  Future<void> delete(String id) async =>
      records.removeWhere((record) => record.id == id);

  @override
  Future<void> clear() async => records.clear();
}

class _MemoryOverrideRepository implements DeveloperAnswerOverrideRepository {
  _MemoryOverrideRepository(this.values);
  final Map<String, DateTime> values;

  @override
  Future<void> clear() async => values.clear();

  @override
  Future<Map<String, DateTime>> getAll() async => {...values};

  @override
  Future<void> replaceAll(Map<String, DateTime> overrides) async {
    values
      ..clear()
      ..addAll(overrides);
  }
}

class _FakeNotificationService implements AnswerNotificationService {
  _FakeNotificationService({
    this.enabled = true,
    this.permissionGranted = true,
    this.showFirstRecordPrompt = false,
  });
  bool enabled;
  bool permissionGranted;
  bool showFirstRecordPrompt;
  int rebuildCount = 0;
  int cancelAllCount = 0;
  final List<String> cancelledIds = [];
  ValueChanged<String?>? _onTap;

  void tap() => _onTap?.call('answer-list');

  @override
  Future<void> initialize(ValueChanged<String?> onNotificationTap) async {
    _onTap = onNotificationTap;
  }

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<NotificationPermissionState> permissionState() async =>
      permissionGranted
      ? NotificationPermissionState.granted
      : NotificationPermissionState.denied;

  @override
  Future<bool> shouldShowFirstRecordPrompt() async => showFirstRecordPrompt;

  @override
  Future<void> markFirstRecordPromptShown() async {
    showFirstRecordPrompt = false;
  }

  @override
  Future<NotificationPermissionState> setEnabled(bool value) async {
    enabled = value && permissionGranted;
    return permissionGranted
        ? NotificationPermissionState.granted
        : NotificationPermissionState.denied;
  }

  @override
  Future<bool> openSystemNotificationSettings() async => true;

  @override
  Future<void> rebuild(
    Iterable<SkipRecord> records,
    ProvisionalAnswerReadyService answerReadyService,
  ) async {
    rebuildCount++;
  }

  @override
  Future<void> cancelRecord(String recordId) async =>
      cancelledIds.add(recordId);

  @override
  Future<void> cancelAll() async => cancelAllCount++;
}

class _FixedAnswerPriceService implements AnswerPriceService {
  const _FixedAnswerPriceService();

  @override
  Future<AnswerClose> fetchClose(String stockCode, DateTime date) async =>
      AnswerClose(code: stockCode, close: 1100, priceDate: date);
}
