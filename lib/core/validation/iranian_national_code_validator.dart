/// اعتبارسنج کد ملی ایران.
class IranianNationalCodeValidator {
  const IranianNationalCodeValidator._();

  static const String testNationalCode = '1111111111';

  static String normalize(String value) {
    const persianDigits = '۰۱۲۳۴۵۶۷۸۹';
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';

    return value.trim().split('').map((character) {
      final persianIndex = persianDigits.indexOf(character);
      if (persianIndex >= 0) return persianIndex.toString();

      final arabicIndex = arabicDigits.indexOf(character);
      if (arabicIndex >= 0) return arabicIndex.toString();

      return character;
    }).join();
  }

  static bool isValid(String value, {bool allowTestCode = false}) {
    final code = normalize(value);

    if (allowTestCode && code == testNationalCode) return true;
    if (!RegExp(r'^\d{10}$').hasMatch(code)) return false;
    if (RegExp(r'^(\d)\1{9}$').hasMatch(code)) return false;

    var sum = 0;
    for (var index = 0; index < 9; index++) {
      sum += int.parse(code[index]) * (10 - index);
    }

    final remainder = sum % 11;
    final checkDigit = int.parse(code[9]);
    final expectedDigit = remainder < 2 ? remainder : 11 - remainder;

    return checkDigit == expectedDigit;
  }
}
