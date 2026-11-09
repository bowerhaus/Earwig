import Foundation
import SwiftData

/// Records a take among its script's takes (PRD §4.7; plan 005, decision 6): inserted as
/// stopped when its slate plays, so the number is taken even if the app is killed mid-take,
/// and given its duration and outcome when it ends.
@MainActor
final class ScriptTakeRecorder: TakeRecorder {
    private let script: Script
    private let stepIndex: Int
    private let number: Int
    private let context: ModelContext
    private let recording: Recording?
    private(set) var take: Take?

    /// Where a take's recording goes, and whether it is kept (plan 010, decision 6).
    struct Recording {
        var path: String
        var keep: Bool
        var store = RecordingStore.standard
        var defaults = UserDefaults.standard
    }

    init(script: Script, stepIndex: Int, number: Int, context: ModelContext, recording: Recording? = nil) {
        self.script = script
        self.stepIndex = stepIndex
        self.number = number
        self.context = context
        self.recording = recording
    }

    func started(at date: Date) {
        let take = Take(stepIndex: stepIndex, number: number, startedAt: date)
        take.outcome = .stopped
        context.insert(take)
        take.script = script
        self.take = take
        if let recording {
            take.recordingPath = recording.path
            if let deleted = recording.store.started(recording.path, keep: recording.keep, defaults: recording.defaults) {
                forget(deleted)
            }
        }
        save()
    }

    /// The recording came to nothing: the take has none (decision 6).
    func recordingFinished(_ result: RecordingResult?) {
        guard let recording, result == nil else { return }
        recording.store.discard(recording.path, defaults: recording.defaults)
        take?.recordingPath = nil
        save()
    }

    /// The takes whose recording was deleted no longer name it.
    private func forget(_ path: String) {
        let descriptor = FetchDescriptor<Take>(predicate: #Predicate { $0.recordingPath == path })
        for take in (try? context.fetch(descriptor)) ?? [] { take.recordingPath = nil }
    }

    func finished(duration: TimeInterval, outcome: TakeOutcome) {
        take?.duration = duration
        take?.outcome = outcome
        save()
    }

    private func save() {
        do {
            try context.save()
        } catch {
            Log.event("take record not saved: \(error.localizedDescription)")
        }
    }
}
