import Flutter
import FirebaseCore
import FirebaseMessaging
import GoogleMaps
import GoogleNavigation
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
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

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(
      application,
      didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
    )
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    super.application(
      application,
      didFailToRegisterForRemoteNotificationsWithError: error
    )
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
