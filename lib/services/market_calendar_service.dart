class MarketCalendarService {
  const MarketCalendarService();

  DateTime effectiveAnswerDate(DateTime requestedDate) {
    var date = _dateOnly(requestedDate);
    while (!isTradingDay(date)) {
      date = date.add(const Duration(days: 1));
    }
    return date;
  }

  bool isTradingDay(DateTime date) {
    final value = _dateOnly(date);
    if (value.weekday == DateTime.saturday ||
        value.weekday == DateTime.sunday) {
      return false;
    }
    if ((value.month == 12 && value.day == 31) ||
        (value.month == 1 && value.day <= 3)) {
      return false;
    }
    return !_japaneseHolidays(value.year).contains(value);
  }

  Set<DateTime> _japaneseHolidays(int year) {
    final holidays = <DateTime>{
      DateTime(year, 1, 1),
      _nthMonday(year, 1, 2),
      DateTime(year, 2, 11),
      if (year >= 2020) DateTime(year, 2, 23),
      DateTime(year, 3, _vernalEquinoxDay(year)),
      DateTime(year, 4, 29),
      DateTime(year, 5, 3),
      DateTime(year, 5, 4),
      DateTime(year, 5, 5),
      _nthMonday(year, 7, 3),
      DateTime(year, 8, 11),
      _nthMonday(year, 9, 3),
      DateTime(year, 9, _autumnalEquinoxDay(year)),
      _nthMonday(year, 10, 2),
      DateTime(year, 11, 3),
      DateTime(year, 11, 23),
    };

    for (final holiday in [...holidays]) {
      if (holiday.weekday != DateTime.sunday) continue;
      var substitute = holiday.add(const Duration(days: 1));
      while (holidays.contains(substitute)) {
        substitute = substitute.add(const Duration(days: 1));
      }
      holidays.add(substitute);
    }

    for (
      var day = DateTime(year, 1, 2);
      day.year == year;
      day = day.add(const Duration(days: 1))
    ) {
      if (day.weekday == DateTime.sunday || holidays.contains(day)) continue;
      if (holidays.contains(day.subtract(const Duration(days: 1))) &&
          holidays.contains(day.add(const Duration(days: 1)))) {
        holidays.add(day);
      }
    }
    return holidays;
  }

  static DateTime _nthMonday(int year, int month, int nth) {
    final first = DateTime(year, month, 1);
    final offset = (DateTime.monday - first.weekday + 7) % 7;
    return DateTime(year, month, 1 + offset + (nth - 1) * 7);
  }

  static int _vernalEquinoxDay(int year) =>
      (20.8431 + 0.242194 * (year - 1980) - ((year - 1980) ~/ 4)).floor();

  static int _autumnalEquinoxDay(int year) =>
      (23.2488 + 0.242194 * (year - 1980) - ((year - 1980) ~/ 4)).floor();

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
