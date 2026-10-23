import Flutter
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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SensitiveClipboard") {
      SensitiveClipboard.register(with: registrar)
    }
  }
}

/// The native side of `SensitiveClipboard` (lib/shared/utils/sensitive_clipboard.dart): a copied result or key value
/// expires after the time the Dart side sends and stays on this device, so Universal Clipboard does not carry it to
/// the user's other devices. No error carries the copied text.
final class SensitiveClipboard: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "org.libredb.mobile/sensitive_clipboard", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(SensitiveClipboard(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "copy" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let arguments = call.arguments as? [String: Any],
      let text = arguments["text"] as? String,
      let seconds = arguments["expiresInSeconds"] as? Int
    else {
      result(FlutterError(code: "bad_arguments", message: "copy needs a text and an expiry", details: nil))
      return
    }
    var options: [UIPasteboard.OptionsKey: Any] = [.expirationDate: Date().addingTimeInterval(TimeInterval(seconds))]
    if arguments["localOnly"] as? Bool == true {
      options[.localOnly] = true
    }
    UIPasteboard.general.setItems([["public.utf8-plain-text": text]], options: options)
    result(nil)
  }
}
