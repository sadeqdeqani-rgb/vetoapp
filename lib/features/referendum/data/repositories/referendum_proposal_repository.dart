import 'dart:math';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../auth/data/services/biometric_auth_service.dart';
import '../../../auth/domain/entities/geographical_area.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../domain/entities/referendum_proposal.dart';

class ReferendumProposalRepository {
  ReferendumProposalRepository({
    required Dio dio,
    required BiometricAuthService biometricAuth,
    required SecureStorageService storage,
  }) : _dio = dio,
       _biometricAuth = biometricAuth,
       _storage = storage;

  final Dio _dio;
  final BiometricAuthService _biometricAuth;
  final SecureStorageService _storage;

  Future<ProposalPreview> preview(String subject) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/referendum/proposals/preview',
      data: {'subject': subject},
    );
    final data = _map(response.data)['data'];
    if (data is! Map) throw StateError('پاسخ بررسی موضوع معتبر نیست.');
    final payload = Map<String, dynamic>.from(data);
    final scopes = (payload['geographic_scopes'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (scope) => ProposalScope.fromJson(Map<String, dynamic>.from(scope)),
        )
        .toList(growable: false);
    return ProposalPreview(
      normalizedSubject: payload['normalized_subject']?.toString() ?? '',
      scopes: scopes,
    );
  }

  Future<List<ProposalCandidate>> similar({
    required String subject,
    required ProposalScope scope,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/referendum/proposals/similar',
      data: {
        'subject': subject,
        'geographic_level_code': scope.levelCode,
        'geographic_id': scope.geographicId,
      },
    );
    final data = _map(response.data)['data'];
    if (data is! Map) {
      throw StateError('پاسخ بررسی موضوع‌های مشابه معتبر نیست.');
    }
    return ((data['matches'] as List<dynamic>?) ?? const [])
        .whereType<Map>()
        .map(
          (item) => ProposalCandidate.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<List<GeographicalArea>> geographyChildren({
    int? parentId,
    required String childType,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/geographical-areas',
      queryParameters: {
        if (parentId != null) 'parent_id': parentId,
        'child_type': childType,
      },
    );
    final data = _map(response.data)['data'];
    if (data is! List) throw StateError('پاسخ حوزه‌های جغرافیایی معتبر نیست.');
    return data
        .whereType<Map>()
        .map(
          (item) => GeographicalArea(
            id: _toInt(item['id']),
            parentId:
                item['parent_id'] == null ? null : _toInt(item['parent_id']),
            name: item['name']?.toString() ?? '',
            type: item['type']?.toString() ?? '',
          ),
        )
        .toList(growable: false);
  }

  Future<ProposalPage> list({
    int? geographicLevelCode,
    int? geographicId,
    int page = 1,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/referendum/proposals',
      queryParameters: {
        if (geographicLevelCode != null)
          'geographic_level_code': geographicLevelCode,
        if (geographicId != null) 'geographic_id': geographicId,
        'page': page,
        'per_page': 50,
      },
    );
    final data = _map(response.data)['data'];
    if (data is! Map) throw StateError('پاسخ فهرست موضوع‌ها معتبر نیست.');
    final payload = Map<String, dynamic>.from(data);
    final items = (payload['items'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (row) => ReferendumProposal.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
    final pagination =
        payload['pagination'] is Map
            ? Map<String, dynamic>.from(payload['pagination'] as Map)
            : <String, dynamic>{};
    return ProposalPage(
      items: items,
      page: _toInt(pagination['page']),
      total: _toInt(pagination['total']),
    );
  }

  Future<ReferendumProposal> detail(int processId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/referendum/proposals/$processId',
    );
    return ReferendumProposal.fromJson(
      _map(response.data)['data'] as Map<String, dynamic>,
    );
  }

  Future<ProposalSupportPage> supportBreakdown({
    required int processId,
    required int geographicLevelCode,
    String search = '',
    int page = 1,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/referendum/proposals/$processId/support-breakdown',
      queryParameters: {
        'geographic_level_code': geographicLevelCode,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        'page': page,
        'per_page': 100,
      },
    );
    final data = _map(response.data)['data'];
    if (data is! Map) throw StateError('پاسخ آمار جغرافیایی معتبر نیست.');
    final payload = Map<String, dynamic>.from(data);
    final items = (payload['items'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (row) => ProposalSupportArea.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
    final pagination =
        payload['pagination'] is Map
            ? Map<String, dynamic>.from(payload['pagination'] as Map)
            : <String, dynamic>{};
    return ProposalSupportPage(
      items: items,
      total: _toInt(pagination['total']),
    );
  }

  Future<Map<String, dynamic>> supportWithPassword({
    required ReferendumProposal proposal,
    required String password,
  }) async {
    return _commit(
      ProposalCommitSelection.fromProposal(proposal),
      method: 'password',
      password: password,
    );
  }

  Future<Map<String, dynamic>> createOrSupportWithPassword({
    required ProposalCommitSelection selection,
    required String password,
  }) => _commit(selection, method: 'password', password: password);

  Future<Map<String, dynamic>> supportWithBiometrics(
    ReferendumProposal proposal,
  ) async {
    final credentialId = await _biometricAuth.localCredentialId;
    if (credentialId == null || !await _biometricAuth.canAuthenticate) {
      throw StateError('ورود بیومتریک روی این دستگاه در دسترس نیست.');
    }
    final challengeResponse = await _dio.post<Map<String, dynamic>>(
      '/api/v1/referendum/proposals/biometric-challenge',
      data: _selection(ProposalCommitSelection.fromProposal(proposal)),
    );
    final challenge = _map(challengeResponse.data)['data'];
    if (challenge is! Map) throw StateError('پاسخ چالش بیومتریک معتبر نیست.');
    final values = Map<String, dynamic>.from(challenge);
    final challengeId = values['challenge_id']?.toString();
    final serverCredentialId = values['credential_id']?.toString();
    final signedPayload = values['signed_payload']?.toString();
    if (challengeId == null ||
        serverCredentialId != credentialId ||
        signedPayload == null) {
      throw StateError('اعتبارنامهٔ بیومتریک این دستگاه با حساب هم‌خوان نیست.');
    }
    final signature = await _biometricAuth.signProposalPayload(signedPayload);
    return _commit(
      ProposalCommitSelection.fromProposal(proposal),
      method: 'biometric',
      challengeId: challengeId,
      credentialId: credentialId,
      signature: signature,
    );
  }

  Future<Map<String, dynamic>> createOrSupportWithBiometrics(
    ProposalCommitSelection selection,
  ) async {
    final credentialId = await _biometricAuth.localCredentialId;
    if (credentialId == null || !await _biometricAuth.canAuthenticate) {
      throw StateError('ورود بیومتریک روی این دستگاه در دسترس نیست.');
    }
    final challengeResponse = await _dio.post<Map<String, dynamic>>(
      '/api/v1/referendum/proposals/biometric-challenge',
      data: _selection(selection),
    );
    final challenge = _map(challengeResponse.data)['data'];
    if (challenge is! Map) throw StateError('پاسخ چالش بیومتریک معتبر نیست.');
    final values = Map<String, dynamic>.from(challenge);
    final challengeId = values['challenge_id']?.toString();
    final serverCredentialId = values['credential_id']?.toString();
    final signedPayload = values['signed_payload']?.toString();
    if (challengeId == null ||
        serverCredentialId != credentialId ||
        signedPayload == null) {
      throw StateError('اعتبارنامهٔ بیومتریک این دستگاه با حساب هم‌خوان نیست.');
    }
    final signature = await _biometricAuth.signProposalPayload(signedPayload);
    return _commit(
      selection,
      method: 'biometric',
      challengeId: challengeId,
      credentialId: credentialId,
      signature: signature,
    );
  }

  Future<Map<String, dynamic>> _commit(
    ProposalCommitSelection selection, {
    required String method,
    String? password,
    String? challengeId,
    String? credentialId,
    String? signature,
  }) async {
    final idempotencyKey = await _idempotencyKey(selection);
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/referendum/proposals/commit',
      data: {
        ..._selection(selection),
        'idempotency_key': idempotencyKey,
        'confirmation_method': method,
        if (password != null) 'password': password,
        if (challengeId != null) 'challenge_id': challengeId,
        if (credentialId != null) 'credential_id': credentialId,
        if (signature != null) 'signature': signature,
      },
    );
    final data = _map(response.data)['data'];
    if (data is! Map) throw StateError('رسید حمایت از سرور دریافت نشد.');
    await _storage.delete(key: _pendingIdempotencyStorageKey);
    return Map<String, dynamic>.from(data);
  }

  static const _pendingIdempotencyStorageKey =
      'referendum_support_pending_operation_v1';

  Future<String> _idempotencyKey(ProposalCommitSelection selection) async {
    final fingerprint = jsonEncode({
      'user_id': await _storage.read(key: 'auth_user_id'),
      'subject': selection.subject,
      'level': selection.geographicLevelCode,
      'geo': selection.geographicId,
      'existing_process_id': selection.existingProcessId,
    });
    final stored = await _storage.read(key: _pendingIdempotencyStorageKey);
    if (stored != null) {
      try {
        final saved = jsonDecode(stored);
        if (saved is Map &&
            saved['fingerprint'] == fingerprint &&
            saved['key'] is String) {
          return saved['key'] as String;
        }
      } catch (_) {}
    }
    final key = _uuidV4();
    await _storage.write(
      key: _pendingIdempotencyStorageKey,
      value: jsonEncode({'fingerprint': fingerprint, 'key': key}),
    );
    return key;
  }

  Map<String, dynamic> _selection(ProposalCommitSelection selection) => {
    'subject': selection.subject,
    'geographic_level_code': selection.geographicLevelCode,
    'geographic_id': selection.geographicId,
    if (selection.existingProcessId != null)
      'existing_process_id': selection.existingProcessId,
  };

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map<String, dynamic> ? value : <String, dynamic>{};

  static int _toInt(dynamic value) =>
      value is int ? value : int.tryParse('$value') ?? 0;

  static String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
