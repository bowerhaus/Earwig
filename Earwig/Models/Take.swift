import Foundation
import SwiftData

/// One attempt at one step (PRD §4.7, §6.1). Made from stage 5. A take names its step by
/// index, not by relationship, so a re-paste that rebuilds the steps keeps it.
@Model
final class Take {
    var stepIndex: Int = 0
    /// Numbered from 1 per step within the script; the slate says it.
    var number: Int = 1
    var startedAt: Date = Date()
    /// Seconds.
    var duration: Double = 0
    var outcomeRaw: String = TakeOutcome.stopped.rawValue
    var script: Script?

    init(stepIndex: Int = 0, number: Int = 1, startedAt: Date = Date()) {
        self.stepIndex = stepIndex
        self.number = number
        self.startedAt = startedAt
    }

    var outcome: TakeOutcome {
        get { TakeOutcome(rawValue: outcomeRaw) ?? .stopped }
        set { outcomeRaw = newValue.rawValue }
    }
}
