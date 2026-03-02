import AppKit
import Foundation

struct ActiveAppInfo: Sendable {
    let bundleIdentifier: String
    let appName: String
    let url: String?
}

@MainActor
final class ActiveAppMonitor: ObservableObject {
    @Published var currentApp: ActiveAppInfo?

    private var observer: NSObjectProtocol?

    private static let browserBundleIDs: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "company.thebrowser.Browser",
        "org.mozilla.firefox",
        "com.microsoft.edgemac",
        "com.brave.Browser",
    ]

    func startMonitoring() {
        stopMonitoring()
        checkFrontmostApp()

        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor [weak self] in
                if let app {
                    self?.updateCurrentApp(from: app)
                } else {
                    self?.checkFrontmostApp()
                }
            }
        }
    }

    func stopMonitoring() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observer = nil
        currentApp = nil
    }

    private func checkFrontmostApp() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        updateCurrentApp(from: app)
    }

    private func updateCurrentApp(from app: NSRunningApplication) {
        let bundleID = app.bundleIdentifier ?? ""
        let appName = app.localizedName ?? "Unknown"

        var url: String? = nil
        if Self.browserBundleIDs.contains(bundleID) {
            url = fetchBrowserURL(bundleID: bundleID)
        }

        currentApp = ActiveAppInfo(
            bundleIdentifier: bundleID,
            appName: appName,
            url: url
        )
    }

    private func fetchBrowserURL(bundleID: String) -> String? {
        let script: String
        switch bundleID {
        case "com.apple.Safari":
            script = """
            tell application "Safari"
                if (count of windows) > 0 then
                    return URL of current tab of front window
                end if
            end tell
            """
        case "com.google.Chrome", "com.brave.Browser", "com.microsoft.edgemac":
            let appName: String
            switch bundleID {
            case "com.google.Chrome": appName = "Google Chrome"
            case "com.brave.Browser": appName = "Brave Browser"
            case "com.microsoft.edgemac": appName = "Microsoft Edge"
            default: return nil
            }
            script = """
            tell application "\(appName)"
                if (count of windows) > 0 then
                    return URL of active tab of front window
                end if
            end tell
            """
        case "company.thebrowser.Browser":
            script = """
            tell application "Arc"
                if (count of windows) > 0 then
                    return URL of active tab of front window
                end if
            end tell
            """
        default:
            return nil
        }

        guard let appleScript = NSAppleScript(source: script) else { return nil }
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        if error != nil { return nil }
        return result.stringValue
    }
}
