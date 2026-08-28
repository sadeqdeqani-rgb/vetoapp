class PublicContent {
  const PublicContent({
    required this.id,
    required this.versionNumber,
    required this.title,
    required this.body,
    this.publishedAt,
  });

  final int id;
  final int versionNumber;
  final String title;
  final String body;
  final DateTime? publishedAt;
}

class PublicIntroductionVideo {
  const PublicIntroductionVideo({
    required this.id,
    required this.versionNumber,
    required this.title,
    required this.videoUrl,
    this.posterUrl,
    this.durationSeconds,
    this.publishedAt,
  });

  final int id;
  final int versionNumber;
  final String title;
  final String videoUrl;
  final String? posterUrl;
  final int? durationSeconds;
  final DateTime? publishedAt;
}
