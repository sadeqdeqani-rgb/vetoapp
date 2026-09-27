import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/otp_challenge.dart';

abstract interface class OtpRemoteDataSource {
  Future<OtpChallenge> request({
    required String phoneNumber,
    required OtpPurpose purpose,
    String? registrationDraftId,
    String? telegramIdentityId,
  });

  Future<OtpChallenge> verify({
    required String phoneNumber,
    required String code,
    required OtpPurpose purpose,
    String? otpId,
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
    String? registrationDraftId,
    String? telegramIdentityId,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/otp/request',
        data: {
          'phone_number': phoneNumber,
          'purpose': _purpose(purpose),
          if (registrationDraftId != null)
            'registration_draft_id': registrationDraftId,
          if (telegramIdentityId != null)
            'telegram_identity_id': telegramIdentityId,
        },
      );
      final data = response.data;
      if (data == null) {
        throw const ServerFailure('پاسخ درخواست کد تأیید نامعتبر است.');
      }
      return _fromJson(data, phoneNumber, purpose);
    } on DioException catch (error) {
      throw ServerFailure(_apiError(error, 'ارسال کد تأیید انجام نشد.'));
    }
  }

  @override
  Future<OtpChallenge> verify({
    required String phoneNumber,
    required String code,
    required OtpPurpose purpose,
    String? otpId,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/otp/verify',
        data: {
          'phone_number': phoneNumber,
          'code': code,
          'purpose': _purpose(purpose),
          if (otpId != null) 'otp_id': otpId,
        },
      );
      final data = response.data;
      if (data == null) {
        throw const ServerFailure('پاسخ تأیید کد نامعتبر است.');
      }
      return _fromJson(data, phoneNumber, purpose);
    } on DioException catch (error) {
      throw AuthFailure(
        _apiError(error, 'کد تأیید معتبر نیست یا منقضی شده است.'),
      );
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
    final expiresAt = expiresAtValue is String
        ? DateTime.tryParse(expiresAtValue)
        : null;

    return OtpChallenge(
      phoneNumber: phoneNumber,
      purpose: purpose,
      expiresAt: expiresAt ?? DateTime.now().add(const Duration(seconds: 120)),
      verificationToken: json['verification_token'] as String?,
      otpId: json['otp_id']?.toString(),
      registrationDraftId: json['registration_draft_id']?.toString(),
    );
  }

  String _apiError(DioException error, String fallback) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message'];
      if (message is String &&
          message.trim().isNotEmpty &&
          message != 'The given data was invalid.') {
        return message;
      }
      final errors = data['errors'];
      if (errors is Map) {
        for (final entry in errors.entries) {
          final messages = entry.value;
          if (messages is List && messages.isNotEmpty) {
            final text = messages.first.toString();
            if (text.contains('draft') || text.contains('تلگرام')) {
              return 'برای دریافت کد، ابتدا ثبت‌نام را از طریق بات تلگرام تأیید کنید.';
            }
            return text;
          }
        }
      }
    }
    if (error.response?.statusCode == 422) {
      return 'اطلاعات ثبت‌نام پذیرفته نشد. شماره و تأیید تلگرام را بررسی کنید.';
    }
    if (error.response == null) return 'اتصال به سرور برقرار نشد.';
    return fallback;
  }
}
