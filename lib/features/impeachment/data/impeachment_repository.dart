import 'dart:convert';

import 'package:dio/dio.dart';

import '../../auth/data/services/biometric_auth_service.dart';
import '../../../core/storage/secure_storage_service.dart';

class ImpeachmentRepository {
  ImpeachmentRepository({required Dio dio, required BiometricAuthService biometricAuth, required SecureStorageService storage})
      : _dio = dio, _biometric = biometricAuth, _storage = storage;

  final Dio _dio;
  final BiometricAuthService _biometric;
  final SecureStorageService _storage;

  String _base(String office) => '/api/v1/impeachment/$office';
  String _voteBase(String office, int id) => '${_base(office)}/voting/$id';
  Map<String, dynamic> _data(Map<String, dynamic>? body) {
    final value = body?['data'];
    if (value is! Map) throw StateError('پاسخ سرور استیضاح معتبر نیست.');
    return Map<String, dynamic>.from(value);
  }

  Future<Map<String, dynamic>> list(String office, String kind, {String search = '', int? level, int? geographicId, int page = 1}) async =>
      _data((await _dio.get<Map<String, dynamic>>('${_base(office)}/processes/$kind', queryParameters: {
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (level != null) 'geographic_level_code': level,
        if (geographicId != null) 'geographic_id': geographicId,
        'page': page, 'per_page': 30,
      })).data);

  Future<Map<String, dynamic>> detail(String office, int id) async =>
      _data((await _dio.get<Map<String, dynamic>>(_voteBase(office, id))).data);

  Future<Map<String, dynamic>?> current(String office) async {
    final data = _data((await _dio.get<Map<String, dynamic>>('${_base(office)}/current')).data);
    final process = data['process'];
    return process is Map ? Map<String, dynamic>.from(process) : null;
  }

  Future<Map<String, dynamic>> results(String office, int id, {int? level, int? geographicId}) async =>
      _data((await _dio.get<Map<String, dynamic>>('${_voteBase(office, id)}/results', queryParameters: {
        if (level != null) 'geographic_level_code': level,
        if (geographicId != null) 'geographic_id': geographicId,
      })).data);

  Future<Map<String, dynamic>> request(String office, String password, String key) async =>
      _data((await _dio.post<Map<String, dynamic>>('${_base(office)}/requests', data: {
        'confirmation_method': 'password', 'password': password, 'idempotency_key': key,
      })).data);

  Future<Map<String, dynamic>> support(String office, int id, String password, String key) async =>
      _data((await _dio.post<Map<String, dynamic>>('${_base(office)}/processes/$id/support', data: {
        'confirmation_method': 'password', 'password': password, 'idempotency_key': key,
      })).data);

  String _pendingKey(String office, int id) => 'impeachment_vote_${office}_$id';
  Future<Map<String, String>?> pending(String office, int id) async {
    final value = await _storage.read(key: _pendingKey(office, id));
    if (value == null) return null;
    try {
      final map = jsonDecode(value);
      if (map is! Map) return null;
      return map.map((key, value) => MapEntry(key.toString(), value.toString()));
    } catch (_) { return null; }
  }
  Future<void> savePending(String office, int id, String choice, String issuance, String submission) =>
      _storage.write(key: _pendingKey(office, id), value: jsonEncode({'choice': choice, 'issuance': issuance, 'submission': submission}));
  Future<void> clearPending(String office, int id) => _storage.delete(key: _pendingKey(office, id));

  Future<Map<String, dynamic>> cast(String office, int id, String choice, String issuance, String submission, {String? password}) async {
    final method = password == null ? 'biometric' : 'password';
    Map<String, dynamic> payload = {'choice_key': choice, 'confirmation_method': method, 'idempotency_key': issuance};
    if (password != null) {
      payload['password'] = password;
    } else {
      final credentialId = await _biometric.localCredentialId;
      if (credentialId == null || !await _biometric.canAuthenticate || !await _biometric.isEnabledOnServer()) throw StateError('ورود بیومتریک روی این دستگاه در دسترس نیست.');
      final challenge = _data((await _dio.post<Map<String, dynamic>>('${_voteBase(office, id)}/biometric-challenge', data: {'choice_key': choice})).data);
      if (challenge['credential_id'] != credentialId) throw StateError('اعتبارنامهٔ بیومتریک این دستگاه با حساب هم‌خوان نیست.');
      payload.addAll({'challenge_id': challenge['challenge_id'], 'credential_id': credentialId, 'signature': await _biometric.signProposalPayload('${challenge['signed_payload']}')});
    }
    final token = _data((await _dio.post<Map<String, dynamic>>('${_voteBase(office, id)}/confirmation', data: payload)).data)['vote_token']?.toString();
    if (token == null || token.isEmpty) throw StateError('توکن رأی دریافت نشد.');
    return _data((await _dio.post<Map<String, dynamic>>('${_voteBase(office, id)}/votes', data: {
      'vote_token': token, 'choice_key': choice, 'issuance_idempotency_key': issuance, 'submission_idempotency_key': submission,
    })).data);
  }

  Future<Map<String, dynamic>> verifyReceipt(String number) async =>
      _data((await _dio.post<Map<String, dynamic>>('/api/v1/public/process-receipts/verify', data: {'receipt_number': number})).data);
}
