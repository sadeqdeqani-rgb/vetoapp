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

class NationalIdEligibilityRecord extends NationalIdEligibilityDraft {
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

class NationalIdAgeEligibilityReport {
  const NationalIdAgeEligibilityReport({
    required this.id,
    required this.registrationDraftId,
    required this.nationalId,
    required this.birthDate,
    required this.statusCode,
    required this.createdAt,
    this.adminNote,
    this.updatedAt,
  });

  final int id;
  final int registrationDraftId;
  final String nationalId;
  final String birthDate;
  final String statusCode;
  final String? adminNote;
  final DateTime createdAt;
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

class AdminGeoCooldownPolicy {
  const AdminGeoCooldownPolicy({
    required this.id,
    required this.policyCode,
    required this.policyName,
    required this.policyStage,
    required this.cooldownDays,
    required this.isActive,
    required this.effectiveFrom,
    this.description,
    this.maxChangesAllowed,
    this.windowDays,
    this.effectiveTo,
  });

  final int id;
  final String policyCode;
  final String policyName;
  final String? description;
  final int policyStage;
  final int? maxChangesAllowed;
  final int? windowDays;
  final int cooldownDays;
  final bool isActive;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
}

class AdminClosurePenaltyPolicy {
  const AdminClosurePenaltyPolicy({
    required this.id,
    required this.policyFamilyCode,
    required this.policyCode,
    required this.policyName,
    required this.penaltyStage,
    required this.penaltyHours,
    required this.triggerScope,
    required this.isActive,
    required this.effectiveFrom,
    this.description,
    this.effectiveTo,
  });

  final int id;
  final String policyFamilyCode;
  final String policyCode;
  final String policyName;
  final String? description;
  final int penaltyStage;
  final int penaltyHours;
  final String triggerScope;
  final bool isActive;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
}

class AdminProcessLifecyclePolicy {
  const AdminProcessLifecyclePolicy({
    required this.id,
    required this.versionNumber,
    required this.thresholdRatePpm,
    required this.minSupportCount,
    required this.supportPeriodDays,
    required this.waitingPeriodDays,
    required this.votingPeriodDays,
    required this.publicationDelayHours,
    required this.isActive,
    this.effectiveFrom,
  });

  final int id;
  final int versionNumber;
  final int thresholdRatePpm;
  final int minSupportCount;
  final int supportPeriodDays;
  final int waitingPeriodDays;
  final int votingPeriodDays;
  final int publicationDelayHours;
  final bool isActive;
  final DateTime? effectiveFrom;
}
