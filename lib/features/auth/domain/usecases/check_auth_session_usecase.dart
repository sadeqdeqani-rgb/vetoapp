import '../entities/auth_session.dart';
import '../repositories/auth_session_repository.dart';

class CheckAuthSessionUseCase {
  const CheckAuthSessionUseCase(this._repository);

  final AuthSessionRepository _repository;

  Future<AuthSession> call() => _repository.readSession();
}
