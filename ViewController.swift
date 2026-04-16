import UIKit
import WebKit
import UserNotifications

class ViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {

    var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.027, green: 0.035, blue: 0.059, alpha: 1.0)

        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // Bridge JS <-> Swift
        let contentController = WKUserContentController()
        contentController.add(self, name: "notify")
        contentController.add(self, name: "vibrate")

        // Intercept Notification API -> native iOS
        let bridgeScript = """
        (function(){
          function IOSNotif(title, opts){
            try { window.webkit.messageHandlers.notify.postMessage({
              title: String(title),
              body: opts && opts.body ? String(opts.body) : ''
            }); } catch(e){}
          }
          IOSNotif.requestPermission = function(cb){ if(cb) cb('granted'); return Promise.resolve('granted'); };
          Object.defineProperty(IOSNotif, 'permission', { get: function(){ return 'granted'; } });
          window.Notification = IOSNotif;
          if (navigator.vibrate === undefined) {
            navigator.vibrate = function(){
              try { window.webkit.messageHandlers.vibrate.postMessage({}); } catch(e){}
            };
          }
        })();
        """
        contentController.addUserScript(WKUserScript(
            source: bridgeScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))
        config.userContentController = contentController

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .always
        view.addSubview(webView)

        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }

        // Load bundled index.html
        if let path = Bundle.main.path(forResource: "index", ofType: "html") {
            let url = URL(fileURLWithPath: path)
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }

    // MARK: JS -> Native bridge
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        if message.name == "notify", let dict = message.body as? [String: Any] {
            let title = dict["title"] as? String ?? "Alerta"
            let body = dict["body"] as? String ?? ""
            sendNotification(title: title, body: body)
        } else if message.name == "vibrate" {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }

    override var prefersStatusBarHidden: Bool { return false }
    override var preferredStatusBarStyle: UIStatusBarStyle { return .lightContent }
}
