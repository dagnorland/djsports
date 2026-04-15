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
        if #available(iOS 15.0, *) {
            AppleMusicNativeChannel().setup(messenger: controller.binaryMessenger)
        }
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
