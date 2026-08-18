import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../../../core/storage/secure_storage_service.dart';
import 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  final LoginUseCase _loginUseCase;
  final SecureStorageService _secureStorage;

  LoginCubit({
    required LoginUseCase loginUseCase,
    required SecureStorageService secureStorage,
  })  : _loginUseCase = loginUseCase,
        _secureStorage = secureStorage,
        super(const LoginState.idle());

  Future<void> login({
    required String phoneNumber,
    required String password,
  }) async {
    emit(const LoginState.loading());
    final result = await _loginUseCase(
      phoneNumber: phoneNumber,
      password: password,
    );

    result.fold(
      (failure) => emit(LoginState.failure(message: failure.message)),
      (authResult) async {
        await _secureStorage.write(
          key: 'session_token',
          value: authResult.sessionToken,
        );
        emit(LoginState.success(sessionToken: authResult.sessionToken));
      },
    );
  }
}
