import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/check_auth_session_usecase.dart';
import '../../domain/usecases/clear_auth_session_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/save_authenticated_session_usecase.dart';
import '../../domain/usecases/save_guest_session_usecase.dart';
import '../../data/services/biometric_auth_service.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required CheckAuthSessionUseCase checkSession,
    required AuthRepository authRepository,
    required LoginUseCase loginUseCase,
    required SaveAuthenticatedSessionUseCase saveAuthenticatedSession,
    required SaveGuestSessionUseCase saveGuestSession,
    required ClearAuthSessionUseCase clearSession,
    required BiometricAuthService biometricAuth,
  }) : _checkSession = checkSession,
       _authRepository = authRepository,
       _loginUseCase = loginUseCase,
       _saveAuthenticatedSession = saveAuthenticatedSession,
       _saveGuestSession = saveGuestSession,
       _clearSession = clearSession,
       _biometricAuth = biometricAuth,
       super(const AuthState.initial());

  final CheckAuthSessionUseCase _checkSession;
  final AuthRepository _authRepository;
  final LoginUseCase _loginUseCase;
  final SaveAuthenticatedSessionUseCase _saveAuthenticatedSession;
  final SaveGuestSessionUseCase _saveGuestSession;
  final ClearAuthSessionUseCase _clearSession;
  final BiometricAuthService _biometricAuth;

  Future<void> checkAuthStatus() async {
    emit(const AuthState.loading());
    try {
      final session = await _checkSession();
      emit(_stateForSession(session));
    } catch (error) {
      emit(AuthState.error(error.toString()));
    }
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    emit(const AuthState.loading());
    final result = await _loginUseCase(
      phoneNumber: username,
      password: password,
    );

    return result.fold(
      (failure) {
        emit(AuthState.error(failure.message));
        return false;
      },
      (session) async {
        try {
          await _saveAuthenticatedSession(
            sessionToken: session.sessionToken,
            userId: session.userId,
          );
          emit(const AuthState.authenticated());
          return true;
        } catch (error) {
          emit(AuthState.error(error.toString()));
          return false;
        }
      },
    );
  }

  Future<bool> loginWithBiometrics() async {
    emit(const AuthState.loading());
    try {
      final session = await _biometricAuth.login();
      await _saveAuthenticatedSession(
        sessionToken: session.sessionToken!,
        userId: session.userId!,
      );
      emit(const AuthState.authenticated());
      return true;
    } catch (error) {
      emit(AuthState.error(error.toString().replaceFirst('Bad state: ', '')));
      return false;
    }
  }

  Future<void> continueAsGuest() async {
    emit(const AuthState.loading());
    try {
      await _saveGuestSession();
      emit(const AuthState.guest());
    } catch (error) {
      emit(AuthState.error(error.toString()));
    }
  }

  Future<void> logout() async {
    emit(const AuthState.loading());
    try {
      try {
        await _authRepository.logout().timeout(const Duration(seconds: 3));
      } catch (_) {
        // Local sign-out must still work if the API is temporarily unreachable.
      }
      await _clearSession();
      emit(const AuthState.unauthenticated());
    } catch (error) {
      emit(const AuthState.unauthenticated());
    }
  }

  Future<void> exitGuestMode() async {
    if (state is! Guest) return;
    try {
      await _clearSession();
    } catch (_) {
      // Let the current app session leave preview mode even if secure storage
      // is temporarily unavailable; the router will still allow /login.
    }
    emit(const AuthState.unauthenticated());
  }

  void expireSession() {
    emit(const AuthState.unauthenticated());
  }

  AuthState _stateForSession(AuthSession session) {
    return switch (session.mode) {
      AuthSessionMode.authenticated => const AuthState.authenticated(),
      AuthSessionMode.guest => const AuthState.guest(),
      AuthSessionMode.unauthenticated => const AuthState.unauthenticated(),
    };
  }
}
