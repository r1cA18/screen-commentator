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
        .frame(width: 360, height: 640)
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
                blacklistSection
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

            if viewModel.selectedProvider == .ollama {
                Picker("Model", selection: $viewModel.selectedOllamaModel) {
                    ForEach(OllamaModel.allCases) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .pickerStyle(.menu)
            } else {
                Picker("Model", selection: $viewModel.selectedGeminiModel) {
                    ForEach(GeminiModel.allCases) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .pickerStyle(.menu)

                SecureField("API Key", text: $viewModel.geminiApiKey)
                    .textFieldStyle(.roundedBorder)
            }

            sectionLabel("Pipeline")

            Picker("Pipeline", selection: $viewModel.pipelineMode) {
                ForEach(PipelineMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(pipelineHint)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .disabled(viewModel.isRunning)
    }

    private var pipelineHint: String {
        switch viewModel.pipelineMode {
        case .smart: return "VLM structured JSON output (Gemini recommended)"
        case .ocrEnhanced: return "OCR text extraction, no image sent to LLM"
        case .basic: return "Image + simple prompt (legacy)"
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
                    .frame(width: 20, alignment: .trailing)
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

            HStack(spacing: 8) {
                Text("Speed")
                    .frame(width: 50, alignment: .leading)
                Slider(value: $viewModel.scrollDuration, in: 2.0...10.0, step: 0.5)
                Text("\(String(format: "%.1f", viewModel.scrollDuration))s")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }

            Toggle("Bold", isOn: $viewModel.fontWeightBold)
        }
    }

    // MARK: - Blacklist

    @State private var newBlacklistPattern = ""

    private var blacklistSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Blacklist Monitor")

            Toggle("Enable", isOn: $viewModel.blacklistEnabled)

            if viewModel.blacklistEnabled {
                if viewModel.isBlacklistTriggered {
                    Text("TRIGGERED - Roast mode active")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                ForEach(viewModel.blacklistManager.entries) { entry in
                    HStack(spacing: 6) {
                        Image(systemName: entry.matchType == .url ? "globe" : "app")
                            .foregroundStyle(.secondary)
                            .frame(width: 14)
                            .font(.caption2)
                        Text(entry.pattern)
                            .font(.caption)
                        Spacer()
                        Button {
                            if let idx = viewModel.blacklistManager.entries.firstIndex(where: { $0.id == entry.id }) {
                                viewModel.blacklistManager.entries.remove(at: idx)
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 6) {
                    TextField("e.g. youtube.com", text: $newBlacklistPattern)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    Button("Add") {
                        let pattern = newBlacklistPattern.trimmingCharacters(in: .whitespaces)
                        guard !pattern.isEmpty else { return }
                        viewModel.blacklistManager.add(BlacklistEntry(pattern: pattern))
                        newBlacklistPattern = ""
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        Text(viewModel.selectedProvider == .ollama
            ? "Requires Ollama with a vision model"
            : "Uses Google Gemini API")
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
                .frame(width: 100, alignment: .leading)

            if isEnabled {
                Slider(value: $weight, in: 0.1...1.0, step: 0.1)
                Text("\(Int(weight * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }
        }
    }
}
