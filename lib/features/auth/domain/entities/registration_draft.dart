class RegistrationDraft {
  const RegistrationDraft({
    required this.draftId,
    required this.telegramIdentityId,
    required this.phoneNumber,
    required this.nationalCode,
    required this.countryId,
    required this.provinceId,
    required this.countyId,
    required this.localityId,
    required this.password,
  });

  final String draftId;
  final String telegramIdentityId;
  final String phoneNumber;
  final String nationalCode;
  final int countryId;
  final int provinceId;
  final int countyId;
  final int localityId;
  final String password;
}
