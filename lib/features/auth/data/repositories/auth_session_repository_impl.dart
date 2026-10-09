import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_session_repository.dart';
import '../datasources/auth_local_data_source_impl.dart';

class AuthSessionRepositoryImpl implements AuthSessionRepository {
  const AuthSessionRepositoryImpl(this._localDataSource);

  final AuthLocalDataSource _localDataSource;

  static const _modeKey = 'auth_session_mode';
  static const _tokenKey = 'auth_session_token';
  static const _userIdKey = 'auth_user_id';

  @override
  Future<AuthSession> readSession() async {
    final mode = await _localDataSource.read(_modeKey);
    // Interactive preview is intentionally scoped to the current app process.
    // Remove the legacy persisted guest marker so an app restart always opens
    // the gateway instead of silently returning to the preview.
    if (mode == '2') {
      await clearSession();
      return const AuthSession(mode: AuthSessionMode.unauthenticated);
    }

    final sessionMode = switch (mode) {
      '1' => AuthSessionMode.authenticated,
      _ => AuthSessionMode.unauthenticated,
    };

    return AuthSession(
      mode: sessionMode,
      sessionToken: await _localDataSource.read(_tokenKey),
      userId: await _localDataSource.read(_userIdKey),
    );
  }

  @override
  Future<void> saveAuthenticatedSession({
    required String sessionToken,
    required String userId,
  }) async {
    await _localDataSource.write(_modeKey, '1');
    await _localDataSource.write(_tokenKey, sessionToken);
    await _localDataSource.write(_userIdKey, userId);
  }

  @override
  Future<void> saveGuestSession() async {
    // Guest preview is ephemeral; only the in-memory AuthCubit state marks it.
    // Clearing stale persisted values also handles upgrades from older builds.
    await _localDataSource.delete(_tokenKey);
    await _localDataSource.delete(_userIdKey);
    await _localDataSource.delete(_modeKey);
  }

  @override
  Future<void> clearSession() async {
    await _localDataSource.delete(_modeKey);
    await _localDataSource.delete(_tokenKey);
    await _localDataSource.delete(_userIdKey);
  }
}
