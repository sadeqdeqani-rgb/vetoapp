class AuthSession {
  const AuthSession({
    required this.mode,
    this.sessionToken,
    this.userId,
  });

  final AuthSessionMode mode;
  final String? sessionToken;
  final String? userId;

  bool get isAuthenticated => mode == AuthSessionMode.authenticated;
  bool get isGuest => mode == AuthSessionMode.guest;
}

enum AuthSessionMode { unauthenticated, authenticated, guest }
