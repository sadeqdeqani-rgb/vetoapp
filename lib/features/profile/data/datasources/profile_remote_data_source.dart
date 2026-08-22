import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../models/profile_model.dart';

abstract interface class ProfileRemoteDataSource {
  Future<ProfileModel> getProfile();
  Future<void> closeAccount();
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  const ProfileRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<ProfileModel> getProfile() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/profile');
      final data = response.data?['data'] ?? response.data;
      if (data is! Map<String, dynamic>) {
        throw const ServerFailure('اطلاعات حساب نامعتبر است.');
      }
      return ProfileModel.fromJson(data);
    } on DioException catch (error) {
      throw NetworkFailure('دریافت اطلاعات حساب انجام نشد: ${error.message}');
    }
  }

  @override
  Future<void> closeAccount() async {
    try {
      await _dio.post<void>('/profile/close');
    } on DioException catch (error) {
      throw ServerFailure('بستن حساب انجام نشد: ${error.message}');
    }
  }
}
