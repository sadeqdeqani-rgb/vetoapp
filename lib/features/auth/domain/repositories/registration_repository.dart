import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/geographical_area.dart';
import '../entities/registration_draft.dart';

abstract interface class RegistrationRepository {
  Future<Either<Failure, List<GeographicalArea>>> children({
    int? parentId,
    String? childType,
  });
  Future<Either<Failure, void>> saveDraft(RegistrationDraft draft);
}
