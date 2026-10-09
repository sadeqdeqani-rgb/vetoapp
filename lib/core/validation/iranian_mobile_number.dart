import 'digit_normalizer.dart';

/// Normalizes Iranian mobile numbers to the API's canonical E.164 form.
///
/// UI fields with a fixed +98 prefix should call this with the ten digit
/// subscriber number; older callers may pass a national or international
/// number and receive the same canonical representation.
String normalizeIranianMobileNumber(String value) {
  var phone = normalizeDigits(value.trim()).replaceAll(RegExp(r'[\s\-()]'), '');
  if (phone.startsWith('+')) phone = phone.substring(1);
  if (phone.startsWith('0098')) {
    phone = phone.substring(2);
  } else if (phone.startsWith('98')) {
    // Already has the country code.
  } else if (phone.startsWith('09') && phone.length == 11) {
    phone = '98${phone.substring(1)}';
  } else if (RegExp(r'^9\d{9}$').hasMatch(phone)) {
    phone = '98$phone';
  }

  if (!RegExp(r'^989\d{9}$').hasMatch(phone)) {
    throw const FormatException('شمارهٔ تلفن همراه معتبر نیست.');
  }
  return '+$phone';
}

bool isIranianMobileSubscriberNumber(String value) =>
    RegExp(r'^9\d{9}$').hasMatch(normalizeDigits(value.trim()));
