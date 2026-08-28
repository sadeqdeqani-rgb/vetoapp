import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/otp_challenge.dart';

abstract interface class OtpRemoteDataSource {
  Future<OtpChallenge> request({
    required String phoneNumber,
    required OtpPurpose purpose,
  });

  Future<OtpChallenge> verify({
    required String phoneNumber,
    required String code,
    required OtpPurpose purpose,
  });

  Future<void> resetPassword({
    required String phoneNumber,
    required String verificationToken,
    required String newPassword,
  });
}

class OtpRemoteDataSourceImpl implements OtpRemoteDataSource {
  const OtpRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  String _purpose(OtpPurpose purpose) => switch (purpose) {
    OtpPurpose.registration => 'registration',
    OtpPurpose.login => 'login',
    OtpPurpose.passwordRecovery => 'password_recovery',
  };

  @override
  Future<OtpChallenge> request({
    required String phoneNumber,
    required OtpPurpose purpose,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/otp/request',
        data: {'phone_number': phoneNumber, 'purpose': _purpose(purpose)},
      );
      final data = response.data;
      if (data == null) {
        throw const ServerFailure('پاسخ درخواست کد تأیید نامعتبر است.');
      }
      return _fromJson(data, phoneNumber, purpose);
    } on DioException catch (error) {
      throw ServerFailure('خطا در ارسال کد تأیید: ${error.message ?? ''}');
    }
  }

  @override
  Future<OtpChallenge> verify({
    required String phoneNumber,
    required String code,
    required OtpPurpose purpose,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/otp/verify',
        data: {
          'phone_number': phoneNumber,
          'code': code,
          'purpose': _purpose(purpose),
        },
      );
      final data = response.data;
      if (data == null) {
        throw const ServerFailure('پاسخ تأیید کد نامعتبر است.');
      }
      return _fromJson(data, phoneNumber, purpose);
    } on DioException catch (error) {
      throw AuthFailure('کد تأیید معتبر نیست: ${error.message ?? ''}');
    }
  }

  @override
  Future<void> resetPassword({
    required String phoneNumber,
    required String verificationToken,
    required String newPassword,
  }) async {
    try {
      await _dio.post<void>(
        '/api/v1/auth/password/reset',
        data: {
          'phone_number': phoneNumber,
          'verification_token': verificationToken,
          'new_password': newPassword,
        },
      );
    } on DioException catch (error) {
      throw ServerFailure('تغییر رمز عبور انجام نشد: ${error.message ?? ''}');
    }
  }

  OtpChallenge _fromJson(
    Map<String, dynamic> json,
    String phoneNumber,
    OtpPurpose purpose,
  ) {
    final expiresAtValue = json['expires_at'];
    final expiresAt =
        expiresAtValue is String ? DateTime.tryParse(expiresAtValue) : null;

    return OtpChallenge(
      phoneNumber: phoneNumber,
      purpose: purpose,
      expiresAt: expiresAt ?? DateTime.now().add(const Duration(seconds: 120)),
      verificationToken: json['verification_token'] as String?,
    );
  }
}
