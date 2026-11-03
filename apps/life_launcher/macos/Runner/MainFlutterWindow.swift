import Cocoa
import FlutterMacOS
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // #577：设置辅助窗口。第二个 engine 也要注册全部插件；窗口标题/尺寸
    // 在这里给（插件配置项只有 arguments/hiddenAtLaunch）。
    // 另挂一条最小控制通道：「完成」走原生 close，关窗不终止主窗口。
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterGeneratedPlugins(registry: controller)
      guard let window = controller.view.window else { return }
      window.title = "设置"
      window.setContentSize(NSSize(width: 560, height: 760))
      window.center()
      let channel = FlutterMethodChannel(
        name: "lifeos/desktop_window",
        binaryMessenger: controller.engine.binaryMessenger)
      channel.setMethodCallHandler { [weak window] call, result in
        guard let window = window else {
          result(FlutterMethodNotImplemented)
          return
        }
        if call.method == "close" {
          window.performClose(nil)
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    super.awakeFromNib()
  }
}
