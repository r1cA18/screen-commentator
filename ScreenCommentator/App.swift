import SwiftUI
import AppKit
import ScreenCaptureKit

@main
struct ScreenCommentatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = CommentViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onAppear {
                    appDelegate.showOverlay(viewModel: viewModel)
                }
                .task {
                    await requestScreenCapturePermission()
                }
        }
        .windowResizability(.contentSize)
    }

    private func requestScreenCapturePermission() async {
        // Trigger the Screen Recording permission dialog on app launch
        // so the user can grant it before clicking Start.
        _ = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let overlayController = OverlayWindowController()

    @MainActor
    func showOverlay(viewModel: CommentViewModel) {
        overlayController.show(viewModel: viewModel)
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            overlayController.close()
        }
    }
}
