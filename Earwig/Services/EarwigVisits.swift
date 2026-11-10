import Foundation
import Observation

/// How often the earwig comes (plan 014, decision 10, amended at device check 2): the chance of
/// a visit a moment after a screen appears and every `VisitSchedule.again` while it stays. The
/// steps are uneven, so the rare ones are easy to pick. Set by the Critter slider in Settings'
/// Screen group.
enum VisitFrequency: Int, CaseIterable, Sendable {
    case never
    case oneIn50
    case oneIn20
    case oneIn10
    case oneIn5
    case oneIn2
    case everyVisit

    static let key = "earwigVisits"
    static let standard = VisitFrequency.oneIn10

    var chance: Double {
        switch self {
        case .never: 0
        case .oneIn50: 1.0 / 50
        case .oneIn20: 1.0 / 20
        case .oneIn10: 1.0 / 10
        case .oneIn5: 1.0 / 5
        case .oneIn2: 1.0 / 2
        case .everyVisit: 1
        }
    }

    var title: String {
        switch self {
        case .never: "Off"
        case .oneIn50: "Rarely"
        case .oneIn20: "Now and Then"
        case .oneIn10: "Sometimes"
        case .oneIn5: "Often"
        case .oneIn2: "Very Often"
        case .everyVisit: "All the Time"
        }
    }

    /// The setting, or Every Visit with `-EarwigVisits YES` in a Debug build (decision 11).
    static func current(_ defaults: UserDefaults = .standard) -> VisitFrequency {
        #if DEBUG
        if defaults.bool(forKey: "EarwigVisits") { return .everyVisit }
        #endif
        guard defaults.object(forKey: key) != nil else { return standard }
        return VisitFrequency(rawValue: defaults.integer(forKey: key)) ?? standard
    }
}

/// Whether a screen gets a visit (plan 014, decision 8): its chance, and an app-wide rest
/// between visits so moving quickly between screens cannot bring two close together. All the
/// Time ignores the rest, for testing.
enum VisitSchedule {
    static let rest: TimeInterval = 180
    /// How long after a screen appears a visit begins, so it is not there the moment it opens.
    static let delays: ClosedRange<Double> = 2...6
    /// Long enough for the splash to be gone, for `-EarwigVisits YES`.
    static let testingDelay: TimeInterval = 1
    /// How often a screen rolls again while it stays (Andy, device check 2).
    static let again: TimeInterval = 30

    static func delay<G: RandomNumberGenerator>(for frequency: VisitFrequency, using random: inout G) -> TimeInterval {
        frequency == .everyVisit ? testingDelay : Double.random(in: delays, using: &random)
    }

    /// `roll` is a random number from 0 up to 1.
    static func visits(_ frequency: VisitFrequency, roll: Double, at now: TimeInterval, lastVisit: TimeInterval?) -> Bool {
        switch frequency {
        case .never: return false
        case .everyVisit: return true
        default:
            guard roll < frequency.chance else { return false }
            guard let lastVisit else { return true }
            return now - lastVisit >= rest
        }
    }
}

/// The app's visits, shared by the screens (plan 014, decisions 8 and 9): when the last began,
/// so the rest applies across them, whether one is under way, so there is only ever one, and
/// whether the splash is over.
@MainActor
@Observable
final class EarwigVisits {
    /// Set when the splash has gone; no visit before.
    var ready = false
    private(set) var lastVisit: TimeInterval?
    /// When the walk under way ends.
    private(set) var busyUntil: TimeInterval = 0

    /// Claims a walk for a screen, or refuses one while another is under way.
    func begin(_ walk: Walk) -> Bool {
        guard ready, walk.start >= busyUntil else { return false }
        lastVisit = walk.start
        busyUntil = walk.end
        return true
    }

    /// A run replaces the walk it came from; its end is the visit's end.
    func ran(_ run: Walk) {
        busyUntil = run.end
    }

    /// The walk has gone before its end, taken away or left with its screen.
    func ended(at time: TimeInterval) {
        busyUntil = min(busyUntil, time)
    }
}
