import '../repositories/auth_session_repository.dart';

class ClearAuthSessionUseCase {
  const ClearAuthSessionUseCase(this._repository);

  final AuthSessionRepository _repository;

  Future<void> call() => _repository.clearSession();
}
