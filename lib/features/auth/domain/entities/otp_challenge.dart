class OtpChallenge {
  const OtpChallenge({
    required this.phoneNumber,
    required this.purpose,
    required this.expiresAt,
    this.verificationToken,
  });

  final String phoneNumber;
  final OtpPurpose purpose;
  final DateTime expiresAt;
  final String? verificationToken;
}

enum OtpPurpose { registration, login, passwordRecovery }
