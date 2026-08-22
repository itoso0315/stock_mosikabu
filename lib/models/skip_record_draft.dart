import 'stock_candidate.dart';
import 'stock_quote.dart';

enum SkipReason {
  priceTooHigh,
  expectingDrop,
  marketConcern,
  preserveFunds,
  other,
}

enum AnswerCheckPeriod { threeDays, oneWeek, oneMonth, threeMonths, custom }

class AnswerCheckSetting {
  const AnswerCheckSetting({required this.period, this.customDate})
    : assert(
        period == AnswerCheckPeriod.custom || customDate == null,
        'customDate is only available for the custom period',
      );

  const AnswerCheckSetting.oneMonth()
    : period = AnswerCheckPeriod.oneMonth,
      customDate = null;

  final AnswerCheckPeriod period;
  final DateTime? customDate;
}

class SkipRecordDraft {
  const SkipRecordDraft({
    required this.stock,
    required this.quote,
    required this.recordedAt,
    required this.reason,
    required this.answerCheckSetting,
    this.otherNote,
  });

  final StockCandidate stock;
  final StockQuote? quote;
  final DateTime recordedAt;
  final SkipReason reason;
  final AnswerCheckSetting answerCheckSetting;
  final String? otherNote;
}
