import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/public_content.dart';
import '../repositories/public_content_repository.dart';

class GetPublicIntroductionUseCase {
  const GetPublicIntroductionUseCase(this._repository);

  final PublicContentRepository _repository;

  Future<Either<Failure, PublicContent>> call() =>
      _repository.getIntroduction();
}

class GetPublicTermsUseCase {
  const GetPublicTermsUseCase(this._repository);

  final PublicContentRepository _repository;

  Future<Either<Failure, PublicContent>> call() => _repository.getTerms();
}

class GetPublicIntroductionVideoUseCase {
  const GetPublicIntroductionVideoUseCase(this._repository);

  final PublicContentRepository _repository;

  Future<Either<Failure, PublicIntroductionVideo>> call() =>
      _repository.getIntroductionVideo();
}
