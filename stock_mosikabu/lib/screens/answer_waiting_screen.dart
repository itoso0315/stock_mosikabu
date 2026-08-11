import 'package:flutter/material.dart';

import '../models/answer_close.dart';
import '../models/skip_record.dart';
import '../services/answer_price_service.dart';
import '../services/provisional_answer_ready_service.dart';
import '../theme/app_theme.dart';
import '../widgets/answer_result_style.dart';
import '../widgets/stock_icon.dart';
import 'answer_result_screen.dart';

class AnswerWaitingScreen extends StatefulWidget {
  const AnswerWaitingScreen({
    super.key,
    required this.records,
    this.answerReadyService = const ProvisionalAnswerReadyService(),
    this.answerDateOverrides = const {},
    required this.answerPriceService,
    required this.onComplete,
  });

  final List<SkipRecord> records;
  final ProvisionalAnswerReadyService answerReadyService;
  final Map<String, DateTime> answerDateOverrides;
  final AnswerPriceService answerPriceService;
  final Future<SkipRecord> Function(SkipRecord, AnswerClose) onComplete;

  @override
  State<AnswerWaitingScreen> createState() => _AnswerWaitingScreenState();
}

class _AnswerWaitingScreenState extends State<AnswerWaitingScreen> {
  late final List<SkipRecord> _records;
  final Set<String> _loadingIds = {};
  final Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    _records = [...widget.records];
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPendingRecords());
  }

  Future<void> _loadPendingRecords() async {
    for (final record in [..._records]) {
      if (!mounted) return;
      if (record.answerCheckStatus != AnswerCheckStatus.completed) {
        await _loadRecord(record);
      }
    }
  }

  Future<void> _loadRecord(SkipRecord record) async {
    if (_loadingIds.contains(record.id)) return;
    setState(() {
      _loadingIds.add(record.id);
      _errors.remove(record.id);
    });
    try {
      final answerDate = _answerDate(record);
      final close = await widget.answerPriceService.fetchClose(
        record.stockCode,
        answerDate,
      );
      final completed = await widget.onComplete(record, close);
      if (!mounted) return;
      final index = _records.indexWhere((item) => item.id == record.id);
      setState(() {
        if (index >= 0) _records[index] = completed;
        _loadingIds.remove(record.id);
      });
    } on AnswerPriceException catch (error) {
      _showError(record.id, error.message);
    } on Object {
      _showError(record.id, '答え合わせ価格を取得できませんでした。もう一度お試しください。');
    }
  }

  void _showError(String id, String message) {
    if (!mounted) return;
    setState(() {
      _loadingIds.remove(id);
      _errors[id] = message;
    });
  }

  DateTime _answerDate(SkipRecord record) => widget.answerReadyService
      .answerDate(record, override: widget.answerDateOverrides[record.id]);

  Future<void> _openRecord(SkipRecord record) async {
    if (record.answerCheckStatus != AnswerCheckStatus.completed) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AnswerResultScreen(
          record: record,
          answerDate: _answerDate(record),
          answerPriceService: widget.answerPriceService,
          onComplete: widget.onComplete,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text('答え合わせ'),
        centerTitle: true,
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: _records.isEmpty
            ? const _EmptyState()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                itemCount: _records.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final record = _records[index];
                  return _AnswerSummaryCard(
                    record: record,
                    isLoading: _loadingIds.contains(record.id),
                    errorMessage: _errors[record.id],
                    onRetry: () => _loadRecord(record),
                    onTap: () => _openRecord(record),
                  );
                },
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.warmAccent,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_available_rounded,
              color: AppColors.primaryDark,
              size: 34,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'まだ答え合わせできる記録はありません',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            '答え合わせの日が来たら、ここに表示されます',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.mutedText),
          ),
        ],
      ),
    ),
  );
}

class _AnswerSummaryCard extends StatelessWidget {
  const _AnswerSummaryCard({
    required this.record,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
    required this.onTap,
  });

  final SkipRecord record;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCompleted = record.answerCheckStatus == AnswerCheckStatus.completed;
    return Material(
      key: ValueKey('answer-waiting-record-${record.id}'),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.outline),
      ),
      child: InkWell(
        onTap: isCompleted ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StockIcon(
                    companyName: record.stockName,
                    stockCode: record.stockCode,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.stockCode,
                          style: const TextStyle(color: AppColors.mutedText),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          record.stockName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  if (isCompleted)
                    AnswerPercentPill(percent: record.answerChangePercent!),
                ],
              ),
              const SizedBox(height: 14),
              if (isLoading)
                const Row(
                  children: [
                    SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text('答え合わせ価格を取得中…'),
                  ],
                )
              else if (errorMessage != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Color(0xFFB44D4D)),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      key: ValueKey('retry-answer-${record.id}'),
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('再試行'),
                    ),
                  ],
                )
              else if (isCompleted) ...[
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _formatPrice(record.skippedPrice),
                          maxLines: 1,
                          style: _priceStyle,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.primaryDark,
                        size: 20,
                      ),
                    ),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          _formatPrice(record.answerPrice!),
                          maxLines: 1,
                          style: _priceStyle,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Text(record.reasonLabel)),
                    Text(
                      answerCheckSettingLabel(record.answerCheckSetting),
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.mutedText,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static const _priceStyle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

String _formatPrice(double price) {
  final value = price.round().toString();
  return '${value.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}円';
}
