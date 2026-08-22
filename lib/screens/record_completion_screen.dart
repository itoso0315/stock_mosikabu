import 'package:flutter/material.dart';

import '../models/skip_record.dart';
import '../models/skip_record_draft.dart';
import '../theme/app_theme.dart';

class RecordCompletionScreen extends StatelessWidget {
  const RecordCompletionScreen({super.key, required this.record});

  final SkipRecord record;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                SizedBox(
                  height: 220,
                  child: Image.asset(
                    'assets/images/record_completion_cat.png',
                    key: const ValueKey('record-completion-cat'),
                    semanticLabel: '旗を持った猫キャラクター',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '記録しました！',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  '答え合わせの日まで、ゆっくり待とう。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.mutedText),
                ),
                const SizedBox(height: 24),
                _SavedRecordCard(record: record),
                const SizedBox(height: 28),
                FilledButton(
                  key: const ValueKey('back-to-home-button'),
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('ホームに戻る'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedRecordCard extends StatelessWidget {
  const _SavedRecordCard({required this.record});

  final SkipRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
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
          const SizedBox(height: 14),
          _row('見送り価格', _formatPrice(record.skippedPrice)),
          _row('見送った理由', _reasonText(record)),
          _row('答え合わせ', answerCheckSettingLabel(record.answerCheckSetting)),
          _row('記録日時', _formatDateTime(record.recordedAt)),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 94,
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

  static String _reasonText(SkipRecord record) {
    final note = record.otherNote;
    return record.reason == SkipReason.other && note != null && note.isNotEmpty
        ? '${record.reasonLabel}（$note）'
        : record.reasonLabel;
  }

  static String _formatPrice(double price) {
    final value = price.round().toString();
    return '${value.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}円';
  }

  static String _formatDateTime(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${value.year}/${twoDigits(value.month)}/${twoDigits(value.day)} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }
}
