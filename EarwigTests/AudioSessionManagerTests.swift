@testable import Earwig
import Testing

/// The one shared audio session, configured by one take after another (review C1, plan 005).
@MainActor
struct AudioSessionManagerTests {

    @Test func aLateTeardownLeavesTheNextTakesSessionAlone() throws {
        var events: [String] = []
        let first = AudioSessionManager()
        let second = AudioSessionManager()
        first.onEvent = { events.append($0) }
        second.onEvent = { events.append($0) }
        try first.configure()
        try second.configure()
        first.deactivate()
        #expect(events.last == "session left active: configured since for another take")
        second.deactivate()
        #expect(events.last == "session deactivated")
    }
}
