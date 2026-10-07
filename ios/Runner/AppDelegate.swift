import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    let spotifyChannel = SpotifyNativeChannel()

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // UIScene lifecycle (required on iOS 27+): the engine is created by the
    // scene, so plugins and native channels are registered here instead of
    // in didFinishLaunchingWithOptions.
    func didInitializeImplicitFlutterEngine(
        _ engineBridge: FlutterImplicitEngineBridge
    ) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        guard let registrar = engineBridge.pluginRegistry.registrar(
            forPlugin: "DjsportsNativeChannels"
        ) else { return }
        let messenger = registrar.messenger()
        spotifyChannel.setup(messenger: messenger)
        if #available(iOS 15.0, *) {
            AppleMusicNativeChannel().setup(messenger: messenger)
        }
    }
}
