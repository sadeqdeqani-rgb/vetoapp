import '../entities/auth_session.dart';

abstract interface class AuthSessionRepository {
  Future<AuthSession> readSession();
  Future<void> saveAuthenticatedSession({
    required String sessionToken,
    required String userId,
  });
  Future<void> saveGuestSession();
  Future<void> clearSession();
}
