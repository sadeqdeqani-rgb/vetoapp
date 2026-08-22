import '../repositories/auth_session_repository.dart';

class SaveGuestSessionUseCase {
  const SaveGuestSessionUseCase(this._repository);

  final AuthSessionRepository _repository;

  Future<void> call() => _repository.saveGuestSession();
}
