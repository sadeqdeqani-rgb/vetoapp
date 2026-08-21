import 'package:flutter/services.dart';

abstract final class ScreenProtection {
  static const MethodChannel _channel = MethodChannel(
    'ir.vetoapp/screen_protection',
  );

  static Future<void> enable() async {
    try {
      await _channel.invokeMethod<void>('enableSecureFlag');
    } on PlatformException {
      // محافظت از صفحه در همه پلتفرم‌ها معادل یکسان ندارد.
    }
  }

  static Future<void> disable() async {
    try {
      await _channel.invokeMethod<void>('disableSecureFlag');
    } on PlatformException {
      // Fail silently.
    }
  }
}
