import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

Color answerResultColor(double percent) {
  if (percent > 0.05) return const Color(0xFFE15F78);
  if (percent < -0.05) return const Color(0xFF438DCB);
  return AppColors.mutedText;
}

Color answerResultBackgroundColor(double percent) {
  if (percent > 0.05) return const Color(0xFFFFE7ED);
  if (percent < -0.05) return const Color(0xFFE5F2FC);
  return const Color(0xFFEEEEEA);
}

String formatAnswerPercent(double percent) =>
    '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(1)}%';

class AnswerPercentPill extends StatelessWidget {
  const AnswerPercentPill({super.key, required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    final state = percent > 0.05
        ? 'positive'
        : percent < -0.05
        ? 'negative'
        : 'neutral';
    return Container(
      key: ValueKey('answer-percent-pill-$state'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: answerResultBackgroundColor(percent),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        formatAnswerPercent(percent),
        style: TextStyle(
          color: answerResultColor(percent),
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
