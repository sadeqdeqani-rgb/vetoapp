import 'package:dio/dio.dart';

Dio createDioClient() {
  const baseUrl = String.fromEnvironment(
    'VETO_API_BASE_URL',
    defaultValue: 'https://api.vetoapp.ir',
  );

  return Dio(
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
}
