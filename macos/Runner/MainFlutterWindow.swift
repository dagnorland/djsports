import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  let spotifyChannel = SpotifyNativeChannel()
  var appleMusicChannel: AnyObject?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    spotifyChannel.setup(messenger: flutterViewController.engine.binaryMessenger)
    if #available(macOS 14.0, *) {
      let amChannel = AppleMusicNativeChannel()
      appleMusicChannel = amChannel
      amChannel.setup(
        messenger: flutterViewController.engine.binaryMessenger
      )
    }
    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
