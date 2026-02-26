import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  let spotifyChannel = SpotifyNativeChannel()

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    spotifyChannel.setup(messenger: flutterViewController.engine.binaryMessenger)
    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
