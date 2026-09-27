import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/geographical_area.dart';
import '../entities/registration_draft.dart';
import '../entities/registration_session.dart';

abstract interface class RegistrationRepository {
  Future<Either<Failure, List<GeographicalArea>>> children({
    int? parentId,
    String? childType,
  });
  Future<Either<Failure, void>> saveDraft(RegistrationDraft draft);
  Future<Either<Failure, RegistrationSession>> createServerDraft({
    required String phoneNumber,
    required String idempotencyKey,
  });
  Future<Either<Failure, RegistrationSession>> registrationStatus(
    RegistrationSession session,
  );
  Future<Either<Failure, Map<String, dynamic>>> validateNationalCode({
    required String draftId,
    required String nationalCode,
  });
  Future<Either<Failure, void>> submitAgeEligibilityReport({
    required String draftId,
    required String nationalCode,
    required String birthDate,
  });
}
