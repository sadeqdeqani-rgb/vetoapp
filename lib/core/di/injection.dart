import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../../features/auth/data/datasources/auth_local_data_source_impl.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/datasources/otp_remote_data_source.dart';
import '../../features/auth/data/datasources/registration_local_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/data/repositories/auth_session_repository_impl.dart';
import '../../features/auth/data/repositories/otp_repository_impl.dart';
import '../../features/auth/data/repositories/registration_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/repositories/auth_session_repository.dart';
import '../../features/auth/domain/repositories/otp_repository.dart';
import '../../features/auth/domain/repositories/registration_repository.dart';
import '../../features/auth/domain/usecases/check_auth_session_usecase.dart';
import '../../features/auth/domain/usecases/clear_auth_session_usecase.dart';
import '../../features/auth/domain/usecases/load_geographical_children.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/request_otp.dart';
import '../../features/auth/domain/usecases/reset_password.dart';
import '../../features/auth/domain/usecases/save_authenticated_session_usecase.dart';
import '../../features/auth/domain/usecases/save_guest_session_usecase.dart';
import '../../features/auth/domain/usecases/save_registration_draft.dart';
import '../../features/auth/domain/usecases/verify_otp.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/cubit/otp_cubit.dart';
import '../../features/auth/presentation/cubit/registration_cubit.dart';
import '../../features/profile/data/datasources/profile_remote_data_source.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/domain/usecases/close_account.dart';
import '../../features/profile/domain/usecases/get_profile.dart';
import '../../features/profile/presentation/cubit/profile_cubit.dart';
import '../network/dio_client.dart';

final getIt = GetIt.instance;

void configureDependencies() {
  if (!getIt.isRegistered<Dio>()) {
    getIt.registerLazySingleton<Dio>(createDioClient);
  }
  if (!getIt.isRegistered<FlutterSecureStorage>()) {
    getIt.registerLazySingleton<FlutterSecureStorage>(
      () => const FlutterSecureStorage(),
    );
  }

  if (!getIt.isRegistered<AuthLocalDataSource>()) {
    getIt.registerLazySingleton<AuthLocalDataSource>(
      () => AuthLocalDataSourceImpl(getIt<FlutterSecureStorage>()),
    );
  }
  if (!getIt.isRegistered<AuthSessionRepository>()) {
    getIt.registerLazySingleton<AuthSessionRepository>(
      () => AuthSessionRepositoryImpl(getIt<AuthLocalDataSource>()),
    );
  }
  if (!getIt.isRegistered<AuthRemoteDataSource>()) {
    getIt.registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(getIt<Dio>()),
    );
  }
  if (!getIt.isRegistered<AuthRepository>()) {
    getIt.registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(getIt<AuthRemoteDataSource>()),
    );
  }
  if (!getIt.isRegistered<OtpRemoteDataSource>()) {
    getIt.registerLazySingleton<OtpRemoteDataSource>(
      () => OtpRemoteDataSourceImpl(getIt<Dio>()),
    );
  }
  if (!getIt.isRegistered<OtpRepository>()) {
    getIt.registerLazySingleton<OtpRepository>(
      () => OtpRepositoryImpl(getIt<OtpRemoteDataSource>()),
    );
  }

  if (!getIt.isRegistered<RegistrationLocalDataSource>()) {
    getIt.registerLazySingleton<RegistrationLocalDataSource>(
      () => RegistrationLocalDataSourceImpl(getIt<FlutterSecureStorage>()),
    );
  }
  if (!getIt.isRegistered<RegistrationRepository>()) {
    getIt.registerLazySingleton<RegistrationRepository>(
      () => RegistrationRepositoryImpl(
        getIt<Dio>(),
        getIt<RegistrationLocalDataSource>(),
      ),
    );
  }

  if (!getIt.isRegistered<ProfileRemoteDataSource>()) {
    getIt.registerLazySingleton<ProfileRemoteDataSource>(
      () => ProfileRemoteDataSourceImpl(getIt<Dio>()),
    );
  }
  if (!getIt.isRegistered<ProfileRepository>()) {
    getIt.registerLazySingleton<ProfileRepository>(
      () => ProfileRepositoryImpl(getIt<ProfileRemoteDataSource>()),
    );
  }

  getIt
    ..registerLazySingleton(() => LoginUseCase(getIt<AuthRepository>()))
    ..registerLazySingleton(
      () => CheckAuthSessionUseCase(getIt<AuthSessionRepository>()),
    )
    ..registerLazySingleton(
      () => SaveAuthenticatedSessionUseCase(getIt<AuthSessionRepository>()),
    )
    ..registerLazySingleton(
      () => SaveGuestSessionUseCase(getIt<AuthSessionRepository>()),
    )
    ..registerLazySingleton(
      () => ClearAuthSessionUseCase(getIt<AuthSessionRepository>()),
    )
    ..registerLazySingleton(() => RequestOtpUseCase(getIt<OtpRepository>()))
    ..registerLazySingleton(() => VerifyOtpUseCase(getIt<OtpRepository>()))
    ..registerLazySingleton(() => ResetPasswordUseCase(getIt<OtpRepository>()))
    ..registerLazySingleton(
      () => LoadGeographicalChildrenUseCase(getIt<RegistrationRepository>()),
    )
    ..registerLazySingleton(
      () => SaveRegistrationDraftUseCase(getIt<RegistrationRepository>()),
    )
    ..registerLazySingleton(() => GetProfileUseCase(getIt<ProfileRepository>()))
    ..registerLazySingleton(
      () => CloseAccountUseCase(getIt<ProfileRepository>()),
    );

  if (!getIt.isRegistered<AuthCubit>()) {
    getIt.registerLazySingleton(
      () => AuthCubit(
        checkSession: getIt<CheckAuthSessionUseCase>(),
        loginUseCase: getIt<LoginUseCase>(),
        saveAuthenticatedSession: getIt<SaveAuthenticatedSessionUseCase>(),
        saveGuestSession: getIt<SaveGuestSessionUseCase>(),
        clearSession: getIt<ClearAuthSessionUseCase>(),
      ),
    );
  }
  if (!getIt.isRegistered<OtpCubit>()) {
    getIt.registerFactory(
      () => OtpCubit(
        requestOtp: getIt<RequestOtpUseCase>(),
        verifyOtp: getIt<VerifyOtpUseCase>(),
        resetPassword: getIt<ResetPasswordUseCase>(),
      ),
    );
  }
  if (!getIt.isRegistered<RegistrationCubit>()) {
    getIt.registerFactory(
      () => RegistrationCubit(
        loadChildren: getIt<LoadGeographicalChildrenUseCase>(),
        saveDraft: getIt<SaveRegistrationDraftUseCase>(),
      ),
    );
  }
  if (!getIt.isRegistered<ProfileCubit>()) {
    getIt.registerFactory(
      () => ProfileCubit(
        getProfile: getIt<GetProfileUseCase>(),
        closeAccount: getIt<CloseAccountUseCase>(),
      ),
    );
  }
}
