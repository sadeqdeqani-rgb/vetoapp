import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/geographical_area.dart';
import '../../domain/entities/registration_draft.dart';
import '../../domain/usecases/load_geographical_children.dart';
import '../../domain/usecases/save_registration_draft.dart';

sealed class RegistrationState {
  const RegistrationState();
}

class RegistrationInitial extends RegistrationState {
  const RegistrationInitial();
}

class RegistrationLoading extends RegistrationState {
  const RegistrationLoading();
}

class RegistrationReady extends RegistrationState {
  const RegistrationReady();
}

class RegistrationGeographyLoaded extends RegistrationState {
  const RegistrationGeographyLoaded({
    this.countries = const [],
    this.provinces = const [],
    this.counties = const [],
    this.localities = const [],
  });

  final List<GeographicalArea> countries;
  final List<GeographicalArea> provinces;
  final List<GeographicalArea> counties;
  final List<GeographicalArea> localities;
}

class RegistrationSaved extends RegistrationState {
  const RegistrationSaved();
}

class RegistrationError extends RegistrationState {
  const RegistrationError(this.message);

  final String message;
}

class RegistrationCubit extends Cubit<RegistrationState> {
  RegistrationCubit({
    required LoadGeographicalChildrenUseCase loadChildren,
    required SaveRegistrationDraftUseCase saveDraft,
  }) : _loadChildren = loadChildren,
       _saveDraft = saveDraft,
       super(const RegistrationInitial());

  final LoadGeographicalChildrenUseCase _loadChildren;
  final SaveRegistrationDraftUseCase _saveDraft;

  Future<void> save(RegistrationDraft draft) async {
    emit(const RegistrationLoading());
    final result = await _saveDraft(draft);
    result.fold(
      (failure) => emit(RegistrationError(failure.message)),
      (_) => emit(const RegistrationSaved()),
    );
  }

  Future<void> loadChildren({
    int? parentId,
    required RegistrationLevel level,
  }) async {
    emit(const RegistrationLoading());
    final previous =
        state is RegistrationGeographyLoaded
            ? state as RegistrationGeographyLoaded
            : const RegistrationGeographyLoaded();
    final result = await _loadChildren(
      parentId: parentId,
      childType: switch (level) {
        RegistrationLevel.country => 'country',
        RegistrationLevel.province => 'province',
        RegistrationLevel.county => 'county',
        RegistrationLevel.locality => 'locality',
      },
    );
    result.fold(
      (failure) => emit(RegistrationError(failure.message)),
      (items) => emit(
        RegistrationGeographyLoaded(
          countries:
              level == RegistrationLevel.country ? items : previous.countries,
          provinces:
              level == RegistrationLevel.province ? items : previous.provinces,
          counties:
              level == RegistrationLevel.county ? items : previous.counties,
          localities:
              level == RegistrationLevel.locality ? items : previous.localities,
        ),
      ),
    );
  }
}

enum RegistrationLevel { country, province, county, locality }
