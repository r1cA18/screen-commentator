import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: CommentViewModel

    var body: some View {
        VStack(spacing: 12) {
            Text("Screen Commentator")
                .font(.largeTitle)
                .fontWeight(.bold)

            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isRunning ? .green : .red)
                    .frame(width: 10, height: 10)
                Text(viewModel.isRunning ? "Running" : "Stopped")
                    .font(.title3)
            }

            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            // Provider
            Picker("Provider", selection: $viewModel.selectedProvider) {
                ForEach(CommentProvider.allCases) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)
            .disabled(viewModel.isRunning)

            // Model (conditional on provider)
            if viewModel.selectedProvider == .ollama {
                Picker("Model", selection: $viewModel.selectedOllamaModel) {
                    ForEach(OllamaModel.allCases) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 250)
                .disabled(viewModel.isRunning)
            } else {
                Picker("Model", selection: $viewModel.selectedGeminiModel) {
                    ForEach(GeminiModel.allCases) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 250)
                .disabled(viewModel.isRunning)

                SecureField("Gemini API Key", text: $viewModel.geminiApiKey)
                    .frame(maxWidth: 250)
                    .textFieldStyle(.roundedBorder)
                    .disabled(viewModel.isRunning)
            }

            Toggle("Ambient Reactions", isOn: $viewModel.ambientEnabled)
                .frame(maxWidth: 250)

            // Start / Stop
            HStack(spacing: 16) {
                Button("Start") {
                    Task {
                        await viewModel.start()
                    }
                }
                .disabled(viewModel.isRunning)

                Button("Stop") {
                    viewModel.stop()
                }
                .disabled(!viewModel.isRunning)
            }
            .buttonStyle(.borderedProminent)

            Divider()

            // Text style
            Group {
                HStack {
                    Text("Size: \(Int(viewModel.fontSize))")
                        .frame(width: 70, alignment: .leading)
                    Slider(value: $viewModel.fontSize, in: 20...44, step: 2)
                }
                HStack {
                    Text("Opacity")
                        .frame(width: 70, alignment: .leading)
                    Slider(value: $viewModel.textOpacity, in: 0.3...1.0, step: 0.1)
                }
                Toggle("Bold", isOn: $viewModel.fontWeightBold)
            }
            .frame(maxWidth: 250)

            Button("Test Comment") {
                viewModel.addTestComment()
            }
            .buttonStyle(.bordered)

            Spacer()

            if viewModel.selectedProvider == .ollama {
                Text("Requires Ollama with a vision model installed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Uses Google Gemini API (free tier available)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(30)
        .frame(width: 420, height: 560)
    }
}
