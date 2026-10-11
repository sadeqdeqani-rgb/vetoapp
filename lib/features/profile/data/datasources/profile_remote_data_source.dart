import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../models/profile_model.dart';

abstract interface class ProfileRemoteDataSource {
  Future<ProfileModel> getProfile();
  Future<List<Map<String, dynamic>>> getReceipts();
  Future<Map<String, dynamic>> verifyReceipt(String receiptNumber);
  Future<Map<String, dynamic>> getNotifications();
  Future<void> markNotificationRead(String notificationId);
  Future<void> verifyPassword(String currentPassword);
  Future<void> changePassword(String currentPassword, String newPassword);
  Future<Map<String, dynamic>> getGeography();
  Future<Map<String, dynamic>> changeGeography(int settlementId);
  Future<Map<String, dynamic>> getClosurePolicy();
  Future<void> closeAccount(String password);
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  const ProfileRemoteDataSourceImpl(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> _get(String path) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(path);
      final data = response.data?['data'];
      if (data is Map<String, dynamic>) return data;
      throw const ServerFailure('پاسخ سرور نامعتبر است.');
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  Future<Map<String, dynamic>> _getPage(String path) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(path);
      final data = response.data?['data'];
      if (data is Map<String, dynamic>) return data;
      throw const ServerFailure('پاسخ سرور نامعتبر است.');
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: body);
      return response.data ?? {};
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  Failure _failure(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty)
          return ServerFailure(first.first.toString());
      }
      if (data['message'] is String)
        return ServerFailure(data['message'] as String);
    }
    return const NetworkFailure('اتصال به سرور برقرار نشد. دوباره تلاش کنید.');
  }

  @override
  Future<ProfileModel> getProfile() async =>
      ProfileModel.fromJson(await _get('/api/v1/profile'));

  @override
  Future<List<Map<String, dynamic>>> getReceipts() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/profile/receipts',
      );
      if (response.statusCode == 204 || response.data == null) {
        return const [];
      }

      final data = response.data?['data'];
      if (data == null) return const [];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      }
      if (data is! Map<String, dynamic>) {
        throw const ServerFailure('پاسخ فهرست فعالیت‌ها معتبر نیست.');
      }
      final items = data['items'];
      if (items is! List) return const [];
      return items.whereType<Map<String, dynamic>>().toList(growable: false);
    } on DioException catch (error) {
      // Older API deployments may not yet expose this optional inbox endpoint.
      // For a user with no receipt history, present the same empty state.
      if (error.response?.statusCode == 404) return const [];
      throw _failure(error);
    }
  }

  @override
  Future<Map<String, dynamic>> verifyReceipt(String receiptNumber) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/public/process-receipts/verify',
        data: {'receipt_number': receiptNumber.trim()},
      );
      final data = response.data?['data'];
      if (data is Map) return Map<String, dynamic>.from(data);
      throw const ServerFailure('پاسخ استعلام رسید معتبر نیست.');
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<Map<String, dynamic>> getNotifications() =>
      _getPage('/api/v1/profile/notifications');

  @override
  Future<void> markNotificationRead(String notificationId) async {
    await _post('/api/v1/profile/notifications/$notificationId/read', const {});
  }

  @override
  Future<void> verifyPassword(String currentPassword) async {
    await _post('/api/v1/profile/password/verify', {
      'current_password': currentPassword,
    });
  }

  @override
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    await _post('/api/v1/profile/password/change', {
      'current_password': currentPassword,
      'new_password': newPassword,
      'new_password_confirmation': newPassword,
    });
  }

  @override
  Future<Map<String, dynamic>> getGeography() =>
      _get('/api/v1/profile/geography');

  @override
  Future<Map<String, dynamic>> changeGeography(int settlementId) async =>
      _post('/api/v1/profile/geography', {'settlement_id': settlementId});

  @override
  Future<Map<String, dynamic>> getClosurePolicy() =>
      _get('/api/v1/profile/closure-policy');

  @override
  Future<void> closeAccount(String password) async {
    await _post('/api/v1/profile/close', {
      'password': password,
      'confirmed': true,
    });
  }
}
