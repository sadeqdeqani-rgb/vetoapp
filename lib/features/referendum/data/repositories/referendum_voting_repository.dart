import 'package:dio/dio.dart';

import '../../../auth/data/services/biometric_auth_service.dart';
import '../../../../core/storage/secure_storage_service.dart';

class ReferendumVotingRepository {
  ReferendumVotingRepository({required Dio dio, required BiometricAuthService biometricAuth, required SecureStorageService storage})
      : _dio = dio,
        _biometricAuth = biometricAuth,
        _storage = storage;

  final Dio _dio;
  final BiometricAuthService _biometricAuth;
  final SecureStorageService _storage;

  String _pendingKey(int processId) => 'referendum_vote_pending_$processId';
  Future<Map<String, String>?> pendingAttempt(int processId) async {
    final value = await _storage.read(key: _pendingKey(processId));
    if (value == null) return null;
    final parts = value.split('|');
    if (parts.length != 3 || !['YES', 'NO'].contains(parts[0])) return null;
    return {'choice': parts[0], 'issuance_key': parts[1], 'submission_key': parts[2]};
  }

  Future<void> savePendingAttempt(int processId, {required String choice, required String issuanceKey, required String submissionKey}) =>
      _storage.write(key: _pendingKey(processId), value: '$choice|$issuanceKey|$submissionKey');

  Future<void> clearPendingAttempt(int processId) => _storage.delete(key: _pendingKey(processId));

  Future<ReferendumProcessPage> list(String kind, {String search = '', int? level, int? geographicId, int? targetLevel, int page = 1, int perPage = 30}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/referendum/voting/$kind',
      queryParameters: {
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (level != null) 'geographic_level_code': level,
        if (geographicId != null) 'geographic_id': geographicId,
        if (targetLevel != null) 'target_geographic_level_code': targetLevel,
        'page': page,
        'per_page': perPage,
      },
    );
    final data = response.data?['data'];
    if (data is! Map || data['items'] is! List) throw StateError('پاسخ فهرست همه‌پرسی‌ها معتبر نیست.');
    final pagination = data['pagination'];
    if (pagination is! Map) throw StateError('پاسخ صفحه‌بندی همه‌پرسی‌ها معتبر نیست.');
    return ReferendumProcessPage(
      items: (data['items'] as List).whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList(),
      total: int.tryParse(pagination['total']?.toString() ?? '') ?? 0,
    );
  }

  Future<Map<String, dynamic>> detail(int processId) async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/referendum/voting/$processId');
    final data = response.data?['data'];
    if (data is! Map) throw StateError('پاسخ اطلاعات همه‌پرسی معتبر نیست.');
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> results(int processId, {int? level, int? geographicId}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/referendum/voting/$processId/results',
      queryParameters: {if (level != null) 'geographic_level_code': level, if (geographicId != null) 'geographic_id': geographicId},
    );
    final data = response.data?['data'];
    if (data is! Map) throw StateError('پاسخ آمار رأی معتبر نیست.');
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> verifyReceipt(String receiptNumber) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/public/process-receipts/verify',
      data: {'receipt_number': receiptNumber},
    );
    final data = response.data?['data'];
    if (data is! Map) throw StateError('پاسخ بررسی رسید معتبر نیست.');
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> castWithPassword({required int processId, required String choice, required String password, required String issuanceKey, required String submissionKey}) async {
    final token = await _dio.post<Map<String, dynamic>>(
      '/api/v1/referendum/voting/$processId/confirmation',
      data: {'choice_key': choice, 'confirmation_method': 'password', 'password': password, 'idempotency_key': issuanceKey},
    );
    return _submitVote(processId, choice, issuanceKey, submissionKey, token.data?['data']?['vote_token']?.toString());
  }

  Future<Map<String, dynamic>> castWithBiometrics({required int processId, required String choice, required String issuanceKey, required String submissionKey}) async {
    final credentialId = await _biometricAuth.localCredentialId;
    if (credentialId == null || !await _biometricAuth.canAuthenticate || !await _biometricAuth.isEnabledOnServer()) {
      throw StateError('ورود بیومتریک روی این دستگاه در دسترس نیست.');
    }
    final challengeResponse = await _dio.post<Map<String, dynamic>>(
      '/api/v1/referendum/voting/$processId/biometric-challenge', data: {'choice_key': choice},
    );
    final challengeData = challengeResponse.data?['data'];
    if (challengeData is! Map) throw StateError('پاسخ چالش بیومتریک معتبر نیست.');
    final challenge = Map<String, dynamic>.from(challengeData);
    if (challenge['credential_id'] != credentialId) throw StateError('اعتبارنامهٔ بیومتریک این دستگاه با حساب هم‌خوان نیست.');
    final signature = await _biometricAuth.signProposalPayload(challenge['signed_payload'].toString());
    final tokenResponse = await _dio.post<Map<String, dynamic>>(
      '/api/v1/referendum/voting/$processId/confirmation',
      data: {
        'choice_key': choice, 'confirmation_method': 'biometric', 'idempotency_key': issuanceKey,
        'challenge_id': challenge['challenge_id'], 'credential_id': credentialId, 'signature': signature,
      },
    );
    return _submitVote(processId, choice, issuanceKey, submissionKey, tokenResponse.data?['data']?['vote_token']?.toString());
  }

  Future<Map<String, dynamic>> _submitVote(int processId, String choice, String issuanceKey, String submissionKey, String? token) async {
    if (token == null || token.isEmpty) throw StateError('توکن رأی از سرور دریافت نشد.');
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/referendum/voting/$processId/votes',
      data: {'vote_token': token, 'choice_key': choice, 'issuance_idempotency_key': issuanceKey, 'submission_idempotency_key': submissionKey},
    );
    final data = response.data?['data'];
    if (data is! Map) throw StateError('رسید دیجیتال رأی دریافت نشد.');
    return Map<String, dynamic>.from(data);
  }
}

class ReferendumProcessPage {
  const ReferendumProcessPage({required this.items, required this.total});

  final List<Map<String, dynamic>> items;
  final int total;
}
