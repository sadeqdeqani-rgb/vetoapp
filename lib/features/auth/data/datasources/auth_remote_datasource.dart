import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../models/login_request_model.dart';

abstract interface class AuthRemoteDataSource {
  Future<Map<String, dynamic>> login(LoginRequestModel request);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio _dio;

  const AuthRemoteDataSourceImpl(this._dio);

  @override
  Future<Map<String, dynamic>> login(LoginRequestModel request) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/login',
        data: request.toJson(),
      );

      final data = response.data;

      if (data == null) {
        throw const ServerFailure('پاسخ سرور نامعتبر است');
      }

      return data;
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  Failure _mapDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return const NetworkFailure('اتصال به سرور برقرار نشد.');

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;

        if (statusCode == 401) {
          return const AuthFailure('شماره موبایل یا رمز عبور صحیح نیست.');
        }

        if (statusCode == 423) {
          return const AuthFailure('حساب کاربری شما موقتاً قفل شده است.');
        }

        return ServerFailure('خطای سرور رخ داد. کد: ${statusCode ?? 'نامشخص'}');

      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const NetworkFailure('خطا در ارتباط امن با سرور.');
    }
  }
}
