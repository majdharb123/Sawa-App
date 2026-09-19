import UIKit
import Flutter
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    guard let googleMapsApiKey = Bundle.main.object(
      forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY"
    ) as? String, !googleMapsApiKey.isEmpty else {
      fatalError("GOOGLE_MAPS_API_KEY is not configured.")
    }

    GMSServices.provideAPIKey(googleMapsApiKey)
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}