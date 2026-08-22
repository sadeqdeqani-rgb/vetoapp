import '../repositories/auth_session_repository.dart';

class SaveAuthenticatedSessionUseCase {
  const SaveAuthenticatedSessionUseCase(this._repository);

  final AuthSessionRepository _repository;

  Future<void> call({
    required String sessionToken,
    required String userId,
  }) => _repository.saveAuthenticatedSession(
    sessionToken: sessionToken,
    userId: userId,
  );
}
