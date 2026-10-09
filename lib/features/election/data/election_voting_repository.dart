import 'dart:convert';

import 'package:dio/dio.dart';

import '../../auth/data/services/biometric_auth_service.dart';
import '../../../../core/storage/secure_storage_service.dart';

class ElectionVotingRepository {
  ElectionVotingRepository({required Dio dio, required BiometricAuthService biometricAuth, required SecureStorageService storage})
      : _dio = dio, _biometric = biometricAuth, _storage = storage;

  final Dio _dio;
  final BiometricAuthService _biometric;
  final SecureStorageService _storage;

  String _base(String electionType, int processId) => '/api/v1/elections/$electionType/voting/$processId';

  Future<Map<String, dynamic>> list(String electionType, String kind, {String search = '', int? level, int? geographicId, int page = 1}) async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/elections/$electionType/voting/$kind', queryParameters: {
      if (search.trim().isNotEmpty) 'search': search.trim(),
      if (level != null) 'geographic_level_code': level,
      if (geographicId != null) 'geographic_id': geographicId,
      'page': page, 'per_page': 30,
    });
    return _data(response.data);
  }

  Future<Map<String, dynamic>> detail(String electionType, int processId) async => _data((await _dio.get<Map<String, dynamic>>(_base(electionType, processId))).data);

  Future<Map<String, dynamic>> results(String electionType, int processId, {int? level, int? geographicId}) async => _data((await _dio.get<Map<String, dynamic>>('${_base(electionType, processId)}/results', queryParameters: {
    if (level != null) 'geographic_level_code': level,
    if (geographicId != null) 'geographic_id': geographicId,
  })).data);

  Future<Map<String, dynamic>> preview(String electionType, int processId, Map<String, String> names) async => _data((await _dio.post<Map<String, dynamic>>('${_base(electionType, processId)}/candidate-preview', data: names)).data);

  Future<Map<String, dynamic>> castWithPassword({required String electionType, required int processId, required Map<String, String> names, required String password, required String issuanceKey, required String submissionKey}) async {
    final token = _data((await _dio.post<Map<String, dynamic>>('${_base(electionType, processId)}/confirmation', data: {
      ...names, 'confirmation_method': 'password', 'password': password, 'idempotency_key': issuanceKey,
    })).data)['vote_token']?.toString();
    return _submit(electionType, processId, names, token, issuanceKey, submissionKey);
  }

  Future<Map<String, dynamic>> castWithBiometrics({required String electionType, required int processId, required Map<String, String> names, required String issuanceKey, required String submissionKey}) async {
    final credentialId = await _biometric.localCredentialId;
    if (credentialId == null || !await _biometric.canAuthenticate || !await _biometric.isEnabledOnServer()) throw StateError('ورود بیومتریک روی این دستگاه فعال نیست.');
    final challenge = _data((await _dio.post<Map<String, dynamic>>('${_base(electionType, processId)}/biometric-challenge', data: names)).data);
    if (challenge['credential_id'] != credentialId) throw StateError('اعتبارنامهٔ بیومتریک این دستگاه با حساب هم‌خوان نیست.');
    final signature = await _biometric.signProposalPayload(challenge['signed_payload'].toString());
    final token = _data((await _dio.post<Map<String, dynamic>>('${_base(electionType, processId)}/confirmation', data: {
      ...names, 'confirmation_method': 'biometric', 'idempotency_key': issuanceKey,
      'challenge_id': challenge['challenge_id'], 'credential_id': credentialId, 'signature': signature,
    })).data)['vote_token']?.toString();
    return _submit(electionType, processId, names, token, issuanceKey, submissionKey);
  }

  Future<Map<String, dynamic>> _submit(String electionType, int processId, Map<String, String> names, String? token, String issuanceKey, String submissionKey) async {
    if (token == null || token.isEmpty) throw StateError('توکن رأی از سرور دریافت نشد.');
    final response = await _dio.post<Map<String, dynamic>>('${_base(electionType, processId)}/votes', data: {
      ...names, 'vote_token': token, 'issuance_idempotency_key': issuanceKey, 'submission_idempotency_key': submissionKey,
    });
    return _data(response.data);
  }

  Future<Map<String, dynamic>> verifyReceipt(String number) async => _data((await _dio.post<Map<String, dynamic>>('/api/v1/public/process-receipts/verify', data: {'receipt_number': number})).data);

  Future<void> savePending(int processId, Map<String, String> names, String issuance, String submission) =>
      _storage.write(key: 'election_vote_pending_$processId', value: jsonEncode({...names, 'issuance': issuance, 'submission': submission}));

  Future<Map<String, String>?> pending(int processId) async {
    final value = await _storage.read(key: 'election_vote_pending_$processId');
    if (value == null) return null;
    try {
      final data = jsonDecode(value);
      if (data is! Map) return null;
      return data.map((key, value) => MapEntry(key.toString(), value.toString()));
    } catch (_) { return null; }
  }

  Future<void> clearPending(int processId) => _storage.delete(key: 'election_vote_pending_$processId');

  Map<String, dynamic> _data(Map<String, dynamic>? response) {
    final data = response?['data'];
    if (data is! Map) throw StateError('پاسخ API انتخابات معتبر نیست.');
    return Map<String, dynamic>.from(data);
  }
}
