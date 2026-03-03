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

    // Disconnect SPTAppRemote only when the app truly enters the background.
    // Using applicationDidEnterBackground (not applicationWillResignActive)
    // avoids spurious disconnects from transient focus-loss events like
    // Control Center, notification shade, incoming-call banners, or alerts.
    override func applicationDidEnterBackground(_ application: UIApplication) {
        spotifyChannel.handleAppWillResignActive()
        super.applicationDidEnterBackground(application)
    }

    // Silently re-connect SPTAppRemote as the app returns to the foreground,
    // before it becomes fully active.  If the native SPTSession is still valid
    // no auth dialog is shown — SPTAppRemote simply re-establishes the socket.
    override func applicationWillEnterForeground(_ application: UIApplication) {
        super.applicationWillEnterForeground(application)
        spotifyChannel.reconnectIfNeeded()
    }
}
