import AppKit
import WebKit

@MainActor
public final class CommuteWebWindowController: NSWindowController, WKNavigationDelegate {
    public static let shared = CommuteWebWindowController()

    public private(set) var webView: WKWebView!
    public private(set) var progressIndicator: NSProgressIndicator!

    public static let iPhoneUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"

    public init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 390, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "SKALA 출퇴근"
        window.level = .floating
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        guard let window = self.window else { return }

        let containerView = NSView(frame: window.contentView!.bounds)
        containerView.autoresizingMask = [.width, .height]

        // Top toolbar bar
        let toolbarView = NSView(frame: NSRect(x: 0, y: containerView.bounds.height - 38, width: containerView.bounds.width, height: 38))
        toolbarView.autoresizingMask = [.width, .minYMargin]

        let reloadBtn = NSButton(title: "새로고침", target: self, action: #selector(didTapReload))
        reloadBtn.bezelStyle = .rounded
        reloadBtn.frame = NSRect(x: 8, y: 6, width: 75, height: 26)
        toolbarView.addSubview(reloadBtn)

        let titleLabel = NSTextField(labelWithString: "att.skala-ai.com")
        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 90, y: 8, width: containerView.bounds.width - 180, height: 20)
        titleLabel.autoresizingMask = [.width]
        toolbarView.addSubview(titleLabel)

        progressIndicator = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: containerView.bounds.width, height: 2))
        progressIndicator.isIndeterminate = false
        progressIndicator.style = .bar
        progressIndicator.autoresizingMask = [.width]
        progressIndicator.isHidden = true
        toolbarView.addSubview(progressIndicator)

        containerView.addSubview(toolbarView)

        // WKWebView Configuration
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default() // Persistent Google SSO session

        let webFrame = NSRect(x: 0, y: 0, width: containerView.bounds.width, height: containerView.bounds.height - 38)
        webView = WKWebView(frame: webFrame, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.customUserAgent = Self.iPhoneUserAgent
        webView.navigationDelegate = self

        containerView.addSubview(webView)
        window.contentView = containerView
    }

    public func show(url: URL = CommuteService.shared.targetURL) {
        guard let window = self.window else { return }

        if webView.url == nil {
            let request = URLRequest(url: url)
            webView.load(request)
        }

        window.makeKeyAndOrderFront(nil)
        NSApp?.activate(ignoringOtherApps: true)
    }

    @objc private func didTapReload() {
        webView.reload()
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        progressIndicator.stopAnimation(nil)
        progressIndicator.isHidden = true
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        progressIndicator.stopAnimation(nil)
        progressIndicator.isHidden = true
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        progressIndicator.stopAnimation(nil)
        progressIndicator.isHidden = true
    }
}
