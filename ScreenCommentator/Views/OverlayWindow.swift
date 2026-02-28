import SwiftUI

struct OverlayWindow: View {
    @EnvironmentObject var viewModel: CommentViewModel

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                // Transparent background
                Color.clear

                // Comment flow area
                VStack(spacing: 8) {
                    ForEach(viewModel.commentQueue.activeComments) { comment in
                        CommentView(comment: comment, screenWidth: geometry.size.width)
                    }
                }
                .padding(.top, 50)
                .padding(.trailing, 20)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(Color.clear)
    }
}

struct CommentView: View {
    let comment: Comment
    let screenWidth: CGFloat

    @State private var offset: CGFloat = 0

    var body: some View {
        Text(comment.text)
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(.white)
            .shadow(color: .black, radius: 2, x: 1, y: 1)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.3))
            )
            .offset(x: offset)
            .onAppear {
                // Start from right edge
                offset = screenWidth

                // Animate to left edge over 5 seconds
                withAnimation(.linear(duration: 5.0)) {
                    offset = -200
                }
            }
    }
}
