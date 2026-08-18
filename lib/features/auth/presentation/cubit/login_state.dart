import 'package:freezed_annotation/freezed_annotation.dart';

part 'login_state.freezed.dart';

@freezed
sealed class LoginState with _$LoginState {
  const factory LoginState.idle() = LoginIdle;

  const factory LoginState.loading() = LoginLoading;

  const factory LoginState.success({required String sessionToken}) =
      LoginSuccess;

  const factory LoginState.failure({required String message}) = LoginFailure;
}
