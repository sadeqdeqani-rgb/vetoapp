enum ImpeachmentOffice {
  president('president', 'استیضاح رئیس‌جمهور', 1),
  governor('governor', 'استیضاح استانداران', 2),
  county('county', 'استیضاح فرمانداران', 3),
  local('local', 'استیضاح شهرداران و دهیاران', 4);

  const ImpeachmentOffice(this.code, this.title, this.geographicLevelCode);
  final String code;
  final String title;
  final int geographicLevelCode;

  static ImpeachmentOffice? fromCode(String? code) {
    for (final office in values) {
      if (office.code == code) return office;
    }
    return null;
  }

  String get scopeLabel => switch (this) {
        president => 'کشور',
        governor => 'استان محل سکونت شما',
        county => 'شهرستان محل سکونت شما',
        local => 'شهر یا روستای محل سکونت شما',
      };
}
