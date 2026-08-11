import 'package:flutter/material.dart';

import '../models/skip_record.dart';
import '../services/provisional_answer_ready_service.dart';
import '../theme/app_theme.dart';
import '../widgets/record_delete_dialog.dart';
import '../widgets/stock_icon.dart';

class PendingRecordsScreen extends StatefulWidget {
  const PendingRecordsScreen({
    super.key,
    required this.records,
    required this.now,
    required this.answerReadyService,
    this.answerDateOverrides = const {},
    required this.onOpenAnswer,
    required this.onDelete,
  });

  final List<SkipRecord> records;
  final DateTime now;
  final ProvisionalAnswerReadyService answerReadyService;
  final Map<String, DateTime> answerDateOverrides;
  final Future<bool> Function(SkipRecord record) onOpenAnswer;
  final Future<void> Function(String id) onDelete;

  @override
  State<PendingRecordsScreen> createState() => _PendingRecordsScreenState();
}

class _PendingRecordsScreenState extends State<PendingRecordsScreen> {
  late final List<SkipRecord> _records =
      widget.records
          .where(
            (record) => record.answerCheckStatus != AnswerCheckStatus.completed,
          )
          .toList()
        ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

  @override
  Widget build(BuildContext context) {
    final records = _records;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text('見送り記録'),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: records.isEmpty
            ? const _PendingEmptyState()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                itemCount: records.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final record = records[index];
                  final answerDate = widget.answerReadyService.answerDate(
                    record,
                    override: widget.answerDateOverrides[record.id],
                  );
                  final isReady = !answerDate.isAfter(
                    DateUtils.dateOnly(widget.now),
                  );
                  return _PendingRecordCard(
                    record: record,
                    answerDate: answerDate,
                    status: _statusLabel(answerDate, widget.now),
                    onTap: isReady ? () => _openAnswer(record) : null,
                    onDelete: () => _delete(context, record),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, SkipRecord record) async {
    final confirmed = await confirmRecordDeletion(
      context,
      stockName: record.stockName,
      priceLabel: _formatPrice(record.skippedPrice),
    );
    if (!confirmed || !context.mounted) return;
    try {
      await widget.onDelete(record.id);
      if (mounted) {
        setState(() => _records.removeWhere((item) => item.id == record.id));
      }
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('記録を削除できませんでした。もう一度お試しください。')),
      );
    }
  }

  Future<void> _openAnswer(SkipRecord record) async {
    final wasCompleted = await widget.onOpenAnswer(record);
    if (wasCompleted && mounted) {
      setState(() => _records.removeWhere((item) => item.id == record.id));
    }
  }

  static String _statusLabel(DateTime answerDate, DateTime now) {
    final days = DateUtils.dateOnly(
      answerDate,
    ).difference(DateUtils.dateOnly(now)).inDays;
    if (days <= 0) return '答え合わせできます';
    if (days == 1) return '明日答え合わせ';
    return '答え合わせまであと$days日';
  }
}

class _PendingRecordCard extends StatelessWidget {
  const _PendingRecordCard({
    required this.record,
    required this.answerDate,
    required this.status,
    required this.onTap,
    required this.onDelete,
  });

  final SkipRecord record;
  final DateTime answerDate;
  final String status;
  final VoidCallback? onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Material(
    key: ValueKey('pending-record-${record.id}'),
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: AppColors.outline),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                        record.stockName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        record.stockCode,
                        style: const TextStyle(color: AppColors.mutedText),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: ValueKey('delete-pending-${record.id}'),
                  tooltip: '記録を削除',
                  onPressed: onDelete,
                  icon: const Icon(Icons.more_horiz_rounded),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Text(
                  _formatPrice(record.skippedPrice),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  record.reasonLabel,
                  style: const TextStyle(color: AppColors.mutedText),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    status,
                    style: TextStyle(
                      color: onTap == null
                          ? AppColors.mutedText
                          : AppColors.primaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  _formatDate(answerDate),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (onTap != null)
                  const Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _PendingEmptyState extends StatelessWidget {
  const _PendingEmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.event_available_rounded,
            size: 52,
            color: AppColors.primaryDark,
          ),
          const SizedBox(height: 18),
          Text(
            'まだ答え合わせ待ちのもし株はありません',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    ),
  );
}

String _formatPrice(double price) {
  final value = price.round().toString();
  return '${value.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}円';
}

String _formatDate(DateTime value) =>
    '${value.year}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}';
