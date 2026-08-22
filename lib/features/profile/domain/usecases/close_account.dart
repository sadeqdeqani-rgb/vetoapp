import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/profile_repository.dart';

class CloseAccountUseCase {
  const CloseAccountUseCase(this._repository);

  final ProfileRepository _repository;

  Future<Either<Failure, void>> call() => _repository.closeAccount();
}
