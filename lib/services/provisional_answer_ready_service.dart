import '../models/skip_record.dart';
import '../models/skip_record_draft.dart';
import 'market_calendar_service.dart';

class ProvisionalAnswerReadyService {
  const ProvisionalAnswerReadyService({
    this.marketCalendar = const MarketCalendarService(),
  });

  final MarketCalendarService marketCalendar;

  List<SkipRecord> readyRecords(
    List<SkipRecord> records,
    DateTime now, {
    Map<String, DateTime> answerDateOverrides = const {},
  }) {
    final today = _dateOnly(now);
    final ready = records.where((record) {
      return record.answerCheckStatus == AnswerCheckStatus.pending &&
          !answerDate(
            record,
            override: answerDateOverrides[record.id],
          ).isAfter(today);
    }).toList();
    ready.sort(
      (a, b) => answerDate(
        a,
        override: answerDateOverrides[a.id],
      ).compareTo(answerDate(b, override: answerDateOverrides[b.id])),
    );
    return ready;
  }

  DateTime answerDate(SkipRecord record, {DateTime? override}) {
    if (override != null) return _dateOnly(override);
    final savedEffective = record.effectiveAnswerDate;
    if (savedEffective != null) return _dateOnly(savedEffective);
    return marketCalendar.effectiveAnswerDate(requestedAnswerDate(record));
  }

  DateTime requestedAnswerDate(SkipRecord record) {
    final savedRequested = record.requestedAnswerDate;
    if (savedRequested != null) return _dateOnly(savedRequested);
    final recordedDate = _dateOnly(record.recordedAt);
    final setting = record.answerCheckSetting;
    return switch (setting.period) {
      AnswerCheckPeriod.threeDays => recordedDate.add(const Duration(days: 3)),
      AnswerCheckPeriod.oneWeek => recordedDate.add(const Duration(days: 7)),
      AnswerCheckPeriod.oneMonth => _addMonths(recordedDate, 1),
      AnswerCheckPeriod.threeMonths => _addMonths(recordedDate, 3),
      AnswerCheckPeriod.custom => _dateOnly(setting.customDate ?? recordedDate),
    };
  }

  static DateTime _addMonths(DateTime date, int months) {
    final targetMonth = date.month + months;
    final firstOfFollowingMonth = DateTime(date.year, targetMonth + 1);
    final lastDay = firstOfFollowingMonth.subtract(const Duration(days: 1)).day;
    return DateTime(date.year, targetMonth, date.day.clamp(1, lastDay));
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
