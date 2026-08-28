import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/geographical_area.dart';
import '../../domain/entities/registration_draft.dart';
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
      await _localDataSource.saveDraft(draft);
      return const Right(null);
    } catch (_) {
      return const Left(ServerFailure('ذخیره اطلاعات ثبت‌نام انجام نشد.'));
    }
  }
}
