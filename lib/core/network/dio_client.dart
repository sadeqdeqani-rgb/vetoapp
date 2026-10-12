import 'package:dio/dio.dart';

import 'auth_session_events.dart';
import '../storage/secure_storage_service.dart';

Dio createDioClient([
  SecureStorageService? storage,
  AuthSessionExpiredNotifier? sessionEvents,
]) {
  const baseUrl = String.fromEnvironment(
    'VETO_API_BASE_URL',
    defaultValue: 'https://api.vetoapp.net',
  );

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  if (storage != null) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Login, registration, OTP, and public content must not depend on
          // secure storage being readable. In particular, Android Keystore
          // failures must not prevent the login request from reaching Laravel.
          if (_requiresUserSession(options.path)) {
            try {
              final token = await storage.read(key: 'auth_session_token');
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }
            } catch (_) {
              options.headers.remove('Authorization');
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final attachedSessionToken =
              error.requestOptions.headers['Authorization'] is String &&
              (error.requestOptions.headers['Authorization'] as String)
                  .startsWith('Bearer ');
          if (error.response?.statusCode == 401 &&
              _requiresUserSession(error.requestOptions.path) &&
              attachedSessionToken) {
            try {
              await Future.wait([
                storage.delete(key: 'auth_session_mode'),
                storage.delete(key: 'auth_session_token'),
                storage.delete(key: 'auth_user_id'),
              ]);
            } catch (_) {
              // Preserve the original HTTP 401 response if local storage fails.
            }
            sessionEvents?.expire();
          }
          handler.next(error);
        },
      ),
    );
  }

  return dio;
}

bool _requiresUserSession(String path) {
  final normalizedPath = path.startsWith('/') ? path : '/$path';
  return normalizedPath == '/api/v1/dashboard/summary' ||
      normalizedPath == '/api/v1/auth/logout' ||
      normalizedPath == '/api/v1/auth/session/heartbeat' ||
      normalizedPath == '/api/v1/auth/biometric/status' ||
      normalizedPath == '/api/v1/auth/biometric/enrollment-challenge' ||
      normalizedPath == '/api/v1/auth/biometric/enroll' ||
      normalizedPath == '/api/v1/auth/biometric/credential' ||
      normalizedPath == '/api/v1/profile' ||
      normalizedPath.startsWith('/api/v1/profile/') ||
      normalizedPath.startsWith('/api/v1/referendum/') ||
      normalizedPath.startsWith('/api/v1/elections/') ||
      normalizedPath.startsWith('/api/v1/impeachment/');
}
