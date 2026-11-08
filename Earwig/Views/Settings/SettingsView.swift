import SwiftData
import SwiftUI

/// The first Settings screen (PRD §4.8, §8.4; plan 005, decision 11): what stage 5 judges by ear,
/// the lead, the pacing and the start mode, and the Listening check. The rest waits for stage 7.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(TakeSettings.leadKey) private var lead = TakeSettings.defaultLead
    @AppStorage(TakeSettings.voiceSpeedKey) private var voiceSpeed = TakeSettings.defaultVoiceSpeed
    @AppStorage(TakeSettings.pacingKey) private var pacing: PacingMode = FollowSettings().pacing
    @AppStorage(TakeSettings.startModeKey) private var start: StartMode = TakeSettings.defaultStartMode
    @AppStorage(TakeSettings.modeKey) private var mode: TakeMode = TakeSettings.defaultMode
    @AppStorage(TakeSettings.textSizeKey) private var textSize = TakeSettings.defaultTextSize
    @AppStorage(TakeSettings.lightsVoiceKey) private var lightsVoice = false
    @AppStorage(TakeSettings.recordingKey) private var recording: TakeRecordingMode = .off
    @AppStorage(TakeSettings.videoQualityKey) private var videoQuality: VideoQuality = .hd1080
    @AppStorage(TakeSettings.keepsRecordingsKey) private var keepsRecordings = false
    @Environment(\.modelContext) private var context
    @State private var recordingsSize: Int64 = 0
    @State private var confirmingDeleteAll = false

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
                    Picker("Mode", selection: $mode) {
                        ForEach(TakeMode.allCases, id: \.self) { Label($0.label, systemImage: $0.systemImage).tag($0) }
                    }
                    Toggle("Light the Voice's Phrase", isOn: $lightsVoice)
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Text size") {
                            Text("\(Int(textSize)) pt").monospacedDigit()
                        }
                        Slider(value: $textSize, in: TakeSettings.textSizeRange, step: 2)
                            .accessibilityLabel("Text size")
                        Text("The tide is out.")
                            .font(.system(size: textSize, weight: .semibold))
                            .foregroundStyle(EarwigTheme.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.2)
                    }
                } header: {
                    Text("Screen")
                } footer: {
                    Text(modeFooter)
                        .foregroundStyle(EarwigTheme.secondaryText)
                }
                .listRowBackground(EarwigTheme.surface)

                Section {
                    Picker("Record", selection: $recording) {
                        ForEach(TakeRecordingMode.allCases, id: \.self) { Label($0.label, systemImage: $0.systemImage).tag($0) }
                    }
                    Picker("Video Quality", selection: $videoQuality) {
                        ForEach(VideoQuality.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    Toggle("Keep Recordings", isOn: $keepsRecordings)
                    LabeledContent("Recordings") {
                        Text(ByteCountFormatter.string(fromByteCount: recordingsSize, countStyle: .file)).monospacedDigit()
                    }
                    Button("Delete All Recordings", role: .destructive) { confirmingDeleteAll = true }
                        .disabled(recordingsSize == 0)
                } header: {
                    Text("Recording")
                } footer: {
                    Text("Sound records what you say on the iPhone's mic; Video adds the front camera, framed before the take starts. Also beside Start on the Script screen. 1080p is about 60 MB a minute, 4K about 170 MB. With Keep Recordings off, each take's recording replaces the last. Recordings are in the Files app, under On My iPhone › Earwig.")
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
            .onAppear { recordingsSize = RecordingStore.standard.size() }
            .confirmationDialog("Delete every recording?", isPresented: $confirmingDeleteAll, titleVisibility: .visible) {
                Button("Delete All Recordings", role: .destructive) { deleteAllRecordings() }
            } message: {
                Text("Every take's recording is deleted from this iPhone. This can't be undone.")
            }
        }
    }

    private func deleteAllRecordings() {
        do {
            try RecordingStore.standard.deleteAll(defaults: .standard)
        } catch {
            Log.event("recordings not deleted: \(error.localizedDescription)")
        }
        let recorded = FetchDescriptor<Take>(predicate: #Predicate { $0.recordingPath != nil })
        for take in (try? context.fetch(recorded)) ?? [] { take.recordingPath = nil }
        try? context.save()
        recordingsSize = RecordingStore.standard.size()
    }

    private var modeFooter: String {
        switch mode {
        case .voice: "The voice reads the script into your ear while it scrolls on the screen with you. Lit, its phrase shows on the screen ahead of you. Also beside Start on the Script screen. Pinch the text during a take to size it."
        case .screen: "The script scrolls on the screen with you, and no voice reads it. Also beside Start on the Script screen. Pinch the text during a take to size it."
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
