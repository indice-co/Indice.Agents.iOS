import SwiftUI
import WebKit

/// HTML has its own renderer; it must never be concatenated into a Text label.
/// The nonpersistent WebKit view has no identity cookies, native message bridge,
/// or content JavaScript. App-authored JavaScript is used only to measure height.
struct ChatHTMLView: View {
    let html: String
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @State private var contentHeight: CGFloat = 1

    var body: some View {
        HTMLFragmentView(
            html: html,
            isDark: colorScheme == .dark,
            height: $contentHeight,
            openLink: { url in openURL(url) })
        .frame(maxWidth: .infinity)
        .frame(height: contentHeight)
    }
}

private struct HTMLFragmentView: UIViewRepresentable {
    let html: String
    let isDark: Bool
    @Binding var height: CGFloat
    let openLink: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(height: $height, openLink: openLink) }

    func makeUIView(context: Context) -> ContentWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = ContentWebView(frame: .zero, configuration: configuration)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        view.scrollView.isScrollEnabled = false
        view.navigationDelegate = context.coordinator
        view.onWidthChange = { [weak coordinator = context.coordinator, weak view] in
            guard let view else { return }
            coordinator?.measure(view)
        }
        context.coordinator.observation = view.scrollView.observe(\.contentSize, options: [.new]) { [weak coordinator = context.coordinator, weak view] _, _ in
            Task { @MainActor [weak coordinator, weak view] in
                guard let view else { return }
                coordinator?.measure(view)
            }
        }
        return view
    }

    func updateUIView(_ view: ContentWebView, context: Context) {
        context.coordinator.height = $height
        context.coordinator.openLink = openLink
        let document = Self.document(html, isDark: isDark)
        guard context.coordinator.document != document else { return }
        context.coordinator.document = document
        context.coordinator.generation += 1
        view.loadHTMLString(document, baseURL: nil)
    }

    static func dismantleUIView(_ view: ContentWebView, coordinator: Coordinator) {
        coordinator.observation = nil
        view.onWidthChange = nil
        view.navigationDelegate = nil
        view.stopLoading()
    }

    private static func document(_ html: String, isDark: Bool) -> String {
        """
        <!doctype html><html><head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'none'; style-src 'unsafe-inline'; img-src data: https: http:; frame-src 'none'; object-src 'none'; connect-src 'none'; form-action 'none'; base-uri 'none'">
        <style>
        :root { color-scheme: \(isDark ? "dark" : "light"); }
        html, body { margin: 0; padding: 0; background: transparent; }
        body { font: 17px -apple-system, sans-serif; color: \(isDark ? "#f5f5f5" : "#202124"); line-height: 1.5; overflow-wrap: anywhere; }
        #indice-content { display: flow-root; padding: 2px; }
        * { box-sizing: border-box; }
        img, svg { max-width: 100%; height: auto; }
        p { margin: .35em 0; }
        h1, h2, h3, h4 { margin: .6em 0 .2em; line-height: 1.2; }
        h1 { font-size: 1.5em; } h2 { font-size: 1.3em; } h3 { font-size: 1.1em; }
        a { color: \(isDark ? "#80b5ff" : "#1263c5"); }
        pre { white-space: pre-wrap; } table { border-collapse: collapse; max-width: 100%; }
        th, td { padding: .3em; border: 1px solid #8886; }
        figure { margin: 0; }
        .dex-card { display: flex; gap: 1em; align-items: flex-start; padding: 1em; border: 1px solid #8886; border-radius: 1em; }
        .dex-card img { width: 5em; height: 5em; border-radius: 50%; object-fit: cover; flex: none; }
        .dex-muted { opacity: .7; font-size: .85em; }
        .dex-badge { display: inline-block; padding: .1em .6em; border-radius: 1em; font-size: .8em; background: #8883; }
        </style></head><body><div id="indice-content">\(html)</div></body></html>
        """
    }

    final class ContentWebView: WKWebView {
        var onWidthChange: (() -> Void)?
        private var lastWidth: CGFloat = 0
        override func layoutSubviews() {
            super.layoutSubviews()
            if bounds.width != lastWidth {
                lastWidth = bounds.width
                onWidthChange?()
            }
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var height: Binding<CGFloat>
        var openLink: (URL) -> Void
        var document: String?
        var generation = 0
        var observation: NSKeyValueObservation?
        private var measuring = false

        init(height: Binding<CGFloat>, openLink: @escaping (URL) -> Void) {
            self.height = height
            self.openLink = openLink
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { measure(webView) }

        func measure(_ view: WKWebView) {
            guard !measuring, !view.isLoading, view.bounds.width > 0 else { return }
            measuring = true
            let requestedGeneration = generation
            // This is a fixed, app-owned expression, never code from a response.
            // Measure the content element (not viewport scrollHeight), otherwise
            // a previously tall part could never shrink after an updated payload.
            view.evaluateJavaScript("document.getElementById('indice-content').getBoundingClientRect().height") { [weak self] value, _ in
                guard let self else { return }
                measuring = false
                guard requestedGeneration == generation, let number = value as? NSNumber else { return }
                let measured = max(1, min(20_000, ceil(CGFloat(number.doubleValue))))
                if abs(height.wrappedValue - measured) > 0.5 { height.wrappedValue = measured }
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url,
               ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
                openLink(url) // Only an explicit tap opens a link outside the fragment.
                decisionHandler(.cancel)
                return
            }
            // loadHTMLString starts an about:blank navigation. Block meta refresh,
            // form submits and attempts to navigate the embedded view elsewhere.
            decisionHandler(navigationAction.request.url?.absoluteString == "about:blank" ? .allow : .cancel)
        }
    }
}
