import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final FlutterSecureStorage _secureStorage;
  static const String _sessionKey = 'auth_session_mode';

  static const String _modeAuthenticated = '1';
  static const String _modeGuest = '2';

  AuthCubit(this._secureStorage) : super(const AuthState.initial());

  Future<void> checkAuthStatus() async {
    emit(const AuthState.loading());
    try {
      final mode = await _secureStorage.read(key: _sessionKey);
      if (mode == _modeAuthenticated) {
        emit(const AuthState.authenticated());
      } else if (mode == _modeGuest) {
        emit(const AuthState.guest());
      } else {
        emit(const AuthState.unauthenticated());
      }
    } catch (e) {
      emit(AuthState.error(e.toString()));
    }
  }

  Future<void> continueAsGuest() async {
    emit(const AuthState.loading());
    try {
      await _secureStorage.write(key: _sessionKey, value: _modeGuest);
      emit(const AuthState.guest());
    } catch (e) {
      emit(AuthState.error(e.toString()));
    }
  }

  Future<void> loginSuccess() async {
    emit(const AuthState.loading());
    try {
      await _secureStorage.write(key: _sessionKey, value: _modeAuthenticated);
      emit(const AuthState.authenticated());
    } catch (e) {
      emit(AuthState.error(e.toString()));
    }
  }

  Future<void> logout() async {
    emit(const AuthState.loading());
    try {
      await _secureStorage.delete(key: _sessionKey);
      emit(const AuthState.unauthenticated());
    } catch (e) {
      emit(AuthState.error(e.toString()));
    }
  }
}
