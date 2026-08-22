import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/otp_challenge.dart';
import '../repositories/otp_repository.dart';

class VerifyOtpUseCase {
  const VerifyOtpUseCase(this._repository);

  final OtpRepository _repository;

  Future<Either<Failure, OtpChallenge>> call({
    required String phoneNumber,
    required String code,
    required OtpPurpose purpose,
  }) => _repository.verify(
    phoneNumber: phoneNumber,
    code: code,
    purpose: purpose,
  );
}
