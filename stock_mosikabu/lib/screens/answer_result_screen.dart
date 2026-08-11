import 'package:flutter/material.dart';

import '../models/answer_close.dart';
import '../models/skip_record.dart';
import '../services/answer_price_service.dart';
import '../theme/app_theme.dart';
import '../widgets/answer_result_style.dart';
import '../widgets/stock_icon.dart';

class AnswerResultScreen extends StatefulWidget {
  const AnswerResultScreen({
    super.key,
    required this.record,
    required this.answerDate,
    required this.answerPriceService,
    required this.onComplete,
  });

  final SkipRecord record;
  final DateTime answerDate;
  final AnswerPriceService answerPriceService;
  final Future<SkipRecord> Function(SkipRecord, AnswerClose) onComplete;

  @override
  State<AnswerResultScreen> createState() => _AnswerResultScreenState();
}

class _AnswerResultScreenState extends State<AnswerResultScreen> {
  SkipRecord? _completedRecord;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.record.answerCheckStatus == AnswerCheckStatus.completed &&
        widget.record.answerPrice != null) {
      _completedRecord = widget.record;
      _isLoading = false;
    } else {
      _fetchResult();
    }
  }

  Future<void> _fetchResult() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final close = await widget.answerPriceService.fetchClose(
        widget.record.stockCode,
        widget.answerDate,
      );
      final completed = await widget.onComplete(widget.record, close);
      if (!mounted) return;
      setState(() {
        _completedRecord = completed;
        _isLoading = false;
      });
    } on AnswerPriceException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _errorMessage = '答え合わせ価格を取得できませんでした。もう一度お試しください。';
        _isLoading = false;
      });
    }
  }

  void _goBack() => Navigator.of(context).pop(_completedRecord);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text('答え合わせ'),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 14),
                    Text('答え合わせ価格を取得中…'),
                  ],
                ),
              )
            : _errorMessage != null
            ? _ErrorState(message: _errorMessage!, onRetry: _fetchResult)
            : _ResultContent(record: _completedRecord!),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 48,
            color: AppColors.mutedText,
          ),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            key: const ValueKey('retry-answer-price'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('もう一度試す'),
          ),
        ],
      ),
    ),
  );
}

class _ResultContent extends StatelessWidget {
  const _ResultContent({required this.record});
  final SkipRecord record;

  @override
  Widget build(BuildContext context) {
    final percent = record.answerChangePercent!;
    final resultColor = answerResultColor(percent);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: Image.asset(
              'assets/images/answer_result_cat.png',
              key: const ValueKey('answer-result-cat'),
              fit: BoxFit.contain,
              semanticLabel: '棒グラフを上る猫',
            ),
          ),
          const SizedBox(height: 8),
          const Text('こんな値動きになったよ'),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    StockIcon(
                      companyName: record.stockName,
                      stockCode: record.stockCode,
                      size: 48,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.stockName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            record.stockCode,
                            style: const TextStyle(color: AppColors.mutedText),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _PriceColumn(
                        label: '見送り時',
                        price: record.skippedPrice,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    Expanded(
                      child: _PriceColumn(
                        label: '答え合わせ',
                        price: record.answerPrice!,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'もし買っていたら ${formatAnswerPercent(percent)}',
                  key: const ValueKey('answer-result-percent'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: resultColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DetailsCard(record: record),
        ],
      ),
    );
  }
}

class _PriceColumn extends StatelessWidget {
  const _PriceColumn({required this.label, required this.price});
  final String label;
  final double price;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: const TextStyle(color: AppColors.mutedText)),
      const SizedBox(height: 5),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          _formatPrice(price),
          maxLines: 1,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.record});
  final SkipRecord record;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.outline),
    ),
    child: Column(
      children: [
        _row('見送った理由', record.reasonLabel),
        _row('記録日時', _formatDateTime(record.recordedAt)),
        _row('答え合わせ期間', answerCheckSettingLabel(record.answerCheckSetting)),
        _row('価格取得日', _formatDate(record.answerPriceDate!)),
      ],
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: const TextStyle(color: AppColors.mutedText),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              key: ValueKey('answer-detail-value-$label'),
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    ),
  );
}

String _formatPrice(double price) {
  final value = price.round().toString();
  return '${value.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}円';
}

String _formatDate(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${value.year}/${twoDigits(value.month)}/${twoDigits(value.day)}';
}

String _formatDateTime(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${_formatDate(value)} ${twoDigits(value.hour)}:${twoDigits(value.minute)}';
}
