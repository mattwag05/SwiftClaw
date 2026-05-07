import Foundation
import WebKit
import SwiftClawCore
import UniformTypeIdentifiers

/// Handles `swiftclaw-workspace://<sessionId>/<path>` URLs for the Canvas WebView.
///
/// The scheme handler resolves the path against the session's workspace directory
/// (`~/.swiftclaw/workspaces/<sessionId>/`) and serves the file content with
/// the appropriate MIME type. A bare `/` path with no `index.html` returns a
/// simple directory listing.
final class WorkspaceURLSchemeHandler: NSObject, WKURLSchemeHandler {
    private let sessionId: String
    private let workspaceManager: WorkspaceManager

    init(sessionId: String, workspaceManager: WorkspaceManager) {
        self.sessionId = sessionId
        self.workspaceManager = workspaceManager
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            fail(urlSchemeTask, status: 400, message: "No URL")
            return
        }

        Task {
            let workspaceURL = await workspaceManager.path(for: sessionId)
            let relativePath = url.path.isEmpty ? "/" : url.path
            let filePath = relativePath == "/" ? "" : String(relativePath.dropFirst())

            if filePath.isEmpty || filePath == "/" {
                await serveDirectory(workspaceURL: workspaceURL, task: urlSchemeTask)
            } else {
                await serveFile(path: filePath, workspaceURL: workspaceURL, task: urlSchemeTask)
            }
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}

    // MARK: - Private

    private func serveFile(path: String, workspaceURL: URL, task: any WKURLSchemeTask) async {
        let fileURL: URL
        do {
            fileURL = try WorkspaceSandbox.resolve(path: path, in: workspaceURL)
        } catch {
            fail(task, status: 403, message: "Forbidden: \(error.localizedDescription)")
            return
        }

        guard let data = try? Data(contentsOf: fileURL) else {
            fail(task, status: 404, message: "Not found: \(path)")
            return
        }

        let mime = mimeType(for: fileURL)
        respond(task, data: data, mimeType: mime)
    }

    private func serveDirectory(workspaceURL: URL, task: any WKURLSchemeTask) async {
        let indexURL = workspaceURL.appendingPathComponent("index.html")
        if FileManager.default.fileExists(atPath: indexURL.path),
           let data = try? Data(contentsOf: indexURL) {
            respond(task, data: data, mimeType: "text/html")
            return
        }

        let items = (try? FileManager.default.contentsOfDirectory(atPath: workspaceURL.path)) ?? []
        let links = items.sorted().map { name in
            let escaped = htmlEscape(name)
            // URL-encode the href separately from HTML-escaping the display text.
            let href = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? escaped
            return "<li><a href=\"/\(href)\">\(escaped)</a></li>"
        }.joined(separator: "\n")
        let html = "<html><body><ul>\(links)</ul></body></html>"
        respond(task, data: Data(html.utf8), mimeType: "text/html")
    }

    private func mimeType(for url: URL) -> String {
        if let type = UTType(filenameExtension: url.pathExtension),
           let mime = type.preferredMIMEType {
            return mime
        }
        return "application/octet-stream"
    }

    private func respond(_ task: any WKURLSchemeTask, data: Data, mimeType: String) {
        guard let url = task.request.url else {
            DispatchQueue.main.async { task.didFailWithError(URLError(.badURL)) }
            return
        }
        let response = URLResponse(
            url: url,
            mimeType: mimeType,
            expectedContentLength: data.count,
            textEncodingName: "utf-8"
        )
        // WKURLSchemeTask must be driven from the main thread (same as the webView(_:start:) call site).
        DispatchQueue.main.async {
            task.didReceive(response)
            task.didReceive(data)
            task.didFinish()
        }
    }

    private func fail(_ task: any WKURLSchemeTask, status: Int, message: String) {
        let escaped = htmlEscape(message)
        let html = "<html><body><h1>\(status)</h1><p>\(escaped)</p></body></html>"
        respond(task, data: Data(html.utf8), mimeType: "text/html")
    }

    private func htmlEscape(_ str: String) -> String {
        str.replacingOccurrences(of: "&", with: "&amp;")
           .replacingOccurrences(of: "<", with: "&lt;")
           .replacingOccurrences(of: ">", with: "&gt;")
           .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
