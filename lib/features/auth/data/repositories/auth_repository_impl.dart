import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/auth_result.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/login_request_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;

  const AuthRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, AuthResult>> login({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      final result = await _remoteDataSource.login(
        LoginRequestModel(phoneNumber: phoneNumber, password: password),
      );

      final sessionToken = result['session_token'];
      final userId = result['user_id'];

      if (sessionToken is! String || sessionToken.isEmpty) {
        return const Left(ServerFailure('توکن نشست در پاسخ سرور وجود ندارد.'));
      }

      if (userId is! String || userId.isEmpty) {
        return const Left(
          ServerFailure('شناسه کاربر در پاسخ سرور وجود ندارد.'),
        );
      }

      final expiresAtValue = result['expires_at'];
      return Right(
        AuthResult(
          sessionToken: sessionToken,
          userId: userId,
          expiresAt: expiresAtValue is String
              ? DateTime.tryParse(expiresAtValue)
              : null,
        ),
      );
    } on Failure catch (failure) {
      return Left(failure);
    } catch (_) {
      return const Left(ServerFailure('خطای پیش‌بینی‌نشده رخ داد.'));
    }
  }
}
