/// How a take ended (PRD §4.7).
enum TakeOutcome: String, Codable, Sendable {
    /// Ran to the end of the step.
    case completed
    case stopped
}
