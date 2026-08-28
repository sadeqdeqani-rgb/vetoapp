import 'package:dio/dio.dart';

import 'auth_session_events.dart';
import '../storage/secure_storage_service.dart';

Dio createDioClient([
  SecureStorageService? storage,
  AuthSessionExpiredNotifier? sessionEvents,
]) {
  const baseUrl = String.fromEnvironment(
    'VETO_API_BASE_URL',
    defaultValue: 'https://api.vetoapp.ir',
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
          final token = await storage.read(key: 'auth_session_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await Future.wait([
              storage.delete(key: 'auth_session_mode'),
              storage.delete(key: 'auth_session_token'),
              storage.delete(key: 'auth_user_id'),
            ]);
            sessionEvents?.expire();
          }
          handler.next(error);
        },
      ),
    );
  }

  return dio;
}
