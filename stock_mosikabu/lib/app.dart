import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'models/home_view_data.dart';
import 'models/skip_record.dart';
import 'models/skip_record_draft.dart';
import 'models/answer_close.dart';
import 'repositories/skip_record_repository.dart';
import 'repositories/developer_answer_override_repository.dart';
import 'screens/developer_menu_screen.dart';
import 'screens/home_screen.dart';
import 'screens/answer_waiting_screen.dart';
import 'screens/stock_search_screen.dart';
import 'services/stock_price_service.dart';
import 'services/answer_price_service.dart';
import 'services/provisional_answer_ready_service.dart';
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
  });

  final SkipRecordRepository? repository;
  final StockPriceService? stockPriceService;
  final DateTime Function()? clock;
  final bool showDeveloperMenu;
  final DeveloperAnswerOverrideRepository? developerOverrideRepository;
  final AnswerPriceService? answerPriceService;

  @override
  State<MoshiKabuApp> createState() => _MoshiKabuAppState();
}

class _MoshiKabuAppState extends State<MoshiKabuApp> {
  late final SkipRecordRepository _repository;
  List<SkipRecord> _records = const [];
  Map<String, DateTime> _answerDateOverrides = const {};
  final _answerReadyService = const ProvisionalAnswerReadyService();
  late final DeveloperAnswerOverrideRepository _developerOverrideRepository;
  late final AnswerPriceService _answerPriceService;

  bool get _developerMenuEnabled => kDebugMode && widget.showDeveloperMenu;

  List<SkipRecord> get _answerReadyRecords => _answerReadyService.readyRecords(
    _records,
    widget.clock?.call() ?? DateTime.now(),
    answerDateOverrides: _answerDateOverrides,
  );

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SharedPreferencesSkipRecordRepository();
    _developerOverrideRepository =
        widget.developerOverrideRepository ??
        SharedPreferencesDeveloperAnswerOverrideRepository();
    _answerPriceService = widget.answerPriceService ?? HttpAnswerPriceService();
    _loadRecords();
    if (_developerMenuEnabled) _loadDeveloperOverrides();
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
  }

  Future<SkipRecord> _saveRecord(SkipRecordDraft draft) async {
    final record = await _repository.save(draft);
    if (mounted) {
      setState(() {
        _records = [record, ..._records]
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      });
    }
    return record;
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

  HomeViewData get _homeData {
    return HomeViewData(
      answerReadyCount: _answerReadyRecords.length,
      recentStocks: _records.take(3).map((record) {
        return RecentMoshiStock(
          name: record.stockName,
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
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: HomeScreen(
        data: _homeData,
        answersScreenBuilder: (_) => AnswerWaitingScreen(
          records: _answerReadyRecords,
          answerReadyService: _answerReadyService,
          answerDateOverrides: _answerDateOverrides,
          answerPriceService: _answerPriceService,
          onComplete: _completeAnswer,
        ),
        developerMenuBuilder: _developerMenuEnabled
            ? (_) => DeveloperMenuScreen(
                onMakeLatestReady: _makeLatestAnswerReady,
                onMakeAllReady: _makeAllAnswersReady,
                onReset: _resetDeveloperOverrides,
              )
            : null,
        searchScreenBuilder: (_) => StockSearchScreen(
          stockPriceService: widget.stockPriceService,
          onSave: _saveRecord,
        ),
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
