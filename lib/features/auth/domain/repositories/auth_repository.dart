import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/auth_result.dart';

abstract interface class AuthRepository {
  Future<Either<Failure, AuthResult>> login({
    required String phoneNumber,
    required String password,
  });
}
