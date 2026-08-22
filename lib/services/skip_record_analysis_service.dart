import '../models/skip_record.dart';
import '../models/skip_record_draft.dart';

class SkipRecordAnalysis {
  const SkipRecordAnalysis({
    required this.totalCount,
    required this.reasonCounts,
    required this.reasonAverageChanges,
    required this.mostCommonReasons,
    required this.averageChange,
    required this.risingCount,
    required this.fallingCount,
    required this.flatCount,
  });

  final int totalCount;
  final Map<SkipReason, int> reasonCounts;
  final Map<SkipReason, double?> reasonAverageChanges;
  final List<SkipReason> mostCommonReasons;
  final double? averageChange;
  final int risingCount;
  final int fallingCount;
  final int flatCount;

  bool get hasData => totalCount > 0;

  int percentageOf(int count) =>
      totalCount == 0 ? 0 : (count / totalCount * 100).round();

  String get homeInsight {
    if (totalCount == 0) {
      return '見送りデータがたまると、あなたの判断傾向を振り返れます';
    }
    if (totalCount < 3) {
      return 'もう少し答え合わせがたまると、傾向が見えてきます';
    }
    final labels = mostCommonReasons
        .map(skipReasonLabel)
        .map((label) => '「$label」');
    if (mostCommonReasons.length == 1) {
      return '最近は${labels.first}で見送ることが多いみたい';
    }
    return '最近は${labels.join('と')}で見送ることが多いみたい';
  }
}

class SkipRecordAnalysisService {
  const SkipRecordAnalysisService({this.flatThreshold = 0.05});

  final double flatThreshold;

  SkipRecordAnalysis analyze(Iterable<SkipRecord> records) {
    final completed = records.where(_hasSavedResult).toList();
    final counts = {for (final reason in SkipReason.values) reason: 0};
    final totals = {for (final reason in SkipReason.values) reason: 0.0};
    var totalChange = 0.0;
    var rising = 0;
    var falling = 0;
    var flat = 0;

    for (final record in completed) {
      final change = record.answerChangePercent!;
      counts[record.reason] = counts[record.reason]! + 1;
      totals[record.reason] = totals[record.reason]! + change;
      totalChange += change;
      if (change > flatThreshold) {
        rising++;
      } else if (change < -flatThreshold) {
        falling++;
      } else {
        flat++;
      }
    }

    final averages = {
      for (final reason in SkipReason.values)
        reason: counts[reason] == 0 ? null : totals[reason]! / counts[reason]!,
    };
    final maxCount = counts.values.fold(
      0,
      (max, count) => count > max ? count : max,
    );
    final mostCommon = maxCount == 0
        ? <SkipReason>[]
        : SkipReason.values
              .where((reason) => counts[reason] == maxCount)
              .toList();

    return SkipRecordAnalysis(
      totalCount: completed.length,
      reasonCounts: Map.unmodifiable(counts),
      reasonAverageChanges: Map.unmodifiable(averages),
      mostCommonReasons: List.unmodifiable(mostCommon),
      averageChange: completed.isEmpty ? null : totalChange / completed.length,
      risingCount: rising,
      fallingCount: falling,
      flatCount: flat,
    );
  }

  static bool _hasSavedResult(SkipRecord record) =>
      record.answerCheckStatus == AnswerCheckStatus.completed &&
      record.answerPrice != null &&
      record.answerChangePercent != null;
}
