import 'package:flutter/foundation.dart';

class AuthSessionExpiredNotifier extends ChangeNotifier {
  void expire() {
    notifyListeners();
  }
}
