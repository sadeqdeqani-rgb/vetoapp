import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_data_source.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl(this._remoteDataSource);

  final ProfileRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, Profile>> getProfile() async {
    try {
      return Right(await _remoteDataSource.getProfile());
    } on Failure catch (failure) {
      return Left(failure);
    } catch (_) {
      return const Left(ServerFailure('دریافت اطلاعات حساب ناموفق بود.'));
    }
  }

  @override
  Future<Either<Failure, void>> closeAccount() async {
    try {
      await _remoteDataSource.closeAccount();
      return const Right(null);
    } on Failure catch (failure) {
      return Left(failure);
    } catch (_) {
      return const Left(ServerFailure('بستن حساب ناموفق بود.'));
    }
  }
}
