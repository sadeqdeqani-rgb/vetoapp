import '../../domain/entities/otp_challenge.dart';
import 'otp_remote_data_source.dart';

/// OTP فیک مخصوص مشاهدهٔ کامل فلوی ثبت‌نام در محیط توسعه.
///
/// فقط registration را فیک می‌کند و سایر کاربردهای OTP را به API واقعی می‌سپارد.
class FrontendTestOtpDataSource implements OtpRemoteDataSource {
  FrontendTestOtpDataSource(this._realDataSource);

  final OtpRemoteDataSource _realDataSource;

  @override
  Future<OtpChallenge> request({
    required String phoneNumber,
    required OtpPurpose purpose,
    String? registrationDraftId,
    String? telegramIdentityId,
  }) => _realDataSource.request(
    phoneNumber: phoneNumber,
    purpose: purpose,
    registrationDraftId: registrationDraftId,
    telegramIdentityId: telegramIdentityId,
  );

  @override
  Future<OtpChallenge> verify({
    required String phoneNumber,
    required String code,
    required OtpPurpose purpose,
    String? otpId,
  }) async {
    return _realDataSource.verify(
      phoneNumber: phoneNumber,
      code: code,
      purpose: purpose,
      otpId: otpId,
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
