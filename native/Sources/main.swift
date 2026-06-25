// powertoy — native macOS shell. A WKWebView hosting the bundled single-file app.
// No npm, no Rust, no Electron: just AppKit + WebKit, ~hundreds of KB.
import Cocoa
import WebKit
import CoreWLAN
import CoreLocation
import Darwin

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKScriptMessageHandlerWithReply {
    var window: NSWindow!
    var webView: WKWebView!
    let loc = CLLocationManager()   // CoreWLAN needs Location authorization for SSID/RSSI on modern macOS

    func applicationDidFinishLaunching(_ note: Notification) {
        loc.requestWhenInUseAuthorization()
        let frame = NSRect(x: 0, y: 0, width: 1200, height: 820)
        window = NSWindow(contentRect: frame,
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "powertoy"
        window.setFrameAutosaveName("powertoyMain")
        window.center()
        window.minSize = NSSize(width: 760, height: 480)

        let cfg = WKWebViewConfiguration()
        cfg.preferences.setValue(true, forKey: "developerExtrasEnabled")
        // bridges: window.webkit.messageHandlers.{wifi,device}.postMessage('get')
        cfg.userContentController.addScriptMessageHandler(self, contentWorld: .page, name: "wifi")
        cfg.userContentController.addScriptMessageHandler(self, contentWorld: .page, name: "device")
        webView = WKWebView(frame: frame, configuration: cfg)
        webView.navigationDelegate = self
        webView.autoresizingMask = [.width, .height]
        window.contentView = webView

        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // Open external links (the shell-equivalent hints, docs) in the real browser.
    func webView(_ wv: WKWebView, decidePolicyFor nav: WKNavigationAction,
                 decisionHandler done: @escaping (WKNavigationActionPolicy) -> Void) {
        if let u = nav.request.url, nav.navigationType == .linkActivated,
           u.scheme == "http" || u.scheme == "https" {
            NSWorkspace.shared.open(u); done(.cancel); return
        }
        done(.allow)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }

    // Native bridges — reply to the JS promise with live system data.
    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage,
                              replyHandler: @escaping (Any?, String?) -> Void) {
        switch message.name {
        case "wifi":
            guard let i = CWWiFiClient.shared().interface() else { replyHandler(nil, "no WiFi interface"); return }
            var d: [String: Any] = ["interface": i.interfaceName ?? "—"]
            if let ssid = i.ssid() { d["ssid"] = ssid }
            d["rssi"] = i.rssiValue()
            d["noise"] = i.noiseMeasurement()
            d["txRate"] = i.transmitRate()
            if let ch = i.wlanChannel() {
                d["channel"] = ch.channelNumber
                switch ch.channelBand {
                case .band2GHz: d["band"] = "2.4 GHz"
                case .band5GHz: d["band"] = "5 GHz"
                case .band6GHz: d["band"] = "6 GHz"
                default: break
                }
            }
            replyHandler(d, nil)
        case "device":
            replyHandler(["hostname": ProcessInfo.processInfo.hostName, "localIPs": localIPv4()], nil)
        default:
            replyHandler(nil, "unknown handler")
        }
    }

    // Non-loopback IPv4 addresses per interface, via getifaddrs.
    func localIPv4() -> [String] {
        var out: [String] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return out }
        defer { freeifaddrs(ifaddr) }
        var ptr = ifaddr
        while let p = ptr {
            let ifa = p.pointee
            ptr = ifa.ifa_next
            guard let sa = ifa.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET) else { continue }
            if (ifa.ifa_flags & UInt32(IFF_LOOPBACK)) != 0 { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                let ip = String(cString: host)
                if !ip.isEmpty { out.append("\(String(cString: ifa.ifa_name)): \(ip)") }
            }
        }
        return out
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate

// Minimal menu so ⌘Q / ⌘W / ⌘C / ⌘V work.
let menu = NSMenu()
let appItem = NSMenuItem(); menu.addItem(appItem)
let appMenu = NSMenu()
appMenu.addItem(withTitle: "Quit powertoy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
appItem.submenu = appMenu
let editItem = NSMenuItem(); menu.addItem(editItem)
let editMenu = NSMenu(title: "Edit")
editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
editItem.submenu = editMenu
app.mainMenu = menu

app.run()
