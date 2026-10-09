import 'package:flutter/services.dart';

import 'digit_normalizer.dart';

/// Keeps the subscriber part of an Iranian mobile number to 10 digits,
/// beginning with 9. The +98 prefix is shown separately by the field.
class IranianMobileInputFormatter extends TextInputFormatter {
  static final RegExp _digitsOnly = RegExp(r'^[0-9]*$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = normalizeDigits(newValue.text);
    if (!_digitsOnly.hasMatch(normalized) || normalized.length > 10) {
      return oldValue;
    }
    if (normalized.isNotEmpty && !normalized.startsWith('9')) {
      return oldValue;
    }

    return newValue.copyWith(text: normalized);
  }
}
