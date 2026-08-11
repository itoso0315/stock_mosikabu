import '../models/skip_record.dart';
import '../models/skip_record_draft.dart';
import 'stock_search_service.dart';

enum ReviewResultFilter { all, positive, negative, flat }

enum ReviewSortOrder { newest, oldest, highestReturn, lowestReturn }

class ReviewFilter {
  const ReviewFilter({
    this.query = '',
    this.result = ReviewResultFilter.all,
    this.reason,
    this.sortOrder = ReviewSortOrder.newest,
  });

  final String query;
  final ReviewResultFilter result;
  final SkipReason? reason;
  final ReviewSortOrder sortOrder;

  bool get hasNonDefaultOptions =>
      result != ReviewResultFilter.all ||
      reason != null ||
      sortOrder != ReviewSortOrder.newest;

  bool get isFiltering => query.trim().isNotEmpty || hasNonDefaultOptions;

  ReviewFilter copyWith({
    String? query,
    ReviewResultFilter? result,
    SkipReason? reason,
    bool clearReason = false,
    ReviewSortOrder? sortOrder,
  }) => ReviewFilter(
    query: query ?? this.query,
    result: result ?? this.result,
    reason: clearReason ? null : reason ?? this.reason,
    sortOrder: sortOrder ?? this.sortOrder,
  );
}

class ReviewFilterService {
  const ReviewFilterService({
    this.flatThreshold = 0.05,
    this.searchService = const StockSearchService(),
  });

  final double flatThreshold;
  final StockSearchService searchService;

  List<SkipRecord> completedRecords(Iterable<SkipRecord> records) => records
      .where(
        (record) =>
            record.answerCheckStatus == AnswerCheckStatus.completed &&
            record.answerPrice != null &&
            record.answerChangePercent != null,
      )
      .toList();

  List<SkipRecord> apply(Iterable<SkipRecord> records, ReviewFilter filter) {
    final query = searchService.normalize(filter.query);
    final result = completedRecords(records).where((record) {
      final matchesQuery =
          query.isEmpty ||
          searchService.normalize(record.stockName).contains(query) ||
          searchService.normalize(record.stockCode).contains(query);
      if (!matchesQuery) return false;
      if (filter.reason != null && record.reason != filter.reason) return false;
      return _matchesResult(record.answerChangePercent!, filter.result);
    }).toList();

    result.sort(
      (a, b) => switch (filter.sortOrder) {
        ReviewSortOrder.newest => _resultDate(b).compareTo(_resultDate(a)),
        ReviewSortOrder.oldest => _resultDate(a).compareTo(_resultDate(b)),
        ReviewSortOrder.highestReturn => b.answerChangePercent!.compareTo(
          a.answerChangePercent!,
        ),
        ReviewSortOrder.lowestReturn => a.answerChangePercent!.compareTo(
          b.answerChangePercent!,
        ),
      },
    );
    return result;
  }

  bool _matchesResult(double percent, ReviewResultFilter filter) =>
      switch (filter) {
        ReviewResultFilter.all => true,
        ReviewResultFilter.positive => percent > flatThreshold,
        ReviewResultFilter.negative => percent < -flatThreshold,
        ReviewResultFilter.flat => percent.abs() <= flatThreshold,
      };

  static DateTime _resultDate(SkipRecord record) =>
      record.answeredAt ?? record.recordedAt;
}

String reviewResultFilterLabel(ReviewResultFilter filter) => switch (filter) {
  ReviewResultFilter.all => 'すべて',
  ReviewResultFilter.positive => 'プラス',
  ReviewResultFilter.negative => 'マイナス',
  ReviewResultFilter.flat => '横ばい',
};

String reviewSortOrderLabel(ReviewSortOrder order) => switch (order) {
  ReviewSortOrder.newest => '新しい順',
  ReviewSortOrder.oldest => '古い順',
  ReviewSortOrder.highestReturn => '騰落率が高い順',
  ReviewSortOrder.lowestReturn => '騰落率が低い順',
};
