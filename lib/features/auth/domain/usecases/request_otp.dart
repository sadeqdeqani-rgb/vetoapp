import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/otp_challenge.dart';
import '../repositories/otp_repository.dart';

class RequestOtpUseCase {
  const RequestOtpUseCase(this._repository);

  final OtpRepository _repository;

  Future<Either<Failure, OtpChallenge>> call({
    required String phoneNumber,
    required OtpPurpose purpose,
  }) => _repository.request(phoneNumber: phoneNumber, purpose: purpose);
}
