import 'package:flutter/material.dart';

import '../models/skip_record.dart';
import '../models/answer_close.dart';
import '../services/answer_price_service.dart';
import '../services/provisional_answer_ready_service.dart';
import '../theme/app_theme.dart';
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
  late List<SkipRecord> _records;

  @override
  void initState() {
    super.initState();
    _records = [...widget.records];
  }

  Future<void> _openRecord(SkipRecord record, DateTime answerDate) async {
    final completed = await Navigator.of(context).push<SkipRecord>(
      MaterialPageRoute<SkipRecord>(
        builder: (_) => AnswerResultScreen(
          record: record,
          answerDate: answerDate,
          answerPriceService: widget.answerPriceService,
          onComplete: widget.onComplete,
        ),
      ),
    );
    if (!mounted || completed == null) return;
    if (completed.answerCheckStatus == AnswerCheckStatus.completed) {
      setState(() => _records.removeWhere((item) => item.id == completed.id));
    }
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
        title: const Text('答え合わせ待ち'),
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
                itemBuilder: (context, index) => _WaitingRecordCard(
                  record: _records[index],
                  answerDate: widget.answerReadyService.answerDate(
                    _records[index],
                    override: widget.answerDateOverrides[_records[index].id],
                  ),
                  onTap: () {
                    final record = _records[index];
                    _openRecord(
                      record,
                      widget.answerReadyService.answerDate(
                        record,
                        override: widget.answerDateOverrides[record.id],
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
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
}

class _WaitingRecordCard extends StatelessWidget {
  const _WaitingRecordCard({
    required this.record,
    required this.answerDate,
    required this.onTap,
  });

  final SkipRecord record;
  final DateTime answerDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey('answer-waiting-record-${record.id}'),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.outline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
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
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 14),
              _InfoRow(
                label: '見送り価格',
                value: _formatPrice(record.skippedPrice),
              ),
              _InfoRow(
                label: '記録日時',
                value: _formatDateTime(record.recordedAt),
              ),
              _InfoRow(label: '答え合わせ予定日', value: _formatDate(answerDate)),
              _InfoRow(label: '見送った理由', value: record.reasonLabel),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatPrice(double price) {
    final value = price.round().toString();
    return '${value.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}円';
  }

  static String _formatDate(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${value.year}/${twoDigits(value.month)}/${twoDigits(value.day)}';
  }

  static String _formatDateTime(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${_formatDate(value)} ${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.mutedText),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
