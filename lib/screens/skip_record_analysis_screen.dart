import 'package:flutter/material.dart';

import '../models/skip_record.dart';
import '../models/skip_record_draft.dart';
import '../services/skip_record_analysis_service.dart';
import '../theme/app_theme.dart';
import '../widgets/answer_result_style.dart';

class SkipRecordAnalysisScreen extends StatelessWidget {
  const SkipRecordAnalysisScreen({super.key, required this.analysis});

  final SkipRecordAnalysis analysis;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
      ),
      title: const Text('見送り傾向'),
      centerTitle: true,
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
    ),
    body: SafeArea(
      top: false,
      child: analysis.hasData
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
              children: [
                if (analysis.totalCount < 3) ...[
                  const _GentleNotice(),
                  const SizedBox(height: 14),
                ],
                _MostCommonReasonCard(analysis: analysis),
                const SizedBox(height: 14),
                _ReasonBreakdownCard(analysis: analysis),
                const SizedBox(height: 14),
                _MovementCard(analysis: analysis),
                const SizedBox(height: 14),
                _AverageCard(analysis: analysis),
              ],
            )
          : const _AnalysisEmptyState(),
    ),
  );
}

class _GentleNotice extends StatelessWidget {
  const _GentleNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF6EE),
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Row(
      children: [
        Icon(Icons.spa_rounded, color: AppColors.primaryDark),
        SizedBox(width: 10),
        Expanded(child: Text('もう少し答え合わせがたまると、傾向が見えてきます')),
      ],
    ),
  );
}

class _MostCommonReasonCard extends StatelessWidget {
  const _MostCommonReasonCard({required this.analysis});

  final SkipRecordAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final reasons = analysis.mostCommonReasons;
    final count = analysis.reasonCounts[reasons.first]!;
    final label = reasons.map(skipReasonLabel).join('・');
    return _AnalysisCard(
      title: reasons.length == 1 ? 'いちばん多い見送り理由' : '同じくらい多い見送り理由',
      icon: Icons.lightbulb_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 5),
          Text(
            '$count件 / ${analysis.totalCount}件  (${analysis.percentageOf(count)}%)',
            style: const TextStyle(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonBreakdownCard extends StatelessWidget {
  const _ReasonBreakdownCard({required this.analysis});

  final SkipRecordAnalysis analysis;

  @override
  Widget build(BuildContext context) => _AnalysisCard(
    title: '理由別の結果',
    icon: Icons.format_list_bulleted_rounded,
    child: Column(
      children: [
        for (var index = 0; index < SkipReason.values.length; index++) ...[
          _ReasonResultRow(
            reason: SkipReason.values[index],
            count: analysis.reasonCounts[SkipReason.values[index]]!,
            average: analysis.reasonAverageChanges[SkipReason.values[index]],
          ),
          if (index != SkipReason.values.length - 1)
            const Divider(height: 24, color: AppColors.outline),
        ],
      ],
    ),
  );
}

class _ReasonResultRow extends StatelessWidget {
  const _ReasonResultRow({
    required this.reason,
    required this.count,
    required this.average,
  });

  final SkipReason reason;
  final int count;
  final double? average;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: _reasonColor(reason).withValues(alpha: 0.13),
          shape: BoxShape.circle,
        ),
        child: Icon(_reasonIcon(reason), color: _reasonColor(reason), size: 19),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(skipReasonLabel(reason), overflow: TextOverflow.ellipsis),
            Text('$count件', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      const SizedBox(width: 8),
      Text(
        average == null ? 'データなし' : formatAnswerPercent(average!),
        key: ValueKey('reason-average-${reason.name}'),
        style: TextStyle(
          color: average == null
              ? AppColors.mutedText
              : answerResultColor(average!),
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );
}

class _MovementCard extends StatelessWidget {
  const _MovementCard({required this.analysis});

  final SkipRecordAnalysis analysis;

  @override
  Widget build(BuildContext context) => _AnalysisCard(
    title: '見送った株のその後',
    icon: Icons.stacked_bar_chart_rounded,
    child: Column(
      children: [
        _MovementRow(
          label: '上昇',
          count: analysis.risingCount,
          percentage: analysis.percentageOf(analysis.risingCount),
          color: const Color(0xFFE15F78),
        ),
        const SizedBox(height: 12),
        _MovementRow(
          label: '下落',
          count: analysis.fallingCount,
          percentage: analysis.percentageOf(analysis.fallingCount),
          color: const Color(0xFF438DCB),
        ),
        const SizedBox(height: 12),
        _MovementRow(
          label: '横ばい',
          count: analysis.flatCount,
          percentage: analysis.percentageOf(analysis.flatCount),
          color: AppColors.mutedText,
        ),
      ],
    ),
  );
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({
    required this.label,
    required this.count,
    required this.percentage,
    required this.color,
  });

  final String label;
  final int count;
  final int percentage;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 52, child: Text(label)),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 9,
            backgroundColor: const Color(0xFFEEE9E2),
            color: color,
          ),
        ),
      ),
      const SizedBox(width: 10),
      SizedBox(
        width: 67,
        child: Text(
          '$percentage%  $count件',
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
}

class _AverageCard extends StatelessWidget {
  const _AverageCard({required this.analysis});

  final SkipRecordAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final average = analysis.averageChange!;
    return _AnalysisCard(
      title: '全体の平均',
      icon: Icons.show_chart_rounded,
      child: RichText(
        key: const ValueKey('overall-average-change'),
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyLarge,
          children: [
            const TextSpan(text: '見送った株は平均 '),
            TextSpan(
              text: formatAnswerPercent(average),
              style: TextStyle(
                color: answerResultColor(average),
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const TextSpan(text: ' でした'),
          ],
        ),
      ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.outline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primaryDark, size: 21),
            const SizedBox(width: 9),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

class _AnalysisEmptyState extends StatelessWidget {
  const _AnalysisEmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.spa_rounded, size: 52, color: AppColors.primaryDark),
          const SizedBox(height: 18),
          Text(
            'まだ分析できる記録はありません',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            '答え合わせがたまると、見送り傾向が見えてきます',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.mutedText),
          ),
        ],
      ),
    ),
  );
}

Color _reasonColor(SkipReason reason) => switch (reason) {
  SkipReason.priceTooHigh => const Color(0xFFE85D7B),
  SkipReason.expectingDrop => const Color(0xFF438DCB),
  SkipReason.marketConcern => const Color(0xFFE58B47),
  SkipReason.preserveFunds => const Color(0xFF4F7FB5),
  SkipReason.other => AppColors.primaryDark,
};

IconData _reasonIcon(SkipReason reason) => switch (reason) {
  SkipReason.priceTooHigh => Icons.trending_up_rounded,
  SkipReason.expectingDrop => Icons.trending_down_rounded,
  SkipReason.marketConcern => Icons.cloud_rounded,
  SkipReason.preserveFunds => Icons.savings_outlined,
  SkipReason.other => Icons.more_horiz_rounded,
};
