import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/auth_result.dart';
import '../../domain/repositories/auth_repository.dart';

/// Repository موقت برای تست جریان ورود.
///
/// بعداً می‌توان این repository را در DI با AuthRepositoryImpl جایگزین کرد،
/// بدون اینکه LoginScreen یا AuthCubit تغییر اساسی کند.
class FakeAuthRepository implements AuthRepository {
  /// شماره موبایل معتبر برای تست ورود.
  static const String validUsername = '09123456789';

  /// رمز عبور معتبر برای تست ورود.
  static const String validPassword = '12345678';

  const FakeAuthRepository();

  @override
  Future<Either<Failure, AuthResult>> login({
    required String phoneNumber,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (phoneNumber.trim() != validUsername || password != validPassword) {
      return const Left(AuthFailure('نام کاربری یا رمز عبور صحیح نیست.'));
    }

    return const Right(
      AuthResult(sessionToken: 'fake-session-token', userId: 'fake-user-1'),
    );
  }
}
