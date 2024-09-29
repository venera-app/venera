import Cocoa
import FlutterMacOS

@NSApplicationMain
class AppDelegate: FlutterAppDelegate {
  var flutterResult: FlutterResult?
  var directoryPath: URL!

  override func applicationDidFinishLaunching(_ notification: Notification) {
      let controller: FlutterViewController = mainFlutterWindow?.contentViewController as! FlutterViewController
      let methodChannel = FlutterMethodChannel(name: "venera/method_channel", binaryMessenger: controller.engine.binaryMessenger)

      methodChannel.setMethodCallHandler { (call, result) in
        switch call.method {
        case "getProxy":
          if let proxySettings = CFNetworkCopySystemProxySettings()?.takeUnretainedValue() as NSDictionary?,
            let dict = proxySettings.object(forKey: kCFNetworkProxiesHTTPProxy) as? NSDictionary,
            let host = dict.object(forKey: kCFNetworkProxiesHTTPProxy) as? String,
            let port = dict.object(forKey: kCFNetworkProxiesHTTPPort) as? Int {
            let proxyConfig = "\(host):\(port)"
            result(proxyConfig)
          } else {
            result("")
          }
        case "getDirectoryPath":
          self.flutterResult = result
          self.getDirectoryPath()
        case "stopAccessingSecurityScopedResource":
          self.directoryPath?.stopAccessingSecurityScopedResource()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    func getDirectoryPath() {
      let openPanel = NSOpenPanel()
      openPanel.canChooseDirectories = true
      openPanel.canChooseFiles = false
      openPanel.allowsMultipleSelection = false

      openPanel.begin { (result) in
        if result == .OK {
          self.directoryPath = openPanel.urls.first
          if !self.directoryPath?.startAccessingSecurityScopedResource() ?? false {
            self.flutterResult?(nil)
            return
          }
          self.flutterResult?(self.directoryPath?.path)
        } else {
          self.flutterResult?(nil)
        }
      }
    }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }
}
