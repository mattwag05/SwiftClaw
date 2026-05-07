import Foundation
import SwiftClawCore
import UserNotifications

/// Posts a system notification for `run_bash` approval requests in Build mode.
///
/// When a bash command doesn't match the allowlist, this notifier fires a
/// `UNUserNotificationCenter` alert with four action buttons:
///   - **Allow Once** — approve this execution only
///   - **Allow for Session** — approve all future executions of this command this session
///   - **Add to Allowlist** — permanently add the command prefix to the build allowlist
///   - **Deny** — block execution
///
/// The notifier vends a `ToolApprovalDelegate`-compatible interface: callers
/// `await approve(command:sessionId:)` and the answer comes back when the user
/// taps a button (or the 60-second timeout fires → Deny).
@MainActor
public final class ToolApprovalNotifier: NSObject, UNUserNotificationCenterDelegate, Sendable {
    public static let shared = ToolApprovalNotifier()

    // MARK: - Notification category / action identifiers

    public static let categoryIdentifier = "SC_BASH_APPROVAL"
    public static let allowOnceId   = "SC_ALLOW_ONCE"
    public static let allowSessionId = "SC_ALLOW_SESSION"
    public static let addAllowlistId = "SC_ADD_ALLOWLIST"
    public static let denyId        = "SC_DENY"

    // MARK: - Pending requests

    private var pending: [String: CheckedContinuation<ApprovalResult, Never>] = [:]

    public enum ApprovalResult: Sendable {
        case allowOnce
        case allowSession
        case addToAllowlist
        case deny
    }

    // MARK: - Setup

    /// Registers the approval notification category. Call once at app launch.
    public func register() {
        let allowOnce = UNNotificationAction(
            identifier: Self.allowOnceId,
            title: "Allow Once",
            options: []
        )
        let allowSession = UNNotificationAction(
            identifier: Self.allowSessionId,
            title: "Allow for Session",
            options: []
        )
        let addAllowlist = UNNotificationAction(
            identifier: Self.addAllowlistId,
            title: "Add to Allowlist",
            options: []
        )
        let deny = UNNotificationAction(
            identifier: Self.denyId,
            title: "Deny",
            options: .destructive
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [allowOnce, allowSession, addAllowlist, deny],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
        UNUserNotificationCenter.current().delegate = self
    }

    /// Request permission and post an approval notification.
    /// Suspends until the user responds (or the 60-second timeout fires).
    public func requestApproval(command: String, requestId: String) async -> ApprovalResult {
        let granted = await requestPermission()
        guard granted else { return .deny }

        return await withCheckedContinuation { continuation in
            pending[requestId] = continuation

            let content = UNMutableNotificationContent()
            content.title = "SwiftClaw — Bash Approval"
            content.body = command.count > 120
                ? String(command.prefix(117)) + "…"
                : command
            content.categoryIdentifier = Self.categoryIdentifier
            content.userInfo = ["requestId": requestId]
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let request = UNNotificationRequest(
                identifier: requestId,
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request) { [weak self] error in
                if error != nil {
                    Task { @MainActor in
                        self?.resolve(requestId: requestId, result: .deny)
                    }
                }
            }

            // Auto-deny after 60 seconds if no response.
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(60))
                self?.resolve(requestId: requestId, result: .deny)
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let requestId = response.notification.request.content.userInfo["requestId"] as? String ?? ""
        let result: ApprovalResult = switch response.actionIdentifier {
        case Self.allowOnceId:    .allowOnce
        case Self.allowSessionId: .allowSession
        case Self.addAllowlistId: .addToAllowlist
        default:                  .deny
        }
        Task { @MainActor in
            self.resolve(requestId: requestId, result: result)
        }
        completionHandler()
    }

    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // MARK: - Private

    private func resolve(requestId: String, result: ApprovalResult) {
        guard let continuation = pending.removeValue(forKey: requestId) else { return }
        continuation.resume(returning: result)
    }

    private func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .authorized { return true }
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        return granted
    }
}
