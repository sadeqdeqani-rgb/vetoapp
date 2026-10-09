typedef AppBackHandler = bool Function();

class AppBackHandlerRegistry {
  AppBackHandlerRegistry._();

  static Object? _owner;
  static AppBackHandler? _handler;

  static void register(Object owner, AppBackHandler handler) {
    _owner = owner;
    _handler = handler;
  }

  static void unregister(Object owner) {
    if (identical(_owner, owner)) {
      _owner = null;
      _handler = null;
    }
  }

  static bool handle() => _handler?.call() ?? false;
}
