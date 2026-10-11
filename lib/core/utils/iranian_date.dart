/// Conversions and readable formatting for Iranian Jalali dates.
class IranianDate {
  IranianDate._();

  static const months = <String>[
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  static const _persianDigits = '۰۱۲۳۴۵۶۷۸۹';

  static String persianDigits(String value) =>
      value.split('').map((c) {
        final digit = int.tryParse(c);
        return digit == null ? c : _persianDigits[digit];
      }).join();

  static String persianNumber(int value) => persianDigits(value.toString());

  static String formatGregorian(DateTime date) {
    final (year, month, day) = _toJalali(date.year, date.month, date.day);
    return '${persianNumber(day)} ${months[month - 1]} ${persianNumber(year)}';
  }

  /// Converts a Jalali date to a Gregorian date-only value (`yyyy-MM-dd`).
  static String? jalaliToGregorianIso({
    required int year,
    required int month,
    required int day,
  }) {
    if (year < 1200 ||
        year > 1600 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > (month <= 6 ? 31 : 30)) {
      return null;
    }
    final jy = year - 979;
    var days = 365 * jy + (jy ~/ 33) * 8 + ((jy % 33 + 3) ~/ 4);
    days += month <= 6 ? (month - 1) * 31 : 186 + (month - 7) * 30;
    days += day - 1 + 79;

    var gy = 1600 + 400 * (days ~/ 146097);
    days %= 146097;
    var leap = true;
    if (days >= 36525) {
      days--;
      gy += 100 * (days ~/ 36524);
      days %= 36524;
      if (days >= 365) days++;
    }
    gy += 4 * (days ~/ 1461);
    days %= 1461;
    if (days >= 366) {
      leap = false;
      days--;
      gy += days ~/ 365;
      days %= 365;
    }
    final monthDays = <int>[
      31,
      leap ? 29 : 28,
      31,
      30,
      31,
      30,
      31,
      31,
      30,
      31,
      30,
      31,
    ];
    var gm = 1;
    while (gm <= 12 && days >= monthDays[gm - 1]) {
      days -= monthDays[gm - 1];
      gm++;
    }
    final gd = days + 1;
    final roundTrip = _toJalali(gy, gm, gd);
    if (roundTrip != (year, month, day)) return null;
    return '${gy.toString().padLeft(4, '0')}-${gm.toString().padLeft(2, '0')}-${gd.toString().padLeft(2, '0')}';
  }

  static (int, int, int) _toJalali(int gy, int gm, int gd) {
    const cumulative = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
    var jy = gy <= 1600 ? 0 : 979;
    gy -= gy <= 1600 ? 621 : 1600;
    final gy2 = gm > 2 ? gy + 1 : gy;
    var days =
        365 * gy +
        ((gy2 + 3) ~/ 4) -
        ((gy2 + 99) ~/ 100) +
        ((gy2 + 399) ~/ 400) -
        80 +
        gd +
        cumulative[gm - 1];
    jy += 33 * (days ~/ 12053);
    days %= 12053;
    jy += 4 * (days ~/ 1461);
    days %= 1461;
    if (days > 365) {
      jy += (days - 1) ~/ 365;
      days = (days - 1) % 365;
    }
    final jm = days < 186 ? 1 + days ~/ 31 : 7 + (days - 186) ~/ 30;
    final jd = 1 + (days < 186 ? days % 31 : (days - 186) % 30);
    return (jy, jm, jd);
  }
}
