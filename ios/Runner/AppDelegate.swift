import Flutter
import UIKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, SPTAppRemoteDelegate, SPTAppRemotePlayerStateDelegate {
    let SpotifyClientID = ".env['SPOTIFY_CLIENT_ID']"
        let SpotifyRedirectURL = URL(string: "spotify-ios-quick-start://spotify-login-callback")!
        
        lazy var configuration = SPTConfiguration(
          clientID: SpotifyClientID,
          redirectURL: SpotifyRedirectURL
        )
     
        private let spotifyMethodChannelName = "spotify"
        private var spotifyAppRemote: SPTAppRemote? = nil
        private var result: FlutterResult? = nil
           
        func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
          print("connected")
            self.result!("success")
        }
        
        func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
          print("disconnected")
        }
        
        func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
            print("failed " + error.debugDescription)
        }
        
        func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
          print("player state changed")
        }
    
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
