import '../entities/admin_entities.dart';

abstract interface class AdminRepository {
  Future<List<Map<String, dynamic>>> homeSections();
  Future<void> saveHomeSection(String key, Map<String, dynamic> data);
  Future<Map<String, dynamic>> homeState();
  Future<Map<String, dynamic>> changeHomeState(int stateValue);
  Future<List<Map<String, dynamic>>> homeEvents();
  Future<List<AdminContentRecord>> introductionRecords();

  Future<List<AdminContentRecord>> termsRecords();

  Future<void> publishTerms(int id);

  Future<List<AdminVideoRecord>> introductionVideoRecords();

  Future<List<AdminGeoItem>> geographyRecords(String type);

  Future<List<NationalIdEligibilityRecord>> nationalIdRecords();

  Future<List<NationalIdAgeEligibilityReport>>
  nationalIdAgeEligibilityReports();

  Future<void> reviewNationalIdAgeEligibilityReport(
    int id,
    String statusCode,
    String? adminNote,
  );

  Future<List<AdminGeoCooldownPolicy>> geoCooldownPolicies();

  Future<List<AdminClosurePenaltyPolicy>> closurePenaltyPolicies();

  Future<List<AdminProcessLifecyclePolicy>> processLifecyclePolicies();

  Future<void> createProcessLifecyclePolicy(Map<String, dynamic> data);

  Future<AdminSession> login({
    required String username,
    required String password,
  });

  Future<void> logout();

  Future<bool> hasSession();

  Future<AdminContentDraft> saveIntroduction(AdminContentDraft draft);

  Future<AdminContentDraft> saveTerms(AdminContentDraft draft);

  Future<AdminVideoDraft> saveIntroductionVideo(AdminVideoDraft draft);

  Future<void> saveGeography(AdminGeoItem item);

  Future<void> saveNationalIdEligibility(NationalIdEligibilityDraft draft);

  Future<void> createAdminUser({
    required String username,
    required String password,
  });

  Future<void> createGeoCooldownPolicy(Map<String, dynamic> data);

  Future<void> updateGeoCooldownPolicy(int id, Map<String, dynamic> data);

  Future<void> deleteGeoCooldownPolicy(int id);

  Future<void> createClosurePenaltyPolicy(Map<String, dynamic> data);

  Future<void> updateClosurePenaltyPolicy(int id, Map<String, dynamic> data);

  Future<void> deleteClosurePenaltyPolicy(int id);
}
