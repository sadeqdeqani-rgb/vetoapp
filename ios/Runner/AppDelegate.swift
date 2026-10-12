import Flutter
import DeviceCheck
import Security
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ActivationDeviceChannel")
    let channel = FlutterMethodChannel(name: "vetoapp/activation-device", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "getActivationDeviceIdentity" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard DCDevice.current.isSupported else {
        result(FlutterError(code: "device_check_unavailable", message: "DeviceCheck روی این دستگاه در دسترس نیست.", details: nil))
        return
      }
      guard let identifier = Self.activationIdentifier() else {
        result(FlutterError(code: "device_id_unavailable", message: "شناسه دستگاه در دسترس نیست.", details: nil))
        return
      }
      DCDevice.current.generateToken { token, error in
        DispatchQueue.main.async {
          if let error = error {
            result(FlutterError(code: "device_check_failed", message: error.localizedDescription, details: nil))
            return
          }
          guard let token = token else {
            result(FlutterError(code: "device_check_failed", message: "توکن دستگاه ایجاد نشد.", details: nil))
            return
          }
          result([
            "platform": "ios",
            "device_identifier": identifier,
            "device_check_token": token.base64EncodedString()
          ])
        }
      }
    }
  }

  private static func activationIdentifier() -> String? {
    let service = Bundle.main.bundleIdentifier ?? "com.veto.vetoapp"
    let account = "activation-device-id"
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne
    ]
    var item: CFTypeRef?
    if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
       let data = item as? Data,
       let value = String(data: data, encoding: .utf8) {
      return value
    }
    let value = UUID().uuidString.lowercased()
    let attributes: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecValueData as String: Data(value.utf8),
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    ]
    let status = SecItemAdd(attributes as CFDictionary, nil)
    if status == errSecSuccess { return value }
    // A parallel first call may have inserted the item already.
    item = nil
    if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
       let data = item as? Data {
      return String(data: data, encoding: .utf8)
    }
    return nil
  }
}
