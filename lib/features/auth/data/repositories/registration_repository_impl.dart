import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/geographical_area.dart';
import '../../domain/entities/registration_draft.dart';
import '../../domain/entities/registration_session.dart';
import '../../domain/repositories/registration_repository.dart';
import '../datasources/geography_seed_data.dart';
import '../datasources/registration_local_data_source.dart';
import '../models/geographical_area_model.dart';

class RegistrationRepositoryImpl implements RegistrationRepository {
  const RegistrationRepositoryImpl(this._client, this._localDataSource);

  final Dio _client;
  final RegistrationLocalDataSource _localDataSource;

  @override
  Future<Either<Failure, List<GeographicalArea>>> children({
    int? parentId,
    String? childType,
  }) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/api/v1/geographical-areas',
        queryParameters: {
          if (parentId != null) 'parent_id': parentId,
          if (childType != null) 'child_type': childType,
        },
      );
      final data = response.data?['data'];
      if (data is! List) {
        return const Left(
          ServerFailure('پاسخ حوزه‌های جغرافیایی نامعتبر است.'),
        );
      }
      return Right(
        data
            .whereType<Map<String, dynamic>>()
            .map(GeographicalAreaModel.fromJson)
            .toList(),
      );
    } on DioException {
      return Right(GeographySeedData.children(parentId: parentId));
    } catch (_) {
      return const Left(ServerFailure('دریافت حوزه‌های جغرافیایی ناموفق بود.'));
    }
  }

  @override
  Future<Either<Failure, void>> saveDraft(RegistrationDraft draft) async {
    try {
      await _client.post<void>(
        '/api/v1/auth/registration/drafts/${draft.draftId}/details',
        data: {
          'national_code': draft.nationalCode,
          'settlement_id': draft.localityId,
        },
      );
      await _client.post<void>(
        '/api/v1/auth/registration/complete',
        data: {
          'draft_id': draft.draftId,
          'telegram_identity_id': draft.telegramIdentityId,
          'password': draft.password,
        },
      );
      await _localDataSource.saveDraft(draft);
      return const Right(null);
    } on DioException catch (error) {
      return Left(ServerFailure(_registrationError(error)));
    } catch (_) {
      return const Left(ServerFailure('ذخیره اطلاعات ثبت‌نام انجام نشد.'));
    }
  }

  @override
  Future<Either<Failure, RegistrationSession>> createServerDraft({
    required String phoneNumber,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/api/v1/auth/registration/drafts',
        data: {'phone_number': phoneNumber, 'idempotency_key': idempotencyKey},
      );
      final data = response.data;
      if (data == null) {
        return const Left(ServerFailure('پاسخ ایجاد ثبت‌نام نامعتبر است.'));
      }
      return Right(RegistrationSession.fromJson(data));
    } on DioException catch (error) {
      final payload = error.response?.data;
      if (payload is Map && payload['code'] == 'mobile_already_registered') {
        return Left(
          RegistrationMobileAlreadyRegisteredFailure(
            payload['message']?.toString() ??
                'این شماره موبایل قبلاً در اپ ثبت‌نام کرده است؛ شما نمی‌توانید با این شماره ثبت‌نام جدیدی انجام دهید.',
          ),
        );
      }
      return Left(ServerFailure(_registrationError(error)));
    } catch (_) {
      return const Left(ServerFailure('شروع ثبت‌نام انجام نشد.'));
    }
  }

  @override
  Future<Either<Failure, RegistrationSession>> registrationStatus(
    RegistrationSession session,
  ) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/api/v1/auth/registration/drafts/${session.draftId}/status',
        queryParameters: {'telegram_link_nonce': session.telegramLinkNonce},
      );
      final data = response.data;
      if (data == null) {
        return const Left(ServerFailure('پاسخ وضعیت ثبت‌نام نامعتبر است.'));
      }
      return Right(
        RegistrationSession(
          draftId: session.draftId,
          telegramLinkNonce: session.telegramLinkNonce,
          telegramStartUrl: session.telegramStartUrl,
          telegramIdentityId: data['telegram_identity_id']?.toString(),
        ),
      );
    } on DioException catch (error) {
      return Left(ServerFailure(_registrationError(error)));
    } catch (_) {
      return const Left(ServerFailure('بررسی تأیید تلگرام انجام نشد.'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> validateNationalCode({
    required String draftId,
    required String nationalCode,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/api/v1/auth/registration/drafts/$draftId/validate-national-code',
        data: {'national_code': nationalCode},
      );
      return Right(response.data ?? const <String, dynamic>{});
    } on DioException catch (error) {
      final payload = error.response?.data;
      if (payload is Map && payload['code'] is String) {
        return Right(Map<String, dynamic>.from(payload));
      }
      return Left(ServerFailure(_registrationError(error)));
    } catch (_) {
      return const Left(ServerFailure('اعتبارسنجی کد ملی انجام نشد.'));
    }
  }

  @override
  Future<Either<Failure, void>> submitAgeEligibilityReport({
    required String draftId,
    required String nationalCode,
    required String birthDate,
  }) async {
    try {
      await _client.post<void>(
        '/api/v1/auth/registration/drafts/$draftId/age-eligibility-reports',
        data: {'national_code': nationalCode, 'birth_date': birthDate},
      );
      return const Right(null);
    } on DioException catch (error) {
      return Left(ServerFailure(_registrationError(error)));
    } catch (_) {
      return const Left(ServerFailure('ارسال گزارش انجام نشد.'));
    }
  }

  String _registrationError(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final errors = data['errors'];
      if (errors is Map) {
        for (final messages in errors.values) {
          if (messages is List && messages.isNotEmpty) {
            return messages.first.toString();
          }
        }
      }
      if (data['message'] is String) return data['message'] as String;
    }
    if (error.response == null) return 'اتصال به سرور برقرار نشد.';
    return 'درخواست ثبت‌نام پذیرفته نشد (کد ${error.response?.statusCode}).';
  }
}
