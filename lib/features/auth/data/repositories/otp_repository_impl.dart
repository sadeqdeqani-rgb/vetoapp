import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/otp_challenge.dart';
import '../../domain/repositories/otp_repository.dart';
import '../datasources/otp_remote_data_source.dart';

class OtpRepositoryImpl implements OtpRepository {
  const OtpRepositoryImpl(this._remoteDataSource);

  final OtpRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, OtpChallenge>> request({
    required String phoneNumber,
    required OtpPurpose purpose,
  }) async {
    try {
      return Right(
        await _remoteDataSource.request(
          phoneNumber: phoneNumber,
          purpose: purpose,
        ),
      );
    } on Failure catch (failure) {
      return Left(failure);
    } catch (_) {
      return const Left(ServerFailure('ارسال کد تأیید انجام نشد.'));
    }
  }

  @override
  Future<Either<Failure, OtpChallenge>> verify({
    required String phoneNumber,
    required String code,
    required OtpPurpose purpose,
  }) async {
    try {
      return Right(
        await _remoteDataSource.verify(
          phoneNumber: phoneNumber,
          code: code,
          purpose: purpose,
        ),
      );
    } on Failure catch (failure) {
      return Left(failure);
    } catch (_) {
      return const Left(AuthFailure('تأیید کد انجام نشد.'));
    }
  }

  @override
  Future<Either<Failure, void>> resetPassword({
    required String phoneNumber,
    required String verificationToken,
    required String newPassword,
  }) async {
    try {
      await _remoteDataSource.resetPassword(
        phoneNumber: phoneNumber,
        verificationToken: verificationToken,
        newPassword: newPassword,
      );
      return const Right(null);
    } on Failure catch (failure) {
      return Left(failure);
    } catch (_) {
      return const Left(ServerFailure('تغییر رمز عبور انجام نشد.'));
    }
  }
}
