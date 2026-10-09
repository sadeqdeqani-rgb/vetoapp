import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/biometric/device_biometric_key_store.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../domain/entities/auth_session.dart';

class BiometricAuthService {
  BiometricAuthService({
    required Dio dio,
    required SecureStorageService storage,
    required DeviceBiometricKeyStore keyStore,
  }) : _dio = dio,
       _storage = storage,
       _keyStore = keyStore;

  static const _credentialIdKey = 'biometric_credential_id';
  static const _phoneNumberKey = 'biometric_phone_number';

  final Dio _dio;
  final SecureStorageService _storage;
  final DeviceBiometricKeyStore _keyStore;

  Future<bool> get canAuthenticate async =>
      defaultTargetPlatform == TargetPlatform.android &&
      await _keyStore.canAuthenticate();

  Future<bool> get isConfiguredLocally async =>
      await _storage.read(key: _credentialIdKey) != null &&
      await _storage.read(key: _phoneNumberKey) != null;

  Future<String?> get localCredentialId => _storage.read(key: _credentialIdKey);

  Future<bool> isEnabledOnServer() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/auth/biometric/status',
    );
    return response.data?['data']?['enabled'] == true;
  }

  Future<String> signProposalPayload(String payload) async {
    final credentialId = await _storage.read(key: _credentialIdKey);
    if (credentialId == null || !await canAuthenticate) {
      throw StateError('ورود بیومتریک روی این دستگاه در دسترس نیست.');
    }
    return _keyStore.signPayload(credentialId: credentialId, payload: payload);
  }

  Future<void> enable(String phoneNumber) async {
    String? credentialId;
    final previousCredentialId = await _storage.read(key: _credentialIdKey);
    var keyCreated = false;
    var serverEnrolled = false;
    try {
      if (!await canAuthenticate) {
        throw StateError('در این گوشی اثر انگشت قوی و ثبت‌شده در دسترس نیست.');
      }

      final challengeResponse = await _dio.get<Map<String, dynamic>>(
        '/api/v1/auth/biometric/enrollment-challenge',
      );
      final challenge = _responseData(challengeResponse.data);
      final challengeId = challenge['challenge_id'] as String;
      final signedPayload = challenge['signed_payload'] as String;
      credentialId = challenge['credential_id'] as String;

      final publicKey = await _keyStore.createKey(credentialId);
      keyCreated = true;
      final signature = await _keyStore.signPayload(
        credentialId: credentialId,
        payload: signedPayload,
      );
      await _dio.post<void>(
        '/api/v1/auth/biometric/enroll',
        data: {
          'challenge_id': challengeId,
          'credential_id': credentialId,
          'public_key': publicKey,
          'signature': signature,
        },
      );
      serverEnrolled = true;

      await _storage.write(key: _credentialIdKey, value: credentialId);
      await _storage.write(key: _phoneNumberKey, value: phoneNumber);
      if (previousCredentialId != null &&
          previousCredentialId != credentialId) {
        try {
          await _keyStore.deleteKey(previousCredentialId);
        } catch (_) {}
      }
    } catch (_) {
      if (serverEnrolled) {
        try {
          await _dio.delete<void>('/api/v1/auth/biometric/credential');
        } catch (_) {}
      }
      if (keyCreated && credentialId != null) {
        try {
          await _keyStore.deleteKey(credentialId);
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<AuthSession> login() async {
    final credentialId = await _storage.read(key: _credentialIdKey);
    final phoneNumber = await _storage.read(key: _phoneNumberKey);
    if (credentialId == null || phoneNumber == null) {
      throw StateError('ورود با اثر انگشت برای این دستگاه فعال نشده است.');
    }
    if (!await canAuthenticate) {
      throw StateError(
        'اثر انگشت این دستگاه در دسترس نیست. با رمز عبور وارد شوید.',
      );
    }

    try {
      final challengeResponse = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/biometric/login/challenge',
        data: {'phone_number': phoneNumber},
      );
      final challenge = _responseData(challengeResponse.data);
      final challengeId = challenge['challenge_id'] as String;
      final signedPayload = challenge['signed_payload'] as String;
      final signature = await _keyStore.signPayload(
        credentialId: credentialId,
        payload: signedPayload,
      );
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/biometric/login/verify',
        data: {
          'challenge_id': challengeId,
          'credential_id': credentialId,
          'signature': signature,
        },
      );
      return _sessionFrom(response.data);
    } on DioException catch (error) {
      final data = error.response?.data;
      final serverMessage = data is Map ? data['message']?.toString() : null;
      if (error.response?.statusCode == 401) {
        throw StateError(
          'ورود بیومتریک تأیید نشد. با رمز عبور وارد شوید و تنظیم این دستگاه را بررسی کنید.',
        );
      }
      if (serverMessage != null && serverMessage.isNotEmpty) {
        throw StateError(serverMessage);
      }
      throw StateError('ارتباط با سرور برقرار نشد؛ دوباره تلاش کنید.');
    }
  }

  AuthSession _sessionFrom(Map<String, dynamic>? data) {
    final token = data?['session_token']?.toString();
    final userId = data?['user_id']?.toString();
    if (token == null || userId == null) {
      throw StateError('پاسخ ورود بیومتریک از سرور معتبر نیست.');
    }
    return AuthSession(
      mode: AuthSessionMode.authenticated,
      sessionToken: token,
      userId: userId,
    );
  }

  Future<void> disable() async {
    await _dio.delete<void>('/api/v1/auth/biometric/credential');
    final credentialId = await _storage.read(key: _credentialIdKey);
    if (credentialId != null) {
      try {
        await _keyStore.deleteKey(credentialId);
      } catch (_) {}
    }
    await _storage.delete(key: _credentialIdKey);
    await _storage.delete(key: _phoneNumberKey);
  }

  Map<String, dynamic> _responseData(Map<String, dynamic>? response) {
    final data = response?['data'];
    if (data is! Map) throw StateError('پاسخ بیومتریک سرور معتبر نیست.');
    return Map<String, dynamic>.from(data);
  }
}
