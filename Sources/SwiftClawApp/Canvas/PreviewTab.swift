import SwiftUI
import WebKit
import SwiftClawCore

/// Canvas Preview tab — displays the workspace's index.html via a WKWebView
/// configured with the swiftclaw-workspace:// URL scheme handler.
///
/// The view reloads 350ms after any `fileWritten` event so the user sees
/// incremental output as the model writes files.
struct PreviewTab: View {
    let sessionId: String
    let workspaceManager: WorkspaceManager
    /// Observing this triggers a reload.
    let lastWrittenPath: String?

    var body: some View {
        WorkspaceWebView(
            sessionId: sessionId,
            workspaceManager: workspaceManager,
            lastWrittenPath: lastWrittenPath
        )
    }
}

// MARK: - NSViewRepresentable

struct WorkspaceWebView: NSViewRepresentable {
    let sessionId: String
    let workspaceManager: WorkspaceManager
    let lastWrittenPath: String?

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let handler = WorkspaceURLSchemeHandler(
            sessionId: sessionId, workspaceManager: workspaceManager
        )
        config.setURLSchemeHandler(handler, forURLScheme: "swiftclaw-workspace")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.load(URLRequest(url: rootURL))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Reload when a new file has been written (350ms delay)
        if let path = lastWrittenPath, path != context.coordinator.lastPath {
            context.coordinator.lastPath = path
            let sid = sessionId
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                let nonce = Int.random(in: 0..<Int.max)
                guard let reloadURL = URL(string: "swiftclaw-workspace://\(sid)/?v=\(nonce)") else { return }
                webView.load(URLRequest(url: reloadURL))
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var lastPath: String? = nil
    }

    private var rootURL: URL {
        URL(string: "swiftclaw-workspace://\(sessionId)/") ?? URL(fileURLWithPath: "/")
    }
}
