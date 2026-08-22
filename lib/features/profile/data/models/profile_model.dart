import '../../domain/entities/profile.dart';

class ProfileModel extends Profile {
  const ProfileModel({
    required super.nationalCode,
    required super.phoneNumber,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      nationalCode: json['national_code'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
    );
  }
}
