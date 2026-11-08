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
    private(set) var take: Take?

    init(script: Script, stepIndex: Int, number: Int, context: ModelContext) {
        self.script = script
        self.stepIndex = stepIndex
        self.number = number
        self.context = context
    }

    func started(at date: Date) {
        let take = Take(stepIndex: stepIndex, number: number, startedAt: date)
        take.outcome = .stopped
        context.insert(take)
        take.script = script
        self.take = take
        save()
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
