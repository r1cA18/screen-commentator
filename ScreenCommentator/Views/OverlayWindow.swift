import SwiftUI
import AppKit

// MARK: - OverlayWindowController

@MainActor
final class OverlayWindowController {
    private var panel: NSPanel?

    func show(viewModel: CommentViewModel) {
        guard panel == nil else { return }
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar + 1
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false

        let rootView = OverlayContentView(viewModel: viewModel)
            .frame(width: frame.width, height: frame.height)

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: frame.size)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = CGColor.clear
        hostingView.layer?.isOpaque = false

        panel.contentView = hostingView
        panel.orderFrontRegardless()
        self.panel = panel

        print("[ScreenCommentator] Overlay panel created: \(frame)")
    }

    func close() {
        panel?.close()
        panel = nil
    }
}

// MARK: - OverlayContentView

struct OverlayContentView: View {
    @ObservedObject var viewModel: CommentViewModel

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())

                ForEach(viewModel.activeComments) { comment in
                    ScrollingCommentView(
                        comment: comment,
                        screenWidth: geometry.size.width,
                        yPosition: CGFloat(comment.lane) * CommentViewModel.laneHeight + CommentViewModel.topMargin,
                        fontSize: viewModel.fontSize,
                        textOpacity: viewModel.textOpacity,
                        fontWeightBold: viewModel.fontWeightBold
                    )
                }
            }
        }
        .background(.clear)
        .drawingGroup(opaque: false)
    }
}

// MARK: - ScrollingCommentView

struct ScrollingCommentView: View {
    let comment: Comment
    let screenWidth: CGFloat
    let yPosition: CGFloat
    let fontSize: CGFloat
    let textOpacity: Double
    let fontWeightBold: Bool

    @State private var xOffset: CGFloat = 10000

    var body: some View {
        Text(comment.text)
            .font(.system(size: fontSize, weight: fontWeightBold ? .bold : .regular))
            .foregroundColor(.white.opacity(textOpacity))
            .shadow(color: .black, radius: 2, x: 1, y: 1)
            .shadow(color: .black, radius: 1, x: -1, y: -1)
            .fixedSize()
            .offset(x: xOffset, y: yPosition)
            .task {
                xOffset = screenWidth
                try? await Task.sleep(for: .milliseconds(16))
                withAnimation(.linear(duration: 6.0)) {
                    xOffset = -600
                }
            }
    }
}
