import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/geographical_area.dart';
import '../repositories/registration_repository.dart';

class LoadGeographicalChildrenUseCase {
  const LoadGeographicalChildrenUseCase(this._repository);

  final RegistrationRepository _repository;

  Future<Either<Failure, List<GeographicalArea>>> call({
    int? parentId,
    String? childType,
  }) => _repository.children(parentId: parentId, childType: childType);
}
