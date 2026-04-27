import Flutter
import UIKit

import GoogleMaps

GMSServices.provideAPIKey("AIzaSyBgsjMh_ojTBOMxLkSk5NSNYO7qSogbjdw")

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
