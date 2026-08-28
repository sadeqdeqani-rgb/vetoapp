import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/public_content.dart';

abstract interface class PublicContentRepository {
  Future<Either<Failure, PublicContent>> getIntroduction();

  Future<Either<Failure, PublicContent>> getTerms();

  Future<Either<Failure, PublicIntroductionVideo>> getIntroductionVideo();
}
