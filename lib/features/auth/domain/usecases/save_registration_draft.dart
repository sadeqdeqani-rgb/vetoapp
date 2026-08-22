import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/registration_draft.dart';
import '../repositories/registration_repository.dart';

class SaveRegistrationDraftUseCase {
  const SaveRegistrationDraftUseCase(this._repository);

  final RegistrationRepository _repository;

  Future<Either<Failure, void>> call(RegistrationDraft draft) =>
      _repository.saveDraft(draft);
}
