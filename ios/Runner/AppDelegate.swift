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
    let privacy = FlutterMethodChannel(
      name: "kr.example.safe_korea/privacy",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    privacy.setMethodCallHandler { call, result in
      guard call.method == "excludeFamilyBackup" else {
        result(FlutterMethodNotImplemented)
        return
      }
      do {
        // sqflite on iOS stores its database in the app's Documents directory.
        var directory = try FileManager.default.url(
          for: .documentDirectory, in: .userDomainMask,
          appropriateFor: nil, create: true
        )
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        result(nil)
      } catch {
        result(FlutterError(code: "backup_exclusion_failed", message: error.localizedDescription, details: nil))
      }
    }
  }
}
