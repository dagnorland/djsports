import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    let spotifyChannel = SpotifyNativeChannel()

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController
        spotifyChannel.setup(messenger: controller.binaryMessenger)
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    override func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        let handled = spotifyChannel.application(app, open: url, options: options)
        return handled || super.application(app, open: url, options: options)
    }
}
