import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/telegram_password_recovery.dart';
import '../../domain/repositories/telegram_password_recovery_repository.dart';

class TelegramPasswordRecoveryRepositoryImpl
    implements TelegramPasswordRecoveryRepository {
  const TelegramPasswordRecoveryRepositoryImpl(this._client);

  final Dio _client;

  @override
  Future<Either<Failure, TelegramPasswordRecoveryChallenge>> start({
    required String phoneNumber,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/api/v1/auth/password-recovery/telegram',
        data: {'phone_number': phoneNumber},
      );
      final data = response.data;
      final startUrl = data?['telegram_start_url']?.toString();
      if (data == null || startUrl == null || startUrl.isEmpty) {
        return const Left(
          ServerFailure('نشانی ربات بازیابی رمز روی سرور تنظیم نشده است.'),
        );
      }

      final startParameter = Uri.tryParse(startUrl)?.queryParameters['start'];
      if (startParameter == null || !startParameter.startsWith('reset-')) {
        return const Left(
          ServerFailure('پیوند امن بازیابی رمز از سرور معتبر نیست.'),
        );
      }
      final nonce = startParameter.substring('reset-'.length);
      if (nonce.isEmpty) {
        return const Left(
          ServerFailure('شناسهٔ درخواست بازیابی از پیوند تلگرام دریافت نشد.'),
        );
      }

      final expiresAt = DateTime.tryParse(
        data['expires_at']?.toString() ?? '',
      );
      if (expiresAt == null) {
        return const Left(
          ServerFailure('مهلت درخواست بازیابی از سرور معتبر نیست.'),
        );
      }

      return Right(
        TelegramPasswordRecoveryChallenge(
          nonce: nonce,
          telegramStartUrl: startUrl,
          expiresAt: expiresAt,
        ),
      );
    } on DioException catch (error) {
      return Left(ServerFailure(_errorMessage(error)));
    } catch (_) {
      return const Left(ServerFailure('شروع بازیابی رمز انجام نشد.'));
    }
  }

  @override
  Future<Either<Failure, TelegramPasswordRecoveryStatus>> status({
    required String nonce,
  }) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/api/v1/auth/password-recovery/telegram/status',
        queryParameters: {'nonce': nonce},
      );
      final data = response.data;
      final state = data?['state']?.toString();
      if (data == null || state == null || state.isEmpty) {
        return const Left(
          ServerFailure('وضعیت بازیابی رمز از سرور معتبر نیست.'),
        );
      }

      return Right(
        TelegramPasswordRecoveryStatus(
          state: state,
          otpId: data['otp_id']?.toString(),
        ),
      );
    } on DioException catch (error) {
      return Left(ServerFailure(_errorMessage(error)));
    } catch (_) {
      return const Left(ServerFailure('بررسی تأیید تلگرام انجام نشد.'));
    }
  }

  String _errorMessage(DioException error) {
    final payload = error.response?.data;
    if (payload is Map) {
      final message = payload['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
      final errors = payload['errors'];
      if (errors is Map) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) {
            return value.first.toString();
          }
        }
      }
    }
    return 'ارتباط با سرور بازیابی رمز برقرار نشد.';
  }
}
