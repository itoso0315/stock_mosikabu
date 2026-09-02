import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'models/home_view_data.dart';
import 'models/skip_record.dart';
import 'models/skip_record_draft.dart';
import 'models/answer_close.dart';
import 'repositories/skip_record_repository.dart';
import 'repositories/developer_answer_override_repository.dart';
import 'screens/home_screen.dart';
import 'screens/pending_records_screen.dart';
import 'screens/review_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/skip_record_analysis_screen.dart';
import 'screens/answer_waiting_screen.dart';
import 'screens/stock_search_screen.dart';
import 'screens/start_screen.dart';
import 'services/stock_price_service.dart';
import 'services/backend_warmup_service.dart';
import 'services/answer_price_service.dart';
import 'services/answer_notification_service.dart';
import 'services/provisional_answer_ready_service.dart';
import 'services/skip_record_analysis_service.dart';
import 'theme/app_theme.dart';

class MoshiKabuApp extends StatefulWidget {
  const MoshiKabuApp({
    super.key,
    this.repository,
    this.stockPriceService,
    this.clock,
    this.showDeveloperMenu = true,
    this.developerOverrideRepository,
    this.answerPriceService,
    this.notificationService,
    this.backendWarmupService,
    this.showStartScreen = false,
  });

  final SkipRecordRepository? repository;
  final StockPriceService? stockPriceService;
  final DateTime Function()? clock;
  final bool showDeveloperMenu;
  final DeveloperAnswerOverrideRepository? developerOverrideRepository;
  final AnswerPriceService? answerPriceService;
  final AnswerNotificationService? notificationService;
  final BackendWarmupService? backendWarmupService;
  final bool showStartScreen;

  @override
  State<MoshiKabuApp> createState() => _MoshiKabuAppState();
}

class _MoshiKabuAppState extends State<MoshiKabuApp>
    with WidgetsBindingObserver {
  late final SkipRecordRepository _repository;
  List<SkipRecord> _records = const [];
  Map<String, DateTime> _answerDateOverrides = const {};
  final _answerReadyService = const ProvisionalAnswerReadyService();
  final _analysisService = const SkipRecordAnalysisService();
  late final DeveloperAnswerOverrideRepository _developerOverrideRepository;
  late final AnswerPriceService _answerPriceService;
  late final AnswerNotificationService _notificationService;
  late final BackendWarmupService _backendWarmupService;
  late final Future<void> _notificationInitialization;
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _notificationPreferenceEnabled = true;
  late bool _hasStarted;
  NotificationPermissionState _notificationPermission =
      NotificationPermissionState.notRequested;

  bool get _notificationEnabled =>
      _notificationPreferenceEnabled &&
      _notificationPermission == NotificationPermissionState.granted;

  bool get _developerMenuEnabled => kDebugMode && widget.showDeveloperMenu;

  List<SkipRecord> get _answerReadyRecords => _answerReadyService.readyRecords(
    _records,
    widget.clock?.call() ?? DateTime.now(),
    answerDateOverrides: _answerDateOverrides,
  );

  @override
  void initState() {
    super.initState();
    _hasStarted = !widget.showStartScreen;
    WidgetsBinding.instance.addObserver(this);
    _repository = widget.repository ?? SharedPreferencesSkipRecordRepository();
    _developerOverrideRepository =
        widget.developerOverrideRepository ??
        SharedPreferencesDeveloperAnswerOverrideRepository();
    _answerPriceService = widget.answerPriceService ?? HttpAnswerPriceService();
    _notificationService =
        widget.notificationService ?? LocalAnswerNotificationService();
    _backendWarmupService =
        widget.backendWarmupService ?? HttpBackendWarmupService();
    unawaited(_warmUpBackend());
    _notificationInitialization = _initializeNotifications();
    _loadRecords();
    if (_developerMenuEnabled) _loadDeveloperOverrides();
  }

  Future<void> _warmUpBackend() async {
    try {
      await _backendWarmupService.warmUp();
    } on Object catch (error, stackTrace) {
      // Custom implementations are also treated as best effort so startup is
      // never coupled to backend availability.
      if (kDebugMode) {
        debugPrint('[BackendWarmup] Service failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNotificationState(rebuild: true);
    }
  }

  Future<void> _initializeNotifications() async {
    await _notificationService.initialize((_) {
      if (_navigatorKey.currentState != null) {
        _openAnswersFromNotification();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openAnswersFromNotification();
        });
        WidgetsBinding.instance.scheduleFrame();
      }
    });
    await _refreshNotificationState();
  }

  Future<void> _refreshNotificationState({bool rebuild = false}) async {
    final enabled = await _notificationService.isEnabled();
    final permission = await _notificationService.permissionState();
    if (mounted) {
      setState(() {
        _notificationPreferenceEnabled = enabled;
        _notificationPermission = permission;
      });
    }
    if (!rebuild) return;
    if (enabled && permission == NotificationPermissionState.granted) {
      await _notificationService.rebuild(_records, _answerReadyService);
    } else {
      await _notificationService.cancelAll();
    }
  }

  Future<void> _loadDeveloperOverrides() async {
    final overrides = await _developerOverrideRepository.getAll();
    if (!mounted) return;
    setState(() => _answerDateOverrides = overrides);
  }

  Future<int> _makeLatestAnswerReady() async {
    final pending =
        _records
            .where(
              (record) => record.answerCheckStatus == AnswerCheckStatus.pending,
            )
            .toList()
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    if (pending.isEmpty) return 0;
    final overrides = Map<String, DateTime>.of(_answerDateOverrides)
      ..[pending.first.id] = _debugReadyDate;
    await _developerOverrideRepository.replaceAll(overrides);
    if (mounted) setState(() => _answerDateOverrides = overrides);
    return 1;
  }

  Future<int> _makeAllAnswersReady() async {
    final pending = _records.where(
      (record) => record.answerCheckStatus == AnswerCheckStatus.pending,
    );
    final overrides = Map<String, DateTime>.of(_answerDateOverrides);
    var count = 0;
    for (final record in pending) {
      overrides[record.id] = _debugReadyDate;
      count++;
    }
    if (count == 0) return 0;
    await _developerOverrideRepository.replaceAll(overrides);
    if (mounted) setState(() => _answerDateOverrides = overrides);
    return count;
  }

  Future<void> _resetDeveloperOverrides() async {
    await _developerOverrideRepository.clear();
    if (mounted) setState(() => _answerDateOverrides = const {});
  }

  DateTime get _debugReadyDate {
    var date = (widget.clock?.call() ?? DateTime.now()).subtract(
      const Duration(days: 7),
    );
    while (date.weekday == DateTime.saturday ||
        date.weekday == DateTime.sunday) {
      date = date.subtract(const Duration(days: 1));
    }
    return date;
  }

  Future<void> _loadRecords() async {
    final records = await _repository.getAll();
    if (!mounted) return;
    setState(() => _records = records);
    await _notificationInitialization;
    await _notificationService.rebuild(records, _answerReadyService);
  }

  Future<SkipRecord> _saveRecord(SkipRecordDraft draft) async {
    final record = await _repository.save(draft);
    if (mounted) {
      setState(() {
        _records = [record, ..._records]
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      });
    }
    try {
      await _showFirstRecordNotificationPrompt();
      await _notificationService.rebuild(_records, _answerReadyService);
    } on Object catch (error, stackTrace) {
      // The record is already safely persisted. Notification setup is a
      // best-effort secondary operation and must not turn a successful save
      // into a user-visible save failure.
      if (kDebugMode) {
        debugPrint('[Notification] Post-save setup failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    return record;
  }

  Future<void> _showFirstRecordNotificationPrompt() async {
    if (!await _notificationService.shouldShowFirstRecordPrompt()) return;
    await _notificationService.markFirstRecordPromptShown();
    final context = _navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final receive = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('答え合わせの日にお知らせしますか？'),
        content: const Text('見送った株の答え合わせができる日に、もし株から通知します。'),
        actions: [
          TextButton(
            key: const ValueKey('notification-permission-later'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('あとで'),
          ),
          FilledButton(
            key: const ValueKey('notification-permission-accept'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('通知を受け取る'),
          ),
        ],
      ),
    );
    if (receive == true) await _setNotifications(true);
  }

  Future<SkipRecord> _completeAnswer(
    SkipRecord record,
    AnswerClose close,
  ) async {
    if (record.answerCheckStatus == AnswerCheckStatus.completed) return record;
    final changePercent =
        (close.close - record.skippedPrice) / record.skippedPrice * 100;
    final completed = record.copyWith(
      answerCheckStatus: AnswerCheckStatus.completed,
      answerPrice: close.close,
      answerPriceDate: close.priceDate,
      answerChangePercent: changePercent,
      answeredAt: widget.clock?.call() ?? DateTime.now(),
    );
    await _repository.update(completed);
    await _notificationService.cancelRecord(completed.id);
    if (mounted) {
      setState(() {
        _records = _records
            .map(
              (existing) => existing.id == completed.id ? completed : existing,
            )
            .toList();
      });
    }
    return completed;
  }

  Future<NotificationPermissionState> _setNotifications(bool enabled) async {
    final result = await _notificationService.setEnabled(enabled);
    _notificationPreferenceEnabled = await _notificationService.isEnabled();
    _notificationPermission = await _notificationService.permissionState();
    if (_notificationEnabled) {
      await _notificationService.rebuild(_records, _answerReadyService);
    } else {
      await _notificationService.cancelAll();
    }
    if (mounted) setState(() {});
    return result;
  }

  Future<void> _deleteRecord(String id) async {
    final repository = _repository;
    if (repository is! MutableSkipRecordRepository) {
      throw const SkipRecordSaveException('削除に対応していません');
    }
    await (repository as MutableSkipRecordRepository).delete(id);
    await _notificationService.cancelRecord(id);
    final overrides = Map<String, DateTime>.of(_answerDateOverrides)
      ..remove(id);
    await _developerOverrideRepository.replaceAll(overrides);
    if (mounted) {
      setState(() {
        _records = _records.where((record) => record.id != id).toList();
        _answerDateOverrides = overrides;
      });
    }
  }

  Future<void> _resetAllRecords() async {
    final repository = _repository;
    if (repository is! MutableSkipRecordRepository) {
      throw const SkipRecordSaveException('削除に対応していません');
    }
    await (repository as MutableSkipRecordRepository).clear();
    await _notificationService.cancelAll();
    await _developerOverrideRepository.clear();
    if (mounted) {
      setState(() {
        _records = const [];
        _answerDateOverrides = const {};
      });
    }
  }

  void _openAnswersFromNotification() {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    navigator.push<void>(
      MaterialPageRoute<void>(builder: _answersScreenBuilder),
    );
  }

  Widget _answersScreenBuilder(
    BuildContext context, [
    List<SkipRecord>? records,
  ]) => AnswerWaitingScreen(
    records: records ?? _answerReadyRecords,
    answerReadyService: _answerReadyService,
    answerDateOverrides: _answerDateOverrides,
    answerPriceService: _answerPriceService,
    onComplete: _completeAnswer,
  );

  Future<bool> _openPendingAnswer(
    BuildContext context,
    SkipRecord record,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => _answersScreenBuilder(context, [record]),
      ),
    );
    return !_records.any(
      (item) =>
          item.id == record.id &&
          item.answerCheckStatus != AnswerCheckStatus.completed,
    );
  }

  HomeViewData get _homeData {
    final analysis = _analysisService.analyze(_records);
    final pending =
        _records
            .where(
              (record) =>
                  record.answerCheckStatus != AnswerCheckStatus.completed,
            )
            .toList()
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return HomeViewData(
      answerReadyCount: _answerReadyRecords.length,
      trendInsight: analysis.homeInsight,
      recentStocks: pending.take(3).map((record) {
        return RecentMoshiStock(
          id: record.id,
          name: record.stockName,
          stockCode: record.stockCode,
          recordedPrice: _formatPrice(record.skippedPrice),
          recordedAt: _formatDateTime(record.recordedAt),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'もし株',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _hasStarted
          ? _buildHomeScreen()
          : StartScreen(onStart: () => setState(() => _hasStarted = true)),
    );
  }

  Widget _buildHomeScreen() {
    return HomeScreen(
      data: _homeData,
      answersScreenBuilder: _answersScreenBuilder,
      reviewScreenBuilder: (_) => ReviewScreen(
        records: _records,
        answerPriceService: _answerPriceService,
        onComplete: _completeAnswer,
      ),
      analysisScreenBuilder: (_) => SkipRecordAnalysisScreen(
        analysis: _analysisService.analyze(_records),
      ),
      allRecordsScreenBuilder: (pendingContext) => PendingRecordsScreen(
        records: _records,
        now: widget.clock?.call() ?? DateTime.now(),
        answerReadyService: _answerReadyService,
        answerDateOverrides: _answerDateOverrides,
        onOpenAnswer: (record) => _openPendingAnswer(pendingContext, record),
        onDelete: _deleteRecord,
      ),
      onDeleteRecord: _deleteRecord,
      developerMenuBuilder: (_) => SettingsScreen(
        notificationEnabled: _notificationEnabled,
        notificationPermission: _notificationPermission,
        onNotificationChanged: _setNotifications,
        onOpenNotificationSettings:
            _notificationService.openSystemNotificationSettings,
        onResetAllRecords: _resetAllRecords,
        onMakeLatestReady: _developerMenuEnabled
            ? _makeLatestAnswerReady
            : null,
        onMakeAllReady: _developerMenuEnabled ? _makeAllAnswersReady : null,
        onResetOverrides: _developerMenuEnabled
            ? _resetDeveloperOverrides
            : null,
      ),
      searchScreenBuilder: (_) => StockSearchScreen(
        stockPriceService: widget.stockPriceService,
        onSave: _saveRecord,
      ),
    );
  }

  static String _formatPrice(double price) {
    final digits = price.round().toString();
    return '${digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}円';
  }

  static String _formatDateTime(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${value.month}/${value.day} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }
}
