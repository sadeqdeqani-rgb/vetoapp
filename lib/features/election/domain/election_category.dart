enum ElectionCategory {
  presidential('presidential', 'انتخابات ریاست جمهوری', 1),
  governor('governor', 'انتخابات استانداری‌ها', 2),
  county('county', 'انتخابات فرمانداری‌ها', 3),
  local('local', 'انتخابات شهرداری‌ها و دهیاری‌ها', 4);

  const ElectionCategory(this.code, this.title, this.geographicLevelCode);

  final String code;
  final String title;
  final int geographicLevelCode;

  static ElectionCategory? fromCode(String? code) {
    for (final category in values) {
      if (category.code == code) return category;
    }
    return null;
  }
}
