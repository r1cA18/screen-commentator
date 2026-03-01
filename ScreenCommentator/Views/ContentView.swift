import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: CommentViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            settings
            Divider()
            footer
        }
        .frame(width: 360, height: 560)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Screen Commentator")
                    .font(.headline)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.isRunning ? .green : Color(nsColor: .tertiaryLabelColor))
                        .frame(width: 6, height: 6)
                    Text(viewModel.isRunning ? "Active" : "Idle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                Button {
                    if viewModel.isRunning {
                        viewModel.stop()
                    } else {
                        Task { await viewModel.start() }
                    }
                } label: {
                    Label(
                        viewModel.isRunning ? "Stop" : "Start",
                        systemImage: viewModel.isRunning ? "stop.fill" : "play.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)

                Button("Test", action: viewModel.addTestComment)
                    .controlSize(.large)
                    .buttonStyle(.bordered)
            }

            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(16)
    }

    // MARK: - Settings

    private var settings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                providerSection
                generationSection
                appearanceSection
            }
            .padding(16)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.medium))
            .foregroundStyle(.tertiary)
            .tracking(0.5)
    }

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Provider")

            Picker("Source", selection: $viewModel.selectedProvider) {
                ForEach(CommentProvider.allCases) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(viewModel.isRunning)

            if viewModel.selectedProvider == .ollama {
                Picker("Model", selection: $viewModel.selectedOllamaModel) {
                    ForEach(OllamaModel.allCases) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .disabled(viewModel.isRunning)
            } else {
                Picker("Model", selection: $viewModel.selectedGeminiModel) {
                    ForEach(GeminiModel.allCases) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .disabled(viewModel.isRunning)

                SecureField("API Key", text: $viewModel.geminiApiKey)
                    .textFieldStyle(.roundedBorder)
                    .disabled(viewModel.isRunning)
            }
        }
    }

    private var generationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Generation")

            HStack(spacing: 8) {
                Text("Comments")
                Spacer()
                Slider(
                    value: Binding(
                        get: { Double(viewModel.baseCommentCount) },
                        set: { viewModel.baseCommentCount = Int($0) }
                    ),
                    in: 1...10,
                    step: 1
                )
                .frame(maxWidth: 160)
                Text("\(viewModel.baseCommentCount)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 16, alignment: .trailing)
            }

            ForEach(Persona.allCases) { persona in
                PersonaRow(
                    persona: persona,
                    isEnabled: Binding(
                        get: { viewModel.personaEnabled[persona] ?? false },
                        set: { newValue in
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
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Appearance")

            HStack(spacing: 8) {
                Text("Size")
                    .frame(width: 50, alignment: .leading)
                Slider(value: $viewModel.fontSize, in: 20...44, step: 2)
                Text("\(Int(viewModel.fontSize))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 22, alignment: .trailing)
            }

            HStack(spacing: 8) {
                Text("Opacity")
                    .frame(width: 50, alignment: .leading)
                Slider(value: $viewModel.textOpacity, in: 0.3...1.0, step: 0.1)
                Text("\(Int(viewModel.textOpacity * 100))%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }

            Toggle("Bold", isOn: $viewModel.fontWeightBold)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        Group {
            if viewModel.selectedProvider == .ollama {
                Text("Requires Ollama with a vision model")
            } else {
                Text("Uses Google Gemini API")
            }
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
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
                .toggleStyle(.checkbox)
                .frame(width: 100, alignment: .leading)

            if isEnabled {
                Slider(value: $weight, in: 0.1...1.0, step: 0.1)
                Text("\(Int(weight * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .trailing)
            }
        }
    }
}
