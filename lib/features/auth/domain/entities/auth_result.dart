class AuthResult {
  final String sessionToken;
  final String userId;
  final DateTime? expiresAt;

  const AuthResult({
    required this.sessionToken,
    required this.userId,
    this.expiresAt,
  });
}
