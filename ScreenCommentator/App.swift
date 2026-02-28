import SwiftUI
import AppKit

@main
struct ScreenCommentatorApp: App {
    @StateObject private var viewModel = CommentViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }

        // Overlay window (always on top, transparent, click-through)
        Window("Overlay", id: "overlay") {
            OverlayWindow()
                .environmentObject(viewModel)
                .onAppear {
                    configureOverlayWindow()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }

    private func configureOverlayWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApplication.shared.windows.first(where: { $0.title == "Overlay" }) {
                window.level = .floating
                window.isOpaque = false
                window.backgroundColor = .clear
                window.ignoresMouseEvents = true
                window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            }
        }
    }
}
