import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/otp_challenge.dart';

abstract interface class OtpRepository {
  Future<Either<Failure, OtpChallenge>> request({
    required String phoneNumber,
    required OtpPurpose purpose,
  });

  Future<Either<Failure, OtpChallenge>> verify({
    required String phoneNumber,
    required String code,
    required OtpPurpose purpose,
  });

  Future<Either<Failure, void>> resetPassword({
    required String phoneNumber,
    required String verificationToken,
    required String newPassword,
  });
}
