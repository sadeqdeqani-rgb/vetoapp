import '../../../../core/errors/failures.dart';
import '../../domain/entities/otp_challenge.dart';
import 'otp_remote_data_source.dart';

/// OTP فیک مخصوص مشاهدهٔ کامل فلوی ثبت‌نام در محیط توسعه.
///
/// فقط registration را فیک می‌کند و سایر کاربردهای OTP را به API واقعی می‌سپارد.
class FrontendTestOtpDataSource implements OtpRemoteDataSource {
  FrontendTestOtpDataSource(this._realDataSource);

  static const testRegistrationPhone = '0912345678';
  static const legacyTestRegistrationPhone = '09123456789';
  static const testRegistrationOtp = '123456';

  final OtpRemoteDataSource _realDataSource;

  bool _isTestRegistration(String phoneNumber, OtpPurpose purpose) =>
      purpose == OtpPurpose.registration &&
      (phoneNumber == testRegistrationPhone ||
          phoneNumber == legacyTestRegistrationPhone);

  @override
  Future<OtpChallenge> request({
    required String phoneNumber,
    required OtpPurpose purpose,
  }) {
    if (_isTestRegistration(phoneNumber, purpose)) {
      return Future.value(
        OtpChallenge(
          phoneNumber: phoneNumber,
          purpose: purpose,
          expiresAt: DateTime.now().add(const Duration(minutes: 2)),
          verificationToken: 'frontend-test-registration-token',
        ),
      );
    }

    return _realDataSource.request(phoneNumber: phoneNumber, purpose: purpose);
  }

  @override
  Future<OtpChallenge> verify({
    required String phoneNumber,
    required String code,
    required OtpPurpose purpose,
  }) async {
    if (_isTestRegistration(phoneNumber, purpose)) {
      if (code != testRegistrationOtp) {
        throw const AuthFailure('کد تست ثبت‌نام باید ۱۲۳۴۵۶ باشد.');
      }

      return OtpChallenge(
        phoneNumber: phoneNumber,
        purpose: purpose,
        expiresAt: DateTime.now().add(const Duration(minutes: 2)),
        verificationToken: 'frontend-test-registration-token',
      );
    }

    return _realDataSource.verify(
      phoneNumber: phoneNumber,
      code: code,
      purpose: purpose,
    );
  }

  @override
  Future<void> resetPassword({
    required String phoneNumber,
    required String verificationToken,
    required String newPassword,
  }) {
    return _realDataSource.resetPassword(
      phoneNumber: phoneNumber,
      verificationToken: verificationToken,
      newPassword: newPassword,
    );
  }
}
