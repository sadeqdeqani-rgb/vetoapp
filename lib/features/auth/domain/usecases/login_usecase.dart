import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/auth_result.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository _repository;

  const LoginUseCase(this._repository);

  Future<Either<Failure, AuthResult>> call({
    required String phoneNumber,
    required String password,
  }) {
    return _repository.login(phoneNumber: phoneNumber, password: password);
  }
}
