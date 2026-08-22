import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/otp_challenge.dart';
import '../../domain/usecases/request_otp.dart';
import '../../domain/usecases/reset_password.dart';
import '../../domain/usecases/verify_otp.dart';

sealed class OtpState {
  const OtpState();
}

class OtpInitial extends OtpState {
  const OtpInitial();
}

class OtpLoading extends OtpState {
  const OtpLoading();
}

class OtpRequested extends OtpState {
  const OtpRequested(this.challenge);

  final OtpChallenge challenge;
}

class OtpVerified extends OtpState {
  const OtpVerified(this.challenge);

  final OtpChallenge challenge;
}

class OtpPasswordReset extends OtpState {
  const OtpPasswordReset();
}

class OtpError extends OtpState {
  const OtpError(this.message);

  final String message;
}

class OtpCubit extends Cubit<OtpState> {
  OtpCubit({
    required RequestOtpUseCase requestOtp,
    required VerifyOtpUseCase verifyOtp,
    required ResetPasswordUseCase resetPassword,
  }) : _requestOtp = requestOtp,
       _verifyOtp = verifyOtp,
       _resetPassword = resetPassword,
       super(const OtpInitial());

  final RequestOtpUseCase _requestOtp;
  final VerifyOtpUseCase _verifyOtp;
  final ResetPasswordUseCase _resetPassword;

  Future<void> request({
    required String phoneNumber,
    required OtpPurpose purpose,
  }) async {
    emit(const OtpLoading());
    final result = await _requestOtp(phoneNumber: phoneNumber, purpose: purpose);
    result.fold(
      (failure) => emit(OtpError(failure.message)),
      (challenge) => emit(OtpRequested(challenge)),
    );
  }

  Future<void> verify({
    required String phoneNumber,
    required String code,
    required OtpPurpose purpose,
  }) async {
    emit(const OtpLoading());
    final result = await _verifyOtp(
      phoneNumber: phoneNumber,
      code: code,
      purpose: purpose,
    );
    result.fold(
      (failure) => emit(OtpError(failure.message)),
      (challenge) => emit(OtpVerified(challenge)),
    );
  }

  Future<void> resetPassword({
    required String phoneNumber,
    required String verificationToken,
    required String newPassword,
  }) async {
    emit(const OtpLoading());
    final result = await _resetPassword(
      phoneNumber: phoneNumber,
      verificationToken: verificationToken,
      newPassword: newPassword,
    );
    result.fold(
      (failure) => emit(OtpError(failure.message)),
      (_) => emit(const OtpPasswordReset()),
    );
  }
}
