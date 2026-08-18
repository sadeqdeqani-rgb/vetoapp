// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'login_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LoginState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LoginState()';
}


}

/// @nodoc
class $LoginStateCopyWith<$Res>  {
$LoginStateCopyWith(LoginState _, $Res Function(LoginState) __);
}


/// Adds pattern-matching-related methods to [LoginState].
extension LoginStatePatterns on LoginState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( LoginIdle value)?  idle,TResult Function( LoginLoading value)?  loading,TResult Function( LoginSuccess value)?  success,TResult Function( LoginFailure value)?  failure,required TResult orElse(),}){
final _that = this;
switch (_that) {
case LoginIdle() when idle != null:
return idle(_that);case LoginLoading() when loading != null:
return loading(_that);case LoginSuccess() when success != null:
return success(_that);case LoginFailure() when failure != null:
return failure(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( LoginIdle value)  idle,required TResult Function( LoginLoading value)  loading,required TResult Function( LoginSuccess value)  success,required TResult Function( LoginFailure value)  failure,}){
final _that = this;
switch (_that) {
case LoginIdle():
return idle(_that);case LoginLoading():
return loading(_that);case LoginSuccess():
return success(_that);case LoginFailure():
return failure(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( LoginIdle value)?  idle,TResult? Function( LoginLoading value)?  loading,TResult? Function( LoginSuccess value)?  success,TResult? Function( LoginFailure value)?  failure,}){
final _that = this;
switch (_that) {
case LoginIdle() when idle != null:
return idle(_that);case LoginLoading() when loading != null:
return loading(_that);case LoginSuccess() when success != null:
return success(_that);case LoginFailure() when failure != null:
return failure(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  idle,TResult Function()?  loading,TResult Function( String sessionToken)?  success,TResult Function( String message)?  failure,required TResult orElse(),}) {final _that = this;
switch (_that) {
case LoginIdle() when idle != null:
return idle();case LoginLoading() when loading != null:
return loading();case LoginSuccess() when success != null:
return success(_that.sessionToken);case LoginFailure() when failure != null:
return failure(_that.message);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  idle,required TResult Function()  loading,required TResult Function( String sessionToken)  success,required TResult Function( String message)  failure,}) {final _that = this;
switch (_that) {
case LoginIdle():
return idle();case LoginLoading():
return loading();case LoginSuccess():
return success(_that.sessionToken);case LoginFailure():
return failure(_that.message);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  idle,TResult? Function()?  loading,TResult? Function( String sessionToken)?  success,TResult? Function( String message)?  failure,}) {final _that = this;
switch (_that) {
case LoginIdle() when idle != null:
return idle();case LoginLoading() when loading != null:
return loading();case LoginSuccess() when success != null:
return success(_that.sessionToken);case LoginFailure() when failure != null:
return failure(_that.message);case _:
  return null;

}
}

}

/// @nodoc


class LoginIdle implements LoginState {
  const LoginIdle();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginIdle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LoginState.idle()';
}


}




/// @nodoc


class LoginLoading implements LoginState {
  const LoginLoading();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginLoading);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LoginState.loading()';
}


}




/// @nodoc


class LoginSuccess implements LoginState {
  const LoginSuccess({required this.sessionToken});
  

 final  String sessionToken;

/// Create a copy of LoginState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LoginSuccessCopyWith<LoginSuccess> get copyWith => _$LoginSuccessCopyWithImpl<LoginSuccess>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginSuccess&&(identical(other.sessionToken, sessionToken) || other.sessionToken == sessionToken));
}


@override
int get hashCode => Object.hash(runtimeType,sessionToken);

@override
String toString() {
  return 'LoginState.success(sessionToken: $sessionToken)';
}


}

/// @nodoc
abstract mixin class $LoginSuccessCopyWith<$Res> implements $LoginStateCopyWith<$Res> {
  factory $LoginSuccessCopyWith(LoginSuccess value, $Res Function(LoginSuccess) _then) = _$LoginSuccessCopyWithImpl;
@useResult
$Res call({
 String sessionToken
});




}
/// @nodoc
class _$LoginSuccessCopyWithImpl<$Res>
    implements $LoginSuccessCopyWith<$Res> {
  _$LoginSuccessCopyWithImpl(this._self, this._then);

  final LoginSuccess _self;
  final $Res Function(LoginSuccess) _then;

/// Create a copy of LoginState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionToken = null,}) {
  return _then(LoginSuccess(
sessionToken: null == sessionToken ? _self.sessionToken : sessionToken // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class LoginFailure implements LoginState {
  const LoginFailure({required this.message});
  

 final  String message;

/// Create a copy of LoginState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LoginFailureCopyWith<LoginFailure> get copyWith => _$LoginFailureCopyWithImpl<LoginFailure>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginFailure&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'LoginState.failure(message: $message)';
}


}

/// @nodoc
abstract mixin class $LoginFailureCopyWith<$Res> implements $LoginStateCopyWith<$Res> {
  factory $LoginFailureCopyWith(LoginFailure value, $Res Function(LoginFailure) _then) = _$LoginFailureCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$LoginFailureCopyWithImpl<$Res>
    implements $LoginFailureCopyWith<$Res> {
  _$LoginFailureCopyWithImpl(this._self, this._then);

  final LoginFailure _self;
  final $Res Function(LoginFailure) _then;

/// Create a copy of LoginState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(LoginFailure(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
