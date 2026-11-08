import SwiftUI

/// The first Settings screen (PRD §4.8, §8.4; plan 005, decision 11): what stage 5 judges by ear,
/// the lead, the pacing and the start mode, and the Listening check. The rest waits for stage 7.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(TakeSettings.leadKey) private var lead = TakeSettings.defaultLead
    @AppStorage(TakeSettings.voiceSpeedKey) private var voiceSpeed = TakeSettings.defaultVoiceSpeed
    @AppStorage(TakeSettings.pacingKey) private var pacing: PacingMode = FollowSettings().pacing
    @AppStorage(TakeSettings.startModeKey) private var start: StartMode = TakeSettings.defaultStartMode

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $lead, in: TakeSettings.leadRange) {
                        LabeledContent("Lead") {
                            Text(String(format: "%d words · %.1f s", lead, TakeSettings.seconds(forLead: lead)))
                                .monospacedDigit()
                        }
                    }
                    Picker("Pacing", selection: $pacing) {
                        ForEach(PacingMode.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    Picker("Voice speed", selection: $voiceSpeed) {
                        ForEach(TakeSettings.voiceSpeeds, id: \.self) { Text(String(format: "%.2f×", $0)).tag($0) }
                    }
                } header: {
                    Text("Following")
                } footer: {
                    Text("How far ahead of you the voice runs. Hybrid nudges the voice's speed to keep the lead and waits at every phrase end; phrase-gated keeps it at its voice speed and only waits.")
                        .foregroundStyle(EarwigTheme.secondaryText)
                }
                .listRowBackground(EarwigTheme.surface)

                Section {
                    Picker("Start", selection: $start) {
                        ForEach(StartMode.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Start")
                } footer: {
                    Text(startFooter)
                        .foregroundStyle(EarwigTheme.secondaryText)
                }
                .listRowBackground(EarwigTheme.surface)

                Section {
                    NavigationLink {
                        ListeningCheckView()
                    } label: {
                        Label("Listening Check", systemImage: "waveform.and.mic")
                    }
                } header: {
                    Text("Diagnostics")
                }
                .listRowBackground(EarwigTheme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(EarwigTheme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(EarwigTheme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var startFooter: String {
        switch start {
        case .slateWithReply: "The slate is read in your ear; say it back to the camera and the tones follow. Or tap the screen."
        case .slate: "The slate is read in your ear, then a pause to say it to the camera, then the tones."
        case .tonesOnly: "Just the tones, then the first line."
        }
    }
}

#Preview {
    SettingsView()
        .environment(ScriptRenderer.live())
        .tint(EarwigTheme.accent)
        .preferredColorScheme(EarwigTheme.scheme)
}
