import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._secureStorage, this._authRepository)
    : super(const AuthState.initial());

  final FlutterSecureStorage _secureStorage;
  final AuthRepository _authRepository;

  static const String _sessionModeKey = 'auth_session_mode';
  static const String _sessionTokenKey = 'auth_session_token';
  static const String _userIdKey = 'auth_user_id';

  static const String _modeAuthenticated = '1';
  static const String _modeGuest = '2';

  Future<void> checkAuthStatus() async {
    emit(const AuthState.loading());

    try {
      final mode = await _secureStorage.read(key: _sessionModeKey);

      if (mode == _modeAuthenticated) {
        emit(const AuthState.authenticated());
      } else if (mode == _modeGuest) {
        emit(const AuthState.guest());
      } else {
        emit(const AuthState.unauthenticated());
      }
    } catch (error) {
      emit(AuthState.error(error.toString()));
    }
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    emit(const AuthState.loading());

    final result = await _authRepository.login(
      phoneNumber: username,
      password: password,
    );

    return result.fold(
      (failure) {
        emit(AuthState.error(failure.message));
        return false;
      },
      (authResult) async {
        try {
          await _secureStorage.write(
            key: _sessionModeKey,
            value: _modeAuthenticated,
          );
          await _secureStorage.write(
            key: _sessionTokenKey,
            value: authResult.sessionToken,
          );
          await _secureStorage.write(key: _userIdKey, value: authResult.userId);

          emit(const AuthState.authenticated());
          return true;
        } catch (error) {
          emit(AuthState.error(error.toString()));
          return false;
        }
      },
    );
  }

  Future<void> continueAsGuest() async {
    emit(const AuthState.loading());

    try {
      // مهم: Guest نباید نشست واقعی یا session token داشته باشد.
      await _secureStorage.delete(key: _sessionTokenKey);
      await _secureStorage.delete(key: _userIdKey);

      await _secureStorage.write(key: _sessionModeKey, value: _modeGuest);

      emit(const AuthState.guest());
    } catch (error) {
      emit(AuthState.error(error.toString()));
    }
  }

  Future<void> logout() async {
    emit(const AuthState.loading());

    try {
      await _secureStorage.delete(key: _sessionModeKey);
      await _secureStorage.delete(key: _sessionTokenKey);
      await _secureStorage.delete(key: _userIdKey);

      emit(const AuthState.unauthenticated());
    } catch (error) {
      emit(AuthState.error(error.toString()));
    }
  }
}
