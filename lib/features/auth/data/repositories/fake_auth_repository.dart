import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/validation/digit_normalizer.dart';
import '../../domain/entities/auth_result.dart';
import '../../domain/repositories/auth_repository.dart';

/// پیاده‌سازی موقت و فقط برای تست جریان ورود.
///
/// این کلاس عمداً فقط به قرارداد Domain یعنی [AuthRepository] وابسته است.
/// برای اتصال API، آن را حذف نکنید؛ کافی است ثبت [AuthRepository] در فایل DI
/// با [AuthRepositoryImpl] انجام شود. در آن حالت هیچ صفحه یا Cubit تغییری
/// نخواهد کرد.
@Deprecated(
  'فقط برای تست فرانت؛ در محیط API از AuthRepositoryImpl استفاده شود.',
)
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

    if (normalizeDigits(phoneNumber.trim()) != validUsername ||
        normalizeDigits(password) != validPassword) {
      return const Left(AuthFailure('نام کاربری یا رمز عبور صحیح نیست.'));
    }

    return const Right(
      AuthResult(sessionToken: 'fake-session-token', userId: 'fake-user-1'),
    );
  }
}
