import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/profile.dart';
import '../../domain/usecases/close_account.dart';
import '../../domain/usecases/get_profile.dart';

sealed class ProfileState {
  const ProfileState();
}

class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileLoaded extends ProfileState {
  const ProfileLoaded(this.profile);

  final Profile profile;
}

class ProfileError extends ProfileState {
  const ProfileError(this.message);

  final String message;
}

class ProfileClosed extends ProfileState {
  const ProfileClosed();
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({
    required GetProfileUseCase getProfile,
    required CloseAccountUseCase closeAccount,
  }) : _getProfile = getProfile,
       _closeAccount = closeAccount,
       super(const ProfileInitial());

  final GetProfileUseCase _getProfile;
  final CloseAccountUseCase _closeAccount;

  Future<void> load() async {
    emit(const ProfileLoading());
    final result = await _getProfile();
    result.fold(
      (failure) => emit(ProfileError(failure.message)),
      (profile) => emit(ProfileLoaded(profile)),
    );
  }

  Future<void> closeAccount() async {
    emit(const ProfileLoading());
    final result = await _closeAccount();
    result.fold(
      (failure) => emit(ProfileError(failure.message)),
      (_) => emit(const ProfileClosed()),
    );
  }
}
