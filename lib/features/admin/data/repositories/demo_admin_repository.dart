import '../../domain/entities/admin_entities.dart';
import '../../domain/repositories/admin_repository.dart';

/// Repository موقت برای بررسی UI.
///
/// در نسخه اتصال واقعی، این پیاده‌سازی با AdminRemoteDataSource و API
/// احراز هویت‌شده Laravel جایگزین می‌شود. هیچ رمز عبوری در این کلاس ذخیره نمی‌شود.
class DemoAdminRepository implements AdminRepository {
  final Map<String, Map<String, dynamic>> introSections = {};
  int demoState = 1;

  @override
  Future<List<Map<String, dynamic>>> homeSections() async =>
      introSections.values.toList();
  @override
  Future<void> saveHomeSection(String key, Map<String, dynamic> data) async {
    introSections[key] = data;
  }

  @override
  Future<Map<String, dynamic>> homeState() async => {'state_value': demoState};
  @override
  Future<Map<String, dynamic>> changeHomeState(int stateValue) async {
    demoState = stateValue;
    return homeState();
  }

  @override
  Future<List<Map<String, dynamic>>> homeEvents() async =>
      const <Map<String, dynamic>>[];

  AdminSession? session;
  AdminContentDraft? introduction;
  AdminContentDraft? terms;
  AdminVideoDraft? video;
  final List<AdminGeoItem> geography = <AdminGeoItem>[];
  final List<NationalIdEligibilityDraft> nationalIdRanges =
      <NationalIdEligibilityDraft>[];
  final List<AdminGeoCooldownPolicy> geoPolicies = <AdminGeoCooldownPolicy>[];
  final List<AdminClosurePenaltyPolicy> closurePolicies =
      <AdminClosurePenaltyPolicy>[];
  final List<AdminProcessLifecyclePolicy> lifecyclePolicies =
      <AdminProcessLifecyclePolicy>[
        AdminProcessLifecyclePolicy(
          id: 1,
          versionNumber: 1,
          thresholdRatePpm: 200000,
          minSupportCount: 0,
          supportPeriodDays: 30,
          waitingPeriodDays: 30,
          votingPeriodDays: 7,
          publicationDelayHours: 24,
          isActive: true,
        ),
      ];

  @override
  Future<List<AdminContentRecord>> introductionRecords() async => [];

  @override
  Future<List<AdminContentRecord>> termsRecords() async => [];

  @override
  Future<void> publishTerms(int id) async {}

  @override
  Future<List<AdminVideoRecord>> introductionVideoRecords() async => [];

  @override
  Future<List<AdminGeoItem>> geographyRecords(String type) async => [];

  @override
  Future<List<NationalIdEligibilityRecord>> nationalIdRecords() async => [];

  @override
  Future<List<NationalIdAgeEligibilityReport>>
  nationalIdAgeEligibilityReports() async => [];

  @override
  Future<void> reviewNationalIdAgeEligibilityReport(
    int id,
    String statusCode,
    String? adminNote,
  ) async {}

  @override
  Future<List<AdminGeoCooldownPolicy>> geoCooldownPolicies() async =>
      List.unmodifiable(geoPolicies);

  @override
  Future<List<AdminClosurePenaltyPolicy>> closurePenaltyPolicies() async =>
      List.unmodifiable(closurePolicies);

  @override
  Future<List<AdminProcessLifecyclePolicy>> processLifecyclePolicies() async =>
      List.unmodifiable(lifecyclePolicies);

  @override
  Future<void> createProcessLifecyclePolicy(Map<String, dynamic> data) async {
    final version =
        lifecyclePolicies.isEmpty
            ? 1
            : lifecyclePolicies
                    .map((item) => item.versionNumber)
                    .reduce((a, b) => a > b ? a : b) +
                1;
    for (var i = 0; i < lifecyclePolicies.length; i++) {
      final old = lifecyclePolicies[i];
      lifecyclePolicies[i] = AdminProcessLifecyclePolicy(
        id: old.id,
        versionNumber: old.versionNumber,
        thresholdRatePpm: old.thresholdRatePpm,
        minSupportCount: old.minSupportCount,
        supportPeriodDays: old.supportPeriodDays,
        waitingPeriodDays: old.waitingPeriodDays,
        votingPeriodDays: old.votingPeriodDays,
        publicationDelayHours: old.publicationDelayHours,
        isActive: false,
        effectiveFrom: old.effectiveFrom,
      );
    }
    lifecyclePolicies.insert(
      0,
      AdminProcessLifecyclePolicy(
        id: version,
        versionNumber: version,
        thresholdRatePpm: data['threshold_rate_ppm'] as int,
        minSupportCount: data['min_support_count'] as int,
        supportPeriodDays: data['support_period_days'] as int,
        waitingPeriodDays: data['waiting_period_days'] as int,
        votingPeriodDays: data['voting_period_days'] as int,
        publicationDelayHours: data['publication_delay_hours'] as int,
        isActive: true,
        effectiveFrom: DateTime.now(),
      ),
    );
  }

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
