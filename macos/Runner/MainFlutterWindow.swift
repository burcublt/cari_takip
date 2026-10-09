import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    let screen = self.screen ?? NSScreen.screens.first
    let windowFrame = screen?.visibleFrame ?? self.frame
    self.setFrame(windowFrame, display: true)
    // Arayüzün bozulmaması için en küçük pencere boyutu.
    self.minSize = NSSize(width: 920, height: 660)
  }
}
