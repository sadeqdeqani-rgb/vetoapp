import '../entities/admin_entities.dart';

abstract interface class AdminRepository {
  Future<List<AdminContentRecord>> introductionRecords();

  Future<List<AdminContentRecord>> termsRecords();

  Future<List<AdminVideoRecord>> introductionVideoRecords();

  Future<List<AdminGeoItem>> geographyRecords(String type);

  Future<List<NationalIdEligibilityRecord>> nationalIdRecords();

  Future<List<AdminGeoCooldownPolicy>> geoCooldownPolicies();

  Future<List<AdminClosurePenaltyPolicy>> closurePenaltyPolicies();

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
