import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../../features/auth/data/repositories/fake_auth_repository.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';

final getIt = GetIt.instance;

void configureDependencies() {
  if (!getIt.isRegistered<FlutterSecureStorage>()) {
    getIt.registerLazySingleton<FlutterSecureStorage>(
      () => const FlutterSecureStorage(),
    );
  }

  if (!getIt.isRegistered<AuthRepository>()) {
    getIt.registerLazySingleton<AuthRepository>(
      () => const FakeAuthRepository(),
    );
  }

  if (!getIt.isRegistered<AuthCubit>()) {
    getIt.registerLazySingleton<AuthCubit>(
      () => AuthCubit(getIt<FlutterSecureStorage>(), getIt<AuthRepository>()),
    );
  }
}
