import '../../domain/entities/admin_entities.dart';
import '../../domain/repositories/admin_repository.dart';

/// Repository موقت برای بررسی UI.
///
/// در نسخه اتصال واقعی، این پیاده‌سازی با AdminRemoteDataSource و API
/// احراز هویت‌شده Laravel جایگزین می‌شود. هیچ رمز عبوری در این کلاس ذخیره نمی‌شود.
class DemoAdminRepository implements AdminRepository {
  AdminSession? session;
  AdminContentDraft? introduction;
  AdminContentDraft? terms;
  AdminVideoDraft? video;
  final List<AdminGeoItem> geography = <AdminGeoItem>[];
  final List<NationalIdEligibilityDraft> nationalIdRanges =
      <NationalIdEligibilityDraft>[];
  final List<AdminGeoCooldownPolicy> geoPolicies =
      <AdminGeoCooldownPolicy>[];
  final List<AdminClosurePenaltyPolicy> closurePolicies =
      <AdminClosurePenaltyPolicy>[];

  @override
  Future<List<AdminContentRecord>> introductionRecords() async => [];

  @override
  Future<List<AdminContentRecord>> termsRecords() async => [];

  @override
  Future<List<AdminVideoRecord>> introductionVideoRecords() async => [];

  @override
  Future<List<AdminGeoItem>> geographyRecords(String type) async => [];

  @override
  Future<List<NationalIdEligibilityRecord>> nationalIdRecords() async => [];

  @override
  Future<List<AdminGeoCooldownPolicy>> geoCooldownPolicies() async =>
      List.unmodifiable(geoPolicies);

  @override
  Future<List<AdminClosurePenaltyPolicy>> closurePenaltyPolicies() async =>
      List.unmodifiable(closurePolicies);

  @override
  Future<AdminSession> login({
    required String username,
    required String password,
  }) async {
    session = AdminSession(
      token: 'demo-token',
      username: username,
      expiresAt: DateTime.now().add(const Duration(hours: 12)),
    );
    return session!;
  }

  @override
  Future<void> logout() async {
    session = null;
  }

  @override
  Future<bool> hasSession() async => session != null;

  @override
  Future<AdminContentDraft> saveIntroduction(AdminContentDraft draft) async {
    introduction = draft;
    return draft;
  }

  @override
  Future<AdminContentDraft> saveTerms(AdminContentDraft draft) async {
    terms = draft;
    return draft;
  }

  @override
  Future<AdminVideoDraft> saveIntroductionVideo(AdminVideoDraft draft) async {
    video = draft;
    return draft;
  }

  @override
  Future<void> saveGeography(AdminGeoItem item) async {
    geography.add(item);
  }

  @override
  Future<void> saveNationalIdEligibility(
    NationalIdEligibilityDraft draft,
  ) async {
    nationalIdRanges.add(draft);
  }

  @override
  Future<void> createAdminUser({
    required String username,
    required String password,
  }) async {
    // رمز عبور عمداً در کلاینت ذخیره نمی‌شود.
  }

  @override
  Future<void> createGeoCooldownPolicy(Map<String, dynamic> data) async {}

  @override
  Future<void> updateGeoCooldownPolicy(
    int id,
    Map<String, dynamic> data,
  ) async {}

  @override
  Future<void> deleteGeoCooldownPolicy(int id) async {}

  @override
  Future<void> createClosurePenaltyPolicy(Map<String, dynamic> data) async {}

  @override
  Future<void> updateClosurePenaltyPolicy(
    int id,
    Map<String, dynamic> data,
  ) async {}

  @override
  Future<void> deleteClosurePenaltyPolicy(int id) async {}
}
