import 'package:flutter/material.dart';

import '../models/skip_record_draft.dart';
import '../models/skip_record.dart';
import '../models/stock_candidate.dart';
import '../models/stock_quote.dart';
import '../services/external_stock_link_service.dart';
import '../services/stock_price_service.dart';
import '../theme/app_theme.dart';
import 'record_completion_screen.dart';

class SkipRecordScreen extends StatefulWidget {
  const SkipRecordScreen({
    super.key,
    required this.stock,
    required this.stockPriceService,
    this.recordedAt,
    this.onSubmit,
    this.onSave,
    this.clock,
    this.externalLinkService = const YahooFinanceLinkService(),
  });

  final StockCandidate stock;
  final StockPriceService stockPriceService;
  final DateTime? recordedAt;
  final ValueChanged<SkipRecordDraft>? onSubmit;
  final Future<SkipRecord> Function(SkipRecordDraft)? onSave;
  final DateTime Function()? clock;
  final ExternalStockLinkService externalLinkService;

  @override
  State<SkipRecordScreen> createState() => _SkipRecordScreenState();
}

class _SkipRecordScreenState extends State<SkipRecordScreen> {
  final _otherController = TextEditingController();
  late final DateTime _recordedAt;
  StockQuote? _quote;
  String? _errorMessage;
  SkipReason? _selectedReason;
  AnswerCheckSetting _answerCheckSetting = const AnswerCheckSetting.oneMonth();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _saveErrorMessage;

  @override
  void initState() {
    super.initState();
    _recordedAt = widget.recordedAt ?? DateTime.now();
    _fetchQuote();
  }

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  Future<void> _fetchQuote() async {
    try {
      final quote = await widget.stockPriceService.fetchQuote(widget.stock);
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _isLoading = false;
      });
    } on StockPriceException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _errorMessage = '株価を取得できませんでした';
        _isLoading = false;
      });
    }
  }

  void _retryQuote() {
    setState(() {
      _quote = null;
      _errorMessage = null;
      _isLoading = true;
      _saveErrorMessage = null;
    });
    _fetchQuote();
  }

  void _selectReason(SkipReason reason) {
    setState(() {
      _selectedReason = reason;
      if (reason != SkipReason.other) {
        _otherController.clear();
      }
    });
  }

  Future<void> _submit() async {
    final reason = _selectedReason;
    if (reason == null || _quote == null || _isSaving) return;
    final draft = SkipRecordDraft(
      stock: widget.stock,
      quote: _quote,
      recordedAt: widget.clock?.call() ?? widget.recordedAt ?? DateTime.now(),
      reason: reason,
      answerCheckSetting: _answerCheckSetting,
      otherNote: reason == SkipReason.other
          ? _otherController.text.trim()
          : null,
    );
    final save = widget.onSave;
    if (save == null) {
      widget.onSubmit?.call(draft);
      return;
    }

    setState(() {
      _isSaving = true;
      _saveErrorMessage = null;
    });
    try {
      final record = await save(draft);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RecordCompletionScreen(record: record),
        ),
      );
    } on Object catch (error, stackTrace) {
      assert(() {
        debugPrint('SkipRecord save failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        return true;
      }());
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveErrorMessage = '記録を保存できませんでした。もう一度お試しください。';
      });
    }
  }

  Future<void> _openYahooFinance() async {
    var opened = false;
    try {
      opened = await widget.externalLinkService.openYahooFinance(
        widget.stock.code,
      );
    } on Object {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('リンクを開けませんでした')));
    }
  }

  Future<void> _chooseAnswerCheckPeriod() async {
    final period = await showModalBottomSheet<AnswerCheckPeriod>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) =>
          _PeriodSelectionSheet(selectedPeriod: _answerCheckSetting.period),
    );
    if (period == null || !mounted) return;

    if (period != AnswerCheckPeriod.custom) {
      setState(() => _answerCheckSetting = AnswerCheckSetting(period: period));
      return;
    }

    final firstDate = DateUtils.dateOnly(
      _recordedAt,
    ).add(const Duration(days: 1));
    final initialDate =
        _answerCheckSetting.customDate ??
        firstDate.add(const Duration(days: 29));
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate,
      firstDate: firstDate,
      lastDate: DateTime(firstDate.year + 5, firstDate.month, firstDate.day),
      helpText: '答え合わせ日を選択',
      cancelText: 'キャンセル',
      confirmText: '決定',
    );
    if (selectedDate == null || !mounted) return;
    setState(() {
      _answerCheckSetting = AnswerCheckSetting(
        period: AnswerCheckPeriod.custom,
        customDate: DateUtils.dateOnly(selectedDate),
      );
    });
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
        title: const Text('迷った株を記録'),
        centerTitle: true,
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StockInfoCard(
                stock: widget.stock,
                quote: _quote,
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                onRetry: _retryQuote,
                onYahooTap: _openYahooFinance,
              ),
              const SizedBox(height: 24),
              Text(
                'なぜ見送った？',
                key: const ValueKey('reason-section-heading'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Container(
                key: const ValueKey('reason-selection-group'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.outline),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      mainAxisExtent: 116,
                      children:
                          const [
                            _ReasonDefinition(
                              reason: SkipReason.priceTooHigh,
                              icon: Icons.trending_up_rounded,
                              label: '高いと思った',
                              iconColor: Color(0xFFE85D7B),
                              iconBackgroundColor: Color(0xFFFFE7ED),
                            ),
                            _ReasonDefinition(
                              reason: SkipReason.expectingDrop,
                              icon: Icons.trending_down_rounded,
                              label: 'まだ下がりそう',
                              iconColor: Color(0xFF438DCB),
                              iconBackgroundColor: Color(0xFFE5F2FC),
                            ),
                            _ReasonDefinition(
                              reason: SkipReason.marketConcern,
                              icon: Icons.calendar_month_rounded,
                              label: '材料・地合いが不安',
                              iconColor: Color(0xFFE58B47),
                              iconBackgroundColor: Color(0xFFFFEBD8),
                              secondaryIcon: Icons.cloud_rounded,
                              secondaryIconColor: Color(0xFF6D94B5),
                            ),
                            _ReasonDefinition(
                              reason: SkipReason.preserveFunds,
                              icon: Icons.savings_outlined,
                              label: '資金を温存したい',
                              iconColor: Color(0xFF4F7FB5),
                              iconBackgroundColor: Color(0xFFE4EEF9),
                            ),
                          ].map((definition) {
                            return _ReasonCard(
                              definition: definition,
                              isSelected: _selectedReason == definition.reason,
                              onTap: () => _selectReason(definition.reason),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 10),
                    _OtherReasonCard(
                      isSelected: _selectedReason == SkipReason.other,
                      onTap: () => _selectReason(SkipReason.other),
                    ),
                    if (_selectedReason == SkipReason.other) ...[
                      const SizedBox(height: 10),
                      TextField(
                        key: const ValueKey('other-reason-field'),
                        controller: _otherController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: '見送った理由を入力',
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: AppColors.outline,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: AppColors.outline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'いつ答え合わせする？',
                key: const ValueKey('answer-section-heading'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _DetailRow(
                key: const ValueKey('answer-check-setting'),
                icon: Icons.event_repeat_rounded,
                value: _answerCheckLabel(_answerCheckSetting),
                onTap: _chooseAnswerCheckPeriod,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_saveErrorMessage != null) ...[
              Text(
                _saveErrorMessage!,
                key: const ValueKey('save-error-message'),
                style: const TextStyle(color: Color(0xFFB44D4D)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('submit-record-button'),
                onPressed:
                    _selectedReason == null || _quote == null || _isSaving
                    ? null
                    : _submit,
                child: _isSaving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('この内容で記録する'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodSelectionSheet extends StatelessWidget {
  const _PeriodSelectionSheet({required this.selectedPeriod});

  final AnswerCheckPeriod selectedPeriod;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '答え合わせ期間',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            for (final period in AnswerCheckPeriod.values)
              ListTile(
                key: ValueKey('period-${period.name}'),
                onTap: () => Navigator.of(context).pop(period),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                title: Text(_periodLabel(period)),
                trailing: period == selectedPeriod
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.primary,
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

String _periodLabel(AnswerCheckPeriod period) {
  return switch (period) {
    AnswerCheckPeriod.threeDays => '3日後',
    AnswerCheckPeriod.oneWeek => '1週間後',
    AnswerCheckPeriod.oneMonth => '1か月後',
    AnswerCheckPeriod.threeMonths => '3か月後',
    AnswerCheckPeriod.custom => 'カスタム',
  };
}

String _answerCheckLabel(AnswerCheckSetting setting) {
  final customDate = setting.customDate;
  if (setting.period != AnswerCheckPeriod.custom || customDate == null) {
    return _periodLabel(setting.period);
  }
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${customDate.year}/${twoDigits(customDate.month)}/'
      '${twoDigits(customDate.day)}';
}

class _ReasonDefinition {
  const _ReasonDefinition({
    required this.reason,
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.iconBackgroundColor,
    this.secondaryIcon,
    this.secondaryIconColor,
  });

  final SkipReason reason;
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color iconBackgroundColor;
  final IconData? secondaryIcon;
  final Color? secondaryIconColor;
}

class _ReasonCard extends StatelessWidget {
  const _ReasonCard({
    required this.definition,
    required this.isSelected,
    required this.onTap,
  });

  final _ReasonDefinition definition;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey('reason-${definition.reason.name}'),
      color: isSelected ? const Color(0xFFE5F5EB) : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.outline,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: definition.iconBackgroundColor,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      definition.icon,
                      key: ValueKey('reason-icon-${definition.reason.name}'),
                      color: definition.iconColor,
                      size: 25,
                    ),
                    if (definition.secondaryIcon != null)
                      Positioned(
                        right: 1,
                        bottom: 2,
                        child: Icon(
                          definition.secondaryIcon,
                          key: ValueKey(
                            'reason-secondary-icon-${definition.reason.name}',
                          ),
                          color: definition.secondaryIconColor,
                          size: 15,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 7),
              Text(
                definition.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtherReasonCard extends StatelessWidget {
  const _OtherReasonCard({required this.isSelected, required this.onTap});

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('reason-other'),
      color: isSelected ? const Color(0xFFE5F5EB) : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.outline,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFEDF1ED),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.edit_note_rounded, color: Color(0xFF68806E)),
        ),
        title: const Text('その他'),
        trailing: Icon(
          isSelected ? Icons.check_circle_rounded : Icons.add_rounded,
          color: isSelected ? AppColors.primary : AppColors.mutedText,
        ),
      ),
    );
  }
}

class _StockInfoCard extends StatelessWidget {
  const _StockInfoCard({
    required this.stock,
    required this.quote,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
    required this.onYahooTap,
  });

  final StockCandidate stock;
  final StockQuote? quote;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onYahooTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final code = Text(
                stock.code,
                style: const TextStyle(color: AppColors.mutedText),
              );
              final link = TextButton.icon(
                key: const ValueKey('yahoo-finance-link'),
                onPressed: onYahooTap,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Yahoo!ファイナンス'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
              );
              if (constraints.maxWidth < 280) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    code,
                    Align(alignment: Alignment.centerRight, child: link),
                  ],
                );
              }
              return Row(children: [code, const Spacer(), link]);
            },
          ),
          const SizedBox(height: 3),
          Text(
            stock.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Row(
              children: [
                SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text('株価を取得中…'),
              ],
            )
          else if (errorMessage != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(errorMessage!)),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  key: const ValueKey('retry-stock-price'),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('株価を再取得'),
                ),
              ],
            )
          else if (quote != null)
            LayoutBuilder(
              builder: (context, constraints) {
                final price = Text(
                  _formatPrice(quote!.price),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                );
                final fetchedAt = Text(
                  '${_formatDateTime(quote!.fetchedAt.toLocal())} 取得',
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                  ),
                );
                if (constraints.maxWidth < 280) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      price,
                      const SizedBox(height: 4),
                      Align(alignment: Alignment.centerRight, child: fetchedAt),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [price, const Spacer(), fetchedAt],
                );
              },
            ),
        ],
      ),
    );
  }

  static String _formatPrice(double price) {
    final value = price.round().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < value.length; index++) {
      if (index > 0 && (value.length - index) % 3 == 0) buffer.write(',');
      buffer.write(value[index]);
    }
    return '$buffer円';
  }

  static String _formatDateTime(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${value.year}/${twoDigits(value.month)}/${twoDigits(value.day)} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    super.key,
    required this.icon,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.outline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primaryDark, size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 5),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.mutedText,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
