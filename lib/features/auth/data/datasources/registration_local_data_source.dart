import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/registration_draft.dart';

abstract interface class RegistrationLocalDataSource {
  Future<void> saveDraft(RegistrationDraft draft);
}

class RegistrationLocalDataSourceImpl implements RegistrationLocalDataSource {
  const RegistrationLocalDataSourceImpl(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<void> saveDraft(RegistrationDraft draft) {
    return _storage.write(
      key: 'registration_draft',
      value: jsonEncode({
        'phoneNumber': draft.phoneNumber,
        'nationalCode': draft.nationalCode,
        'countryId': draft.countryId,
        'provinceId': draft.provinceId,
        'countyId': draft.countyId,
        'localityId': draft.localityId,
        'password': draft.password,
      }),
    );
  }
}
