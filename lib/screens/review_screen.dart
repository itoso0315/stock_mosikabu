import 'package:flutter/material.dart';

import '../models/answer_close.dart';
import '../models/skip_record.dart';
import '../models/skip_record_draft.dart';
import '../services/answer_price_service.dart';
import '../services/review_filter_service.dart';
import '../theme/app_theme.dart';
import '../widgets/answer_result_style.dart';
import '../widgets/stock_icon.dart';
import 'answer_result_screen.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.records,
    required this.answerPriceService,
    required this.onComplete,
    this.filterService = const ReviewFilterService(),
  });

  final List<SkipRecord> records;
  final AnswerPriceService answerPriceService;
  final Future<SkipRecord> Function(SkipRecord, AnswerClose) onComplete;
  final ReviewFilterService filterService;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _searchController = TextEditingController();
  ReviewFilter _filter = const ReviewFilter();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openResult(BuildContext context, SkipRecord record) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AnswerResultScreen(
          record: record,
          answerDate: record.answerPriceDate ?? record.recordedAt,
          answerPriceService: widget.answerPriceService,
          onComplete: widget.onComplete,
        ),
      ),
    );
  }

  Future<void> _openFilters() async {
    final selected = await showModalBottomSheet<ReviewFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ReviewFilterSheet(initialFilter: _filter),
    );
    if (selected == null || !mounted) return;
    _searchController.text = selected.query;
    setState(() => _filter = selected);
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() => _filter = const ReviewFilter());
  }

  @override
  Widget build(BuildContext context) {
    final completed = widget.filterService.completedRecords(widget.records);
    final visible = widget.filterService.apply(widget.records, _filter);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 10, 8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '振り返り',
                  key: const ValueKey('review-title'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: _FilterButton(
                    isActive: _filter.hasNonDefaultOptions,
                    onTap: _openFilters,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              key: const ValueKey('review-search-field'),
              controller: _searchController,
              onChanged: (query) => setState(() {
                _filter = _filter.copyWith(query: query);
              }),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '銘柄名・コードで検索',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        key: const ValueKey('clear-review-search'),
                        tooltip: '検索をクリア',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _filter = _filter.copyWith(query: ''));
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: AppColors.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: AppColors.outline),
                ),
              ),
            ),
          ),
          Expanded(
            child: completed.isEmpty
                ? const _ReviewEmptyState()
                : visible.isEmpty
                ? _NoFilterMatches(onReset: _resetFilters)
                : ListView.separated(
                    key: const ValueKey('review-list'),
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 28),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final record = visible[index];
                      return _ReviewCard(
                        record: record,
                        onTap: () => _openResult(context, record),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.isActive, required this.onTap});

  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 44,
    child: Stack(
      children: [
        Positioned.fill(
          child: IconButton(
            key: const ValueKey('open-review-filters'),
            tooltip: '絞り込み・並び替え',
            onPressed: onTap,
            icon: const Icon(Icons.filter_alt_outlined),
          ),
        ),
        if (isActive)
          const Positioned(
            key: ValueKey('review-filter-active'),
            right: 5,
            top: 5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(dimension: 8),
            ),
          ),
      ],
    ),
  );
}

class _NoFilterMatches extends StatelessWidget {
  const _NoFilterMatches({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 48,
            color: AppColors.mutedText,
          ),
          const SizedBox(height: 16),
          Text(
            '条件に合う振り返りがありません',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            '検索条件やフィルターを変えてみてください',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.mutedText),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onReset, child: const Text('条件をリセット')),
        ],
      ),
    ),
  );
}

class _ReviewFilterSheet extends StatefulWidget {
  const _ReviewFilterSheet({required this.initialFilter});

  final ReviewFilter initialFilter;

  @override
  State<_ReviewFilterSheet> createState() => _ReviewFilterSheetState();
}

class _ReviewFilterSheetState extends State<_ReviewFilterSheet> {
  late ReviewFilter _filter = widget.initialFilter;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '絞り込み・並び替え',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 22),
          const _FilterHeading('結果'),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final result in ReviewResultFilter.values)
                ChoiceChip(
                  key: ValueKey('result-filter-${result.name}'),
                  label: Text(reviewResultFilterLabel(result)),
                  selected: _filter.result == result,
                  onSelected: (_) => setState(() {
                    _filter = _filter.copyWith(result: result);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const _FilterHeading('見送り理由'),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                key: const ValueKey('reason-filter-all'),
                label: const Text('すべて'),
                selected: _filter.reason == null,
                onSelected: (_) => setState(() {
                  _filter = _filter.copyWith(clearReason: true);
                }),
              ),
              for (final reason in SkipReason.values)
                ChoiceChip(
                  key: ValueKey('reason-filter-${reason.name}'),
                  label: Text(skipReasonLabel(reason)),
                  selected: _filter.reason == reason,
                  onSelected: (_) => setState(() {
                    _filter = _filter.copyWith(reason: reason);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const _FilterHeading('並び順'),
          const SizedBox(height: 9),
          DropdownButtonFormField<ReviewSortOrder>(
            key: const ValueKey('review-sort-order'),
            initialValue: _filter.sortOrder,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.outline),
              ),
            ),
            items: [
              for (final order in ReviewSortOrder.values)
                DropdownMenuItem(
                  value: order,
                  child: Text(reviewSortOrderLabel(order)),
                ),
            ],
            onChanged: (order) {
              if (order == null) return;
              setState(() => _filter = _filter.copyWith(sortOrder: order));
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('reset-review-filters'),
                  onPressed: () =>
                      Navigator.of(context).pop(const ReviewFilter()),
                  child: const Text('リセット'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('apply-review-filters'),
                  onPressed: () => Navigator.of(context).pop(_filter),
                  child: const Text('適用'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _FilterHeading extends StatelessWidget {
  const _FilterHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      Text(label, style: Theme.of(context).textTheme.titleMedium);
}

class _ReviewEmptyState extends StatelessWidget {
  const _ReviewEmptyState();

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
              Icons.auto_stories_rounded,
              color: AppColors.primaryDark,
              size: 34,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'まだ振り返れる記録はありません',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            '答え合わせが終わると、ここに記録が並びます',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.mutedText),
          ),
        ],
      ),
    ),
  );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.record, required this.onTap});

  final SkipRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    key: ValueKey('review-record-${record.id}'),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StockIcon(
                  key: ValueKey('review-stock-icon-${record.id}'),
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
                      const SizedBox(height: 3),
                      Text(
                        record.stockCode,
                        style: const TextStyle(color: AppColors.mutedText),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AnswerPercentPill(percent: record.answerChangePercent!),
              ],
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.reasonLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
        ),
      ),
    ),
  );

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
