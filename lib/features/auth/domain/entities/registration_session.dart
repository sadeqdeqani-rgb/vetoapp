class RegistrationSession {
  const RegistrationSession({
    required this.draftId,
    required this.telegramLinkNonce,
    this.telegramStartUrl,
    this.telegramIdentityId,
  });

  final String draftId;
  final String telegramLinkNonce;
  final String? telegramStartUrl;
  final String? telegramIdentityId;

  factory RegistrationSession.fromJson(Map<String, dynamic> json) =>
      RegistrationSession(
        draftId: json['draft_id'].toString(),
        telegramLinkNonce: json['telegram_link_nonce'] as String,
        telegramStartUrl: json['telegram_start_url'] as String?,
        telegramIdentityId: json['telegram_identity_id']?.toString(),
      );
}
