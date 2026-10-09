class TelegramPasswordRecoveryChallenge {
  const TelegramPasswordRecoveryChallenge({
    required this.nonce,
    required this.telegramStartUrl,
    required this.expiresAt,
  });

  final String nonce;
  final String telegramStartUrl;
  final DateTime expiresAt;
}

class TelegramPasswordRecoveryStatus {
  const TelegramPasswordRecoveryStatus({
    required this.state,
    this.otpId,
  });

  final String state;
  final String? otpId;
}
