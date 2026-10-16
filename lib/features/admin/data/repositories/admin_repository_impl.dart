import 'package:dio/dio.dart';
import 'dart:typed_data';

import '../../../../core/storage/secure_storage_service.dart';
import '../../domain/entities/admin_entities.dart';
import '../../domain/repositories/admin_repository.dart';

class AdminRepositoryImpl implements AdminRepository {
  AdminRepositoryImpl(this._dio, this._storage);

  static const _tokenKey = 'admin_api_token';
  static const _expiresAtKey = 'admin_api_token_expires_at';
  static const _usernameKey = 'admin_username';

  final Dio _dio;
  final SecureStorageService _storage;

  @override
  Future<List<Map<String, dynamic>>> homeSections() async {
    final response = await _dio.get(
      '/api/admin/home/sections',
      options: await _authorizedOptions(),
    );
    return _rows(
      response,
    ).whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
  }

  @override
  Future<void> saveHomeSection(String key, Map<String, dynamic> data) async {
    await _dio.put(
      '/api/admin/home/sections/$key',
      data: data,
      options: await _authorizedOptions(),
    );
  }

  @override
  Future<Map<String, dynamic>> homeState() async {
    final response = await _dio.get(
      '/api/admin/home/state',
      options: await _authorizedOptions(),
    );
    return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
  }

  @override
  Future<Map<String, dynamic>> changeHomeState(int stateValue) async {
    final response = await _dio.post(
      '/api/admin/home/state',
      data: {'state_value': stateValue},
      options: await _authorizedOptions(),
    );
    return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
  }

  @override
  Future<List<Map<String, dynamic>>> homeEvents() async {
    final response = await _dio.get(
      '/api/admin/home/events',
      options: await _authorizedOptions(),
    );
    return _rows(
      response,
    ).whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
  }

  @override
  Future<Map<String, dynamic>> wordpressContent() async {
    final response = await _dio.get(
      '/api/admin/wordpress/content',
      options: await _authorizedOptions(),
    );
    return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
  }

  @override
  Future<void> saveWordPressSettings(Map<String, String> settings) async {
    await _dio.put(
      '/api/admin/wordpress/settings',
      data: {'settings': settings},
      options: await _authorizedOptions(),
    );
  }

  @override
  Future<Map<String, dynamic>> updateWordPressPage(
    int pageId,
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.patch(
      '/api/admin/wordpress/pages/$pageId',
      data: data,
      options: await _authorizedOptions(),
    );
    return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
  }

  @override
  Future<Map<String, dynamic>> updateWordPressCollectionItem(
    String type,
    int itemId,
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.patch(
      '/api/admin/wordpress/collections/$type/$itemId',
      data: data,
      options: await _authorizedOptions(),
    );
    return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
  }

  @override
  Future<Map<String, dynamic>> uploadWordPressImage(
    Uint8List bytes,
    String fileName,
  ) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    final response = await _dio.post(
      '/api/admin/wordpress/media',
      data: form,
      options: await _authorizedOptions(),
    );
    return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
  }

  Future<Options> _authorizedOptions() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null || token.isEmpty) {
      throw const _AdminClientException('نشست ادمین منقضی یا موجود نیست.');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  List<dynamic> _rows(Response<dynamic> response) {
    final payload = response.data;
    if (payload is List) return payload;
    if (payload is Map && payload['data'] is List) {
      return payload['data'] as List;
    }
    if (payload is Map &&
        payload['data'] is Map &&
        (payload['data'] as Map)['data'] is List) {
      return ((payload['data'] as Map)['data'] as List);
    }
    return const [];
  }

  DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.tryParse('$value');

  int? _int(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value');

  @override
  Future<List<AdminContentRecord>> introductionRecords() async {
    final response = await _dio.get(
      '/api/admin/introduction',
      options: await _authorizedOptions(),
    );
    return _rows(response)
        .whereType<Map>()
        .map(
          (row) => AdminContentRecord(
            id: (row['introduction_content_id'] as num).toInt(),
            versionNumber: (row['version_number'] as num).toInt(),
            title: '${row['title'] ?? ''}',
            body: '${row['body_text'] ?? ''}',
            isActive: row['is_active'] == true || row['is_active'] == 1,
            publishedAt: _date(row['published_at']),
          ),
        )
        .toList();
  }

  @override
  Future<List<AdminContentRecord>> termsRecords() async {
    final response = await _dio.get(
      '/api/admin/terms',
      options: await _authorizedOptions(),
    );
    return _rows(response)
        .whereType<Map>()
        .map(
          (row) => AdminContentRecord(
            id: (row['terms_content_id'] as num).toInt(),
            versionNumber: (row['version_number'] as num).toInt(),
            title: '${row['title'] ?? ''}',
            body: '${row['body_text'] ?? ''}',
            isActive: row['is_active'] == true || row['is_active'] == 1,
            publishedAt: _date(row['published_at']),
          ),
        )
        .toList();
  }

  @override
  Future<void> publishTerms(int id) async {
    await _dio.post(
      '/api/admin/terms/$id/publish',
      options: await _authorizedOptions(),
    );
  }

  @override
  Future<List<AdminVideoRecord>> introductionVideoRecords() async {
    final response = await _dio.get(
      '/api/admin/introduction-videos',
      options: await _authorizedOptions(),
    );
    return _rows(response)
        .whereType<Map>()
        .map(
          (row) => AdminVideoRecord(
            id: (row['introduction_video_id'] as num).toInt(),
            versionNumber: (row['version_number'] as num).toInt(),
            title: '${row['title'] ?? ''}',
            videoUrl: '${row['video_url'] ?? ''}',
            posterUrl: '${row['poster_url'] ?? ''}',
            isActive: row['is_active'] == true || row['is_active'] == 1,
            publishedAt: _date(row['published_at']),
          ),
        )
        .toList();
  }

  @override
  Future<List<AdminGeoItem>> geographyRecords(String type) async {
    final endpoint = switch (type) {
      'province' => '/api/admin/provinces',
      'county' => '/api/admin/counties',
      _ => '/api/admin/settlements',
    };
    final response = await _dio.get(
      endpoint,
      options: await _authorizedOptions(),
    );
    return _rows(response)
        .whereType<Map>()
        .map(
          (row) => AdminGeoItem(
            id:
                _int(
                  row['province_id'] ??
                      row['county_id'] ??
                      row['settlement_id'],
                ) ??
                0,
            name: '${row['name_fa'] ?? ''}',
            type: type,
            parentId: _int(
              row['country_id'] ?? row['province_id'] ?? row['county_id'],
            ),
            isActive: row['is_active'] == true || row['is_active'] == 1,
          ),
        )
        .toList();
  }

  @override
  Future<List<NationalIdEligibilityRecord>> nationalIdRecords() async {
    final response = await _dio.get(
      '/api/admin/national-id-eligibilities',
      options: await _authorizedOptions(),
    );
    return _rows(response)
        .whereType<Map>()
        .map(
          (row) => NationalIdEligibilityRecord(
            prefix: '${row['national_id_prefix_3']}'.padLeft(3, '0'),
            firstFrom: (row['first_range_from'] as num).toInt(),
            firstTo: (row['first_range_to'] as num).toInt(),
            secondFrom: (row['second_range_from'] as num).toInt(),
            secondTo: (row['second_range_to'] as num).toInt(),
            createdAt: _date(row['created_at']),
            updatedAt: _date(row['updated_at']),
          ),
        )
        .toList();
  }

  @override
  Future<List<NationalIdAgeEligibilityReport>>
  nationalIdAgeEligibilityReports() async {
    final response = await _dio.get(
      '/api/admin/national-id-age-eligibility-reports',
      options: await _authorizedOptions(),
    );
    return _rows(response)
        .whereType<Map>()
        .map(
          (row) => NationalIdAgeEligibilityReport(
            id: _int(row['report_id']) ?? 0,
            registrationDraftId: _int(row['registration_draft_id']) ?? 0,
            nationalId: '${row['national_id'] ?? ''}',
            birthDate: '${row['birth_date'] ?? ''}',
            statusCode: '${row['status_code'] ?? 'Pending'}',
            adminNote: row['admin_note']?.toString(),
            createdAt:
                _date(row['created_at']) ??
                DateTime.fromMillisecondsSinceEpoch(0),
            updatedAt: _date(row['updated_at']),
          ),
        )
        .toList();
  }

  @override
  Future<void> reviewNationalIdAgeEligibilityReport(
    int id,
    String statusCode,
    String? adminNote,
  ) async {
    await _dio.patch(
      '/api/admin/national-id-age-eligibility-reports/$id',
      data: {'status_code': statusCode, 'admin_note': adminNote},
      options: await _authorizedOptions(),
    );
  }

  @override
  Future<List<AdminGeoCooldownPolicy>> geoCooldownPolicies() async {
    final response = await _dio.get(
      '/api/admin/geo-cooldown-policies',
      options: await _authorizedOptions(),
    );
    return _rows(response)
        .whereType<Map>()
        .map(
          (row) => AdminGeoCooldownPolicy(
            id: _int(row['policy_id']) ?? 0,
            policyCode: '${row['policy_code'] ?? ''}',
            policyName: '${row['policy_name'] ?? ''}',
            description: row['description']?.toString(),
            policyStage: _int(row['policy_stage']) ?? 0,
            maxChangesAllowed: _int(row['max_changes_allowed']),
            windowDays: _int(row['window_days']),
            cooldownDays: _int(row['cooldown_days']) ?? 0,
            isActive: row['is_active'] == true || row['is_active'] == 1,
            effectiveFrom:
                _date(row['effective_from']) ??
                DateTime.fromMillisecondsSinceEpoch(0),
            effectiveTo: _date(row['effective_to']),
          ),
        )
        .toList();
  }

  @override
  Future<List<AdminClosurePenaltyPolicy>> closurePenaltyPolicies() async {
    final response = await _dio.get(
      '/api/admin/account-closure-penalty-policies',
      options: await _authorizedOptions(),
    );
    return _rows(response)
        .whereType<Map>()
        .map(
          (row) => AdminClosurePenaltyPolicy(
            id: _int(row['policy_id']) ?? 0,
            policyFamilyCode: '${row['policy_family_code'] ?? ''}',
            policyCode: '${row['policy_code'] ?? ''}',
            policyName: '${row['policy_name'] ?? ''}',
            description: row['description']?.toString(),
            penaltyStage: _int(row['penalty_stage']) ?? 0,
            penaltyHours: _int(row['penalty_hours']) ?? 0,
            triggerScope: '${row['trigger_scope'] ?? 'account_closure'}',
            isActive: row['is_active'] == true || row['is_active'] == 1,
            effectiveFrom:
                _date(row['effective_from']) ??
                DateTime.fromMillisecondsSinceEpoch(0),
            effectiveTo: _date(row['effective_to']),
          ),
        )
        .toList();
  }

  @override
  Future<List<AdminProcessLifecyclePolicy>> processLifecyclePolicies() async {
    final response = await _dio.get(
      '/api/admin/process-lifecycle-policies',
      options: await _authorizedOptions(),
    );
    return _rows(response).whereType<Map>().map((row) {
      final supportSeconds = _int(row['support_period_seconds']) ?? 0;
      final waitingSeconds = _int(row['waiting_period_seconds']) ?? 0;
      final votingSeconds = _int(row['voting_period_seconds']) ?? 0;
      final publicationSeconds = _int(row['publication_delay_seconds']) ?? 0;
      return AdminProcessLifecyclePolicy(
        id: _int(row['process_lifecycle_policy_version_id']) ?? 0,
        versionNumber: _int(row['version_number']) ?? 0,
        thresholdRatePpm: _int(row['threshold_rate_ppm']) ?? 200000,
        minSupportCount: _int(row['min_support_count']) ?? 0,
        supportPeriodDays: supportSeconds ~/ 86400,
        waitingPeriodDays: waitingSeconds ~/ 86400,
        votingPeriodDays: votingSeconds ~/ 86400,
        publicationDelayHours: publicationSeconds ~/ 3600,
        isActive: row['is_active'] == true || row['is_active'] == 1,
        effectiveFrom: _date(row['effective_from']),
      );
    }).toList();
  }

  @override
  Future<void> createProcessLifecyclePolicy(Map<String, dynamic> data) async {
    await _dio.post(
      '/api/admin/process-lifecycle-policies',
      data: data,
      options: await _authorizedOptions(),
    );
  }

  @override
  Future<AdminSession> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/admin/login',
        data: {'username': username, 'password': password},
      );
      final data = response.data ?? const <String, dynamic>{};
      final token = data['access_token'];
      final expiresAt = DateTime.tryParse('${data['expires_at'] ?? ''}');
      final admin = data['admin'];
      final returnedUsername =
          admin is Map ? '${admin['username'] ?? username}' : username;
      if (token is! String || token.isEmpty || expiresAt == null) {
        throw const _AdminClientException('پاسخ ورود ادمین نامعتبر است.');
      }

      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(
        key: _expiresAtKey,
        value: expiresAt.toIso8601String(),
      );
      await _storage.write(key: _usernameKey, value: returnedUsername);

      return AdminSession(
        token: token,
        username: returnedUsername,
        expiresAt: expiresAt,
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 422 || status == 401) {
        throw const _AdminClientException(
          'نام کاربری یا رمز عبور ادمین صحیح نیست.',
        );
      }
      throw const _AdminClientException('ارتباط با سرور ادمین برقرار نشد.');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _dio.post('/api/admin/logout', options: await _authorizedOptions());
    } finally {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _expiresAtKey);
      await _storage.delete(key: _usernameKey);
    }
  }

  @override
  Future<bool> hasSession() async {
    final token = await _storage.read(key: _tokenKey);
    final expiry = await _storage.read(key: _expiresAtKey);
    final expiresAt = expiry == null ? null : DateTime.tryParse(expiry);
    return token != null &&
        token.isNotEmpty &&
        expiresAt != null &&
        expiresAt.isAfter(DateTime.now());
  }

  @override
  Future<AdminContentDraft> saveIntroduction(AdminContentDraft draft) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/admin/introduction',
      data: {
        'version_number': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'title': draft.title,
        'body_text': draft.body,
        'is_active': draft.isActive,
        if (draft.isActive) 'published_at': DateTime.now().toIso8601String(),
      },
      options: await _authorizedOptions(),
    );
    if (response.statusCode != 201) {
      throw const _AdminClientException('ذخیره معرفی سامانه ناموفق بود.');
    }
    return draft;
  }

  @override
  Future<AdminContentDraft> saveTerms(AdminContentDraft draft) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/admin/terms',
      data: {
        'version_number': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'title': draft.title,
        'body_text': draft.body,
        'is_active': draft.isActive,
        if (draft.isActive) 'published_at': DateTime.now().toIso8601String(),
      },
      options: await _authorizedOptions(),
    );
    if (response.statusCode != 201) {
      throw const _AdminClientException('ذخیره قوانین ناموفق بود.');
    }
    return draft;
  }

  @override
  Future<AdminVideoDraft> saveIntroductionVideo(AdminVideoDraft draft) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/admin/introduction-videos',
      data: {
        'version_number': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'title': draft.title,
        'video_url': draft.videoUrl,
        if (draft.posterUrl.isNotEmpty) 'poster_url': draft.posterUrl,
        'is_active': draft.isActive,
        if (draft.isActive) 'published_at': DateTime.now().toIso8601String(),
      },
      options: await _authorizedOptions(),
    );
    if (response.statusCode != 201) {
      throw const _AdminClientException('ذخیره ویدئو ناموفق بود.');
    }
    return draft;
  }

  @override
  Future<void> saveGeography(AdminGeoItem item) async {
    final endpoint = switch (item.type) {
      'province' => '/api/admin/provinces',
      'county' => '/api/admin/counties',
      _ => '/api/admin/settlements',
    };
    final key = switch (item.type) {
      'province' => 'province_code',
      'county' => 'county_code',
      _ => 'settlement_code',
    };
    await _dio.post(
      endpoint,
      data: {
        key: item.id,
        'name_fa': item.name,
        'is_active': item.isActive,
        if (item.type == 'province') 'country_id': item.parentId ?? 1,
        if (item.type == 'county') 'province_id': item.parentId,
        if (item.type != 'province' && item.type != 'county')
          'county_id': item.parentId,
      },
      options: await _authorizedOptions(),
    );
  }

  @override
  Future<void> saveNationalIdEligibility(
    NationalIdEligibilityDraft draft,
  ) async {
    await _dio.put(
      '/api/admin/national-id-eligibilities/${int.parse(draft.prefix)}',
      data: {
        'first_range_from': draft.firstFrom,
        'first_range_to': draft.firstTo,
        'second_range_from': draft.secondFrom,
        'second_range_to': draft.secondTo,
      },
      options: await _authorizedOptions(),
    );
  }

  @override
  Future<void> createAdminUser({
    required String username,
    required String password,
  }) async {
    await _dio.post(
      '/api/admin/users',
      data: {
        'username': username,
        'password': password,
        'password_confirmation': password,
      },
      options: await _authorizedOptions(),
    );
  }

  @override
  Future<void> createGeoCooldownPolicy(Map<String, dynamic> data) async {
    await _dio.post(
      '/api/admin/geo-cooldown-policies',
      data: data,
      options: await _authorizedOptions(),
    );
  }

  @override
  Future<void> updateGeoCooldownPolicy(
    int id,
    Map<String, dynamic> data,
  ) async {
    await _dio.patch(
      '/api/admin/geo-cooldown-policies/$id',
      data: data,
      options: await _authorizedOptions(),
    );
  }

  @override
  Future<void> deleteGeoCooldownPolicy(int id) async {
    await _dio.delete(
      '/api/admin/geo-cooldown-policies/$id',
      options: await _authorizedOptions(),
    );
  }

  @override
  Future<void> createClosurePenaltyPolicy(Map<String, dynamic> data) async {
    await _dio.post(
      '/api/admin/account-closure-penalty-policies',
      data: data,
      options: await _authorizedOptions(),
    );
  }

  @override
  Future<void> updateClosurePenaltyPolicy(
    int id,
    Map<String, dynamic> data,
  ) async {
    await _dio.patch(
      '/api/admin/account-closure-penalty-policies/$id',
      data: data,
      options: await _authorizedOptions(),
    );
  }

  @override
  Future<void> deleteClosurePenaltyPolicy(int id) async {
    await _dio.delete(
      '/api/admin/account-closure-penalty-policies/$id',
      options: await _authorizedOptions(),
    );
  }
}

class _AdminClientException implements Exception {
  const _AdminClientException(this.message);

  final String message;

  @override
  String toString() => message;
}
