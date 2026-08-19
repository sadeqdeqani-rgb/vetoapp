import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_state.freezed.dart';

@freezed
class AuthState with _$AuthState {
  /// وضعیت اولیه قبل از شروع بررسی
  const factory AuthState.initial() = _Initial;

  /// در حال اعتبارسنجی توکن یا خواندن از حافظه
  const factory AuthState.loading() = _Loading;

  /// کاربر لاگین است و توکن معتبر دارد
  const factory AuthState.authenticated() = _Authenticated;

  /// کاربر لاگین نیست یا نشست منقضی شده است
  const factory AuthState.unauthenticated() = _Unauthenticated;

  /// بروز خطای امنیتی یا سیستمی
  const factory AuthState.error(String message) = _Error;
}
