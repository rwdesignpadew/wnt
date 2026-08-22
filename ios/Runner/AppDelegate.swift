import Flutter
import GoogleMaps
import GoogleNavigation
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
          !apiKey.isEmpty,
          !apiKey.contains("$(") else {
      fatalError("Missing Google Maps API key (GMSApiKey).")
    }
    GMSServices.provideAPIKey(apiKey)
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    DispatchQueue.main.async {
      application.registerForRemoteNotifications()
    }
    return launched
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
