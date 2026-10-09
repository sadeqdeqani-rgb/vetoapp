import 'package:flutter/services.dart';

class DeviceBiometricKeyStore {
  static const MethodChannel _channel = MethodChannel('vetoapp/biometric-key');

  Future<bool> canAuthenticate() async =>
      await _channel.invokeMethod<bool>('canAuthenticate') ?? false;

  Future<String> createKey(String credentialId) async {
    final publicKey = await _channel.invokeMethod<String>(
      'createKey',
      {'credentialId': credentialId},
    );
    if (publicKey == null || publicKey.isEmpty) {
      throw StateError('کلید بیومتریک دستگاه ساخته نشد.');
    }
    return publicKey;
  }

  Future<String> signPayload({
    required String credentialId,
    required String payload,
  }) async {
    final signature = await _channel.invokeMethod<String>(
      'sign',
      {'credentialId': credentialId, 'payload': payload},
    );
    if (signature == null || signature.isEmpty) {
      throw StateError('امضای بیومتریک ساخته نشد.');
    }
    return signature;
  }

  Future<void> deleteKey(String credentialId) async {
    await _channel.invokeMethod<void>(
      'deleteKey',
      {'credentialId': credentialId},
    );
  }
}
