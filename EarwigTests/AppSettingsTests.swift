@testable import Earwig
import Foundation
import Testing

struct AppSettingsTests {

    /// A fresh store of its own, so tests never touch the app's settings or each other's.
    private let settings: TakeSettings = {
        let name = "AppSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return TakeSettings(defaults: defaults)
    }()

    @Test func theDefaults() {
        #expect(settings.lead == 5)
        #expect(settings.voiceSpeed == 0.95)
        #expect(settings.pacing == .hybrid)
        #expect(settings.startMode == .tonesOnly)
    }

    @Test func theFollowSettingsCarryThem() {
        settings.lead = 4
        settings.pacing = .phraseGated
        settings.startMode = .slate
        let follow = settings.followSettings
        #expect(follow.lead == 4)
        #expect(follow.pacing == .phraseGated)
        #expect(follow.start == .slate)
        #expect(follow.minSpeed == FollowSettings().minSpeed)
    }

    @Test func theLeadIsKeptInItsRange() {
        settings.lead = 9
        #expect(settings.lead == 6)
        settings.lead = 1
        #expect(settings.lead == 2)
        settings.defaults.set(0, forKey: TakeSettings.leadKey)
        #expect(settings.lead == 2)
    }

    @Test func theLeadsSecondsAtTheDefaultRate() {
        #expect(abs(TakeSettings.seconds(forLead: 3) - 1.2) < 0.001)
    }

    @Test func theVoiceSpeedIsOneOfTheChoices() {
        settings.voiceSpeed = 0.8
        #expect(settings.voiceSpeed == 0.8)
        settings.defaults.set(0.87, forKey: TakeSettings.voiceSpeedKey)
        #expect(settings.voiceSpeed == 0.85)
        settings.defaults.set(3.0, forKey: TakeSettings.voiceSpeedKey)
        #expect(settings.voiceSpeed == 1.0)
    }
}
