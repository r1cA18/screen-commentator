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

            // Model
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

            Divider()

            // Comment count
            HStack {
                Text("Comments: \(viewModel.baseCommentCount)")
                    .frame(width: 110, alignment: .leading)
                Slider(
                    value: Binding(
                        get: { Double(viewModel.baseCommentCount) },
                        set: { viewModel.baseCommentCount = Int($0) }
                    ),
                    in: 1...10,
                    step: 1
                )
            }
            .frame(maxWidth: 250)

            // Persona
            VStack(alignment: .leading, spacing: 6) {
                Text("Persona")
                    .font(.headline)

                ForEach(Persona.allCases) { persona in
                    PersonaRow(
                        persona: persona,
                        isEnabled: Binding(
                            get: { viewModel.personaEnabled[persona] ?? false },
                            set: { newValue in
                                // Prevent disabling all personas
                                let otherEnabled = Persona.allCases
                                    .filter { $0 != persona }
                                    .contains { viewModel.personaEnabled[$0] == true }
                                if !newValue && !otherEnabled { return }
                                viewModel.personaEnabled[persona] = newValue
                            }
                        ),
                        weight: Binding(
                            get: { viewModel.personaWeights[persona] ?? 0.5 },
                            set: { viewModel.personaWeights[persona] = $0 }
                        )
                    )
                }
            }
            .frame(maxWidth: 280)

            Divider()

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
        .frame(width: 420, height: 700)
    }
}

// MARK: - PersonaRow

struct PersonaRow: View {
    let persona: Persona
    @Binding var isEnabled: Bool
    @Binding var weight: Double

    var body: some View {
        HStack(spacing: 8) {
            Toggle(persona.displayName, isOn: $isEnabled)
                .frame(width: 100)
            if isEnabled {
                Slider(value: $weight, in: 0.1...1.0, step: 0.1)
                Text(String(format: "%.0f%%", weight * 100))
                    .font(.caption)
                    .frame(width: 36)
            }
        }
    }
}
