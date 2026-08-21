class LoginRequestModel {
  final String phoneNumber;
  final String password;

  const LoginRequestModel({required this.phoneNumber, required this.password});

  Map<String, dynamic> toJson() {
    return {'phone_number': phoneNumber, 'password': password};
  }
}
