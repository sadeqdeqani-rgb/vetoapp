import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/otp_repository.dart';

class ResetPasswordUseCase {
  const ResetPasswordUseCase(this._repository);

  final OtpRepository _repository;

  Future<Either<Failure, void>> call({
    required String phoneNumber,
    required String verificationToken,
    required String newPassword,
  }) => _repository.resetPassword(
    phoneNumber: phoneNumber,
    verificationToken: verificationToken,
    newPassword: newPassword,
  );
}
