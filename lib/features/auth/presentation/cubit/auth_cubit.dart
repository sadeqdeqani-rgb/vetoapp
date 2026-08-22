import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/auth_session.dart';
import '../../domain/usecases/check_auth_session_usecase.dart';
import '../../domain/usecases/clear_auth_session_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/save_authenticated_session_usecase.dart';
import '../../domain/usecases/save_guest_session_usecase.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required CheckAuthSessionUseCase checkSession,
    required LoginUseCase loginUseCase,
    required SaveAuthenticatedSessionUseCase saveAuthenticatedSession,
    required SaveGuestSessionUseCase saveGuestSession,
    required ClearAuthSessionUseCase clearSession,
  }) : _checkSession = checkSession,
       _loginUseCase = loginUseCase,
       _saveAuthenticatedSession = saveAuthenticatedSession,
       _saveGuestSession = saveGuestSession,
       _clearSession = clearSession,
       super(const AuthState.initial());

  final CheckAuthSessionUseCase _checkSession;
  final LoginUseCase _loginUseCase;
  final SaveAuthenticatedSessionUseCase _saveAuthenticatedSession;
  final SaveGuestSessionUseCase _saveGuestSession;
  final ClearAuthSessionUseCase _clearSession;

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
      await _clearSession();
      emit(const AuthState.unauthenticated());
    } catch (error) {
      emit(AuthState.error(error.toString()));
    }
  }

  AuthState _stateForSession(AuthSession session) {
    return switch (session.mode) {
      AuthSessionMode.authenticated => const AuthState.authenticated(),
      AuthSessionMode.guest => const AuthState.guest(),
      AuthSessionMode.unauthenticated => const AuthState.unauthenticated(),
    };
  }
}
