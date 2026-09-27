class OtpChallenge {
  const OtpChallenge({
    required this.phoneNumber,
    required this.purpose,
    required this.expiresAt,
    this.verificationToken,
    this.otpId,
    this.registrationDraftId,
    this.telegramIdentityId,
  });

  final String phoneNumber;
  final OtpPurpose purpose;
  final DateTime expiresAt;
  final String? verificationToken;
  final String? otpId;
  final String? registrationDraftId;
  final String? telegramIdentityId;
}

enum OtpPurpose { registration, login, passwordRecovery }
