import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_state.freezed.dart';

@freezed
class AuthState with _$AuthState {
  const factory AuthState.initial() = Initial;
  const factory AuthState.loading() = Loading;
  const factory AuthState.authenticated() = Authenticated;
  const factory AuthState.guest() = Guest;
  const factory AuthState.unauthenticated() = Unauthenticated;
  const factory AuthState.error(String message) = Error;
}
