import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: CommentViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Screen Commentator")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(viewModel.isRunning ? "Running" : "Stopped")
                .font(.title2)
                .foregroundColor(viewModel.isRunning ? .green : .red)

            HStack(spacing: 16) {
                Button("Start") {
                    Task {
                        await viewModel.start()
                    }
                }
                .disabled(viewModel.isRunning)

                Button("Stop") {
                    Task {
                        await viewModel.stop()
                    }
                }
                .disabled(!viewModel.isRunning)
            }
            .buttonStyle(.borderedProminent)

            Spacer()

            Text("Comments will appear as an overlay on your screen")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(40)
        .frame(width: 400, height: 300)
    }
}
