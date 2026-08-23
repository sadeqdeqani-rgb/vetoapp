class AdminContentDraft {
  const AdminContentDraft({
    required this.title,
    required this.body,
    this.isActive = false,
  });

  final String title;
  final String body;
  final bool isActive;
}

class AdminContentRecord extends AdminContentDraft {
  const AdminContentRecord({
    required this.id,
    required this.versionNumber,
    required super.title,
    required super.body,
    required super.isActive,
    this.publishedAt,
  });

  final int id;
  final int versionNumber;
  final DateTime? publishedAt;
}

class AdminVideoRecord extends AdminVideoDraft {
  const AdminVideoRecord({
    required this.id,
    required this.versionNumber,
    required super.title,
    required super.videoUrl,
    required super.posterUrl,
    required super.isActive,
    this.publishedAt,
  });

  final int id;
  final int versionNumber;
  final DateTime? publishedAt;
}

class NationalIdEligibilityRecord
    extends NationalIdEligibilityDraft {
  const NationalIdEligibilityRecord({
    required super.prefix,
    required super.firstFrom,
    required super.firstTo,
    required super.secondFrom,
    required super.secondTo,
    this.createdAt,
    this.updatedAt,
  });

  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class AdminSession {
  const AdminSession({
    required this.token,
    required this.username,
    required this.expiresAt,
  });

  final String token;
  final String username;
  final DateTime expiresAt;
}

class AdminVideoDraft {
  const AdminVideoDraft({
    required this.title,
    required this.videoUrl,
    this.posterUrl = '',
    this.isActive = false,
  });

  final String title;
  final String videoUrl;
  final String posterUrl;
  final bool isActive;
}

class AdminGeoItem {
  const AdminGeoItem({
    required this.id,
    required this.name,
    required this.type,
    this.parentId,
    this.isActive = true,
  });

  final int id;
  final String name;
  final String type;
  final int? parentId;
  final bool isActive;
}

class NationalIdEligibilityDraft {
  const NationalIdEligibilityDraft({
    required this.prefix,
    required this.firstFrom,
    required this.firstTo,
    required this.secondFrom,
    required this.secondTo,
  });

  final String prefix;
  final int firstFrom;
  final int firstTo;
  final int secondFrom;
  final int secondTo;
}
