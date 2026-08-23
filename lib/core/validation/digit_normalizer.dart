/// تبدیل ارقام فارسی و عربی به ارقام لاتین برای اعتبارسنجی و ارسال به API.
String normalizeDigits(String value) {
  const persianDigits = '۰۱۲۳۴۵۶۷۸۹';
  const arabicDigits = '٠١٢٣٤٥٦٧٨٩';

  return value.split('').map((character) {
    final persianIndex = persianDigits.indexOf(character);
    if (persianIndex >= 0) return persianIndex.toString();

    final arabicIndex = arabicDigits.indexOf(character);
    if (arabicIndex >= 0) return arabicIndex.toString();

    return character;
  }).join();
}
