import AVFoundation
import SwiftData
import SwiftUI

/// The Settings screen (PRD §4.8, §8.4; plan 005, decision 11), its groups in the order a take
/// goes (plan 015, decision 15): the voice and its speed (plan 011, decision 15; plan 012,
/// decision 2), the start, cues and the cue voice (plan 015, decision 14), following, the
/// screen, recording, diagnostics, and the version (plan 012, decision 7).
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
    @AppStorage(TakeSettings.cameraBehindTextKey) private var cameraBehindText = TakeSettings.defaultCameraBehindText
    @AppStorage(AppSettings.inlineDirectionsKey) private var inlineDirections: InlineDirections = .chime
    @Environment(\.modelContext) private var context
    @Environment(ScriptRenderer.self) private var renderer
    @State private var voiceID = ""
    /// The cue voice picked by hand, "" for Automatic.
    @State private var cueVoiceID = AppSettings.cueVoiceID ?? ""
    @State private var preview = VoicePreview()
    /// Bumped when Personal Voice has been asked for, so the voices are listed again.
    @State private var personalVoiceAsked = 0
    @State private var recordingsSize: Int64 = 0
    @State private var confirmingDeleteAll = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Voice", selection: $voiceID) {
                        ForEach(presenterOptions, id: \.identifier) { Text($0.displayName).tag($0.identifier) }
                    }
                    .id(personalVoiceAsked)
                    Button {
                        if preview.isPlaying {
                            preview.stop()
                        } else {
                            Task { await preview.play(with: renderer, speed: voiceSpeed) }
                        }
                    } label: {
                        Label(preview.isPlaying ? "Stop" : "Preview", systemImage: preview.isPlaying ? "stop.fill" : "play.fill")
                    }
                    .foregroundStyle(EarwigTheme.accent)
                    .disabled(renderer.voices == nil)
                    Picker("Voice Speed", selection: $voiceSpeed) {
                        ForEach(TakeSettings.voiceSpeeds, id: \.self) { Text(String(format: "%.2f×", $0)).tag($0) }
                    }
                    if AVSpeechSynthesizer.personalVoiceAuthorizationStatus == .notDetermined {
                        Button("Allow Personal Voice") {
                            Task {
                                let status = await AVSpeechSynthesizer.requestPersonalVoiceAuthorization()
                                Log.event("personal voice: \(status == .authorized ? "authorised" : "not authorised (\(status.rawValue))")")
                                personalVoiceAsked += 1
                            }
                        }
                        .foregroundStyle(EarwigTheme.accent)
                    }
                } header: {
                    Text("Voice")
                } footer: {
                    if let problem = preview.problem {
                        Text(problem)
                            .foregroundStyle(EarwigTheme.warning)
                    }
                }
                .listRowBackground(EarwigTheme.surface)

                Section {
                    Picker("Start", selection: $start) {
                        ForEach(StartMode.allCases, id: \.self) { Text($0.label).foregroundStyle(EarwigTheme.text).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Start")
                } footer: {
                    if let startFooter {
                        Text(startFooter)
                            .foregroundStyle(EarwigTheme.secondaryText)
                    }
                }
                .listRowBackground(EarwigTheme.surface)

                // Cues in one place, the cue voice too (plan 015, decision 14): the start card's
                // Read Cues turns them on, and the footer says what the name doesn't.
                Section {
                    Picker("Cue Voice", selection: $cueVoiceID) {
                        Text("Automatic").tag("")
                        ForEach(cueOptions, id: \.identifier) { Text($0.displayName).tag($0.identifier) }
                    }
                    Picker("Hear Cues As", selection: $inlineDirections) {
                        ForEach(InlineDirections.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                } header: {
                    Text("Cues")
                } footer: {
                    Text("Cues at the top of a step are read before the take.")
                        .foregroundStyle(EarwigTheme.secondaryText)
                }
                .listRowBackground(EarwigTheme.surface)

                Section {
                    LabeledContent("Lead") {
                        HStack(spacing: 12) {
                            Text(String(format: "%d words · %.1f s", lead, TakeSettings.seconds(forLead: lead)))
                                .monospacedDigit()
                            LeadStepper(lead: $lead)
                        }
                    }
                    Picker("Pacing", selection: $pacing) {
                        ForEach(PacingMode.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                } header: {
                    Text("Following")
                } footer: {
                    Text("Both wait at phrase ends; Hybrid also speeds the voice up or down to keep the lead.")
                        .foregroundStyle(EarwigTheme.secondaryText)
                }
                .listRowBackground(EarwigTheme.surface)

                Section {
                    Picker("Mode", selection: $mode) {
                        ForEach(TakeMode.allCases, id: \.self) { Label($0.label, systemImage: $0.systemImage).tag($0) }
                    }
                    Toggle("Light the Voice's Phrase", isOn: $lightsVoice)
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Text Size") {
                            Text("\(Int(textSize)) pt").monospacedDigit()
                        }
                        Slider(value: $textSize, in: TakeSettings.textSizeRange, step: 2)
                            .accessibilityLabel("Text Size")
                        Text("The tide is out.")
                            .font(.system(size: textSize, weight: .semibold))
                            .foregroundStyle(EarwigTheme.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.2)
                    }
                    Critter.SettingRow()
                } header: {
                    Text("Screen")
                } footer: {
                    Text("Critter is just a bit of fun.")
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
                    Toggle("Camera Behind the Text", isOn: $cameraBehindText)
                    Toggle("Keep Recordings", isOn: $keepsRecordings)
                    LabeledContent("Recordings") {
                        Text(ByteCountFormatter.string(fromByteCount: recordingsSize, countStyle: .file)).monospacedDigit()
                    }
                    Button("Delete All Recordings", role: .destructive) { confirmingDeleteAll = true }
                        .disabled(recordingsSize == 0)
                } header: {
                    Text("Recording")
                } footer: {
                    Text("With Keep Recordings off, each recording replaces the last. They're in Files, under On My iPhone › Earwig.")
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

                Section {
                    // The version alone: links to the source and the licence would make a bought
                    // app look like a hobby project (plan 012, decision 7).
                    LabeledContent("Version", value: Self.version)
                } header: {
                    Text("About")
                }
                .listRowBackground(EarwigTheme.surface)
            }
            .scrollContentBackground(.hidden)
            // White labels, pale headers and values, in the light scheme (plan 011, decision 16).
            .foregroundStyle(EarwigTheme.text, EarwigTheme.secondaryText)
            // The critter, over the cards here; never while Preview is speaking (plan 014, decision 9).
            .critterVisits(keepAway: preview.isPlaying, leaving: .runsOff)
            .background(EarwigTheme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(EarwigTheme.background, for: .navigationBar)
            // White titles on the sky blue in the light scheme (plan 011, decision 16).
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    DoneButton { dismiss() }
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .onAppear {
                recordingsSize = RecordingStore.standard.size()
                voiceID = renderer.voices?.presenter.identifier ?? VoiceCatalogue.chosen()?.presenter.identifier ?? ""
                // A cue voice since deleted is Automatic again.
                if !cueOptions.contains(where: { $0.identifier == cueVoiceID }) { cueVoiceID = "" }
            }
            .onDisappear { preview.stop() }
            .onChange(of: voiceID) { old, new in
                // A pick by hand; the first value is only the voice already in use.
                guard !old.isEmpty, !new.isEmpty else { return }
                preview.stop()
                AppSettings.presenterVoiceID = new
                // A cue voice of the new presenter's gender is no longer offered: Automatic again.
                if !cueOptions.contains(where: { $0.identifier == cueVoiceID }) { cueVoiceID = "" }
                renderer.use(VoiceCatalogue.chosen())
            }
            .onChange(of: cueVoiceID) { _, new in
                AppSettings.cueVoiceID = new.isEmpty ? nil : new
                renderer.use(VoiceCatalogue.chosen())
            }
            .onChange(of: voiceSpeed) { preview.stop() }
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

    /// One line where the choice does something its name does not say (Andy, 2026-11-09:
    /// short footers, or none).
    /// Personal Voices first, then English voices of Enhanced quality or better, British first.
    private var presenterOptions: [VoiceInfo] { VoiceCatalogue.presenterOptions(from: VoiceCatalogue.installed()) }

    /// English voices of Enhanced quality or better and not of the presenter's gender, never a
    /// Personal Voice, beside Automatic.
    private var cueOptions: [VoiceInfo] {
        let voices = VoiceCatalogue.installed()
        return VoiceCatalogue.cueOptions(from: voices, presenter: voices.first { $0.identifier == voiceID })
    }

    /// "0.2.0 (2)": the version and the build, so a TestFlight build can be told apart.
    static let version: String = {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }()

    private var startFooter: String? {
        switch start {
        case .slateWithReply: "Say the slate back, or tap the screen, and the tones follow."
        case .slate: "A pause after the slate to say it, then the tones."
        case .tonesOnly: nil
        }
    }
}

/// Lead's − and +, in place of iOS's stepper, whose light capsule hid its white symbols (plan 011,
/// decision 16).
private struct LeadStepper: View {
    @Binding var lead: Int

    var body: some View {
        HStack(spacing: 0) {
            step("minus", "Shorter lead", by: -1)
            step("plus", "Longer lead", by: 1)
        }
        .background(EarwigTheme.background, in: Capsule())
    }

    private func step(_ symbol: String, _ label: String, by change: Int) -> some View {
        let next = lead + change
        let allowed = TakeSettings.leadRange.contains(next)
        return Button { if allowed { lead = next } } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(allowed ? EarwigTheme.accent : EarwigTheme.secondaryText.opacity(0.5))
                .frame(width: 44, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#Preview {
    SettingsView()
        .environment(ScriptRenderer.live())
        .tint(EarwigTheme.accent)
        .preferredColorScheme(EarwigTheme.scheme)
}
