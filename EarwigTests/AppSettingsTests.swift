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
        #expect(settings.mode == .voice)
        #expect(settings.textSize == 40)
        #expect(!settings.lightsVoice)
        #expect(settings.recording == .off)
        #expect(settings.videoQuality == .hd1080)
        #expect(!settings.keepsRecordings)
        #expect(settings.cameraBehindText)
        #expect(settings.textOverCamera == TakeSettings.defaultTextOverCamera)
    }

    @Test func theTextOverTheCameraStaysInItsRange() {
        settings.textOverCamera = 0
        #expect(settings.textOverCamera == TakeSettings.textOverCameraRange.lowerBound)
        settings.defaults.set(3.0, forKey: TakeSettings.textOverCameraKey)
        #expect(settings.textOverCamera == 1)
    }

    @Test func anUnknownStoredRecordingReadsAsTheDefault() {
        settings.defaults.set("film", forKey: TakeSettings.recordingKey)
        settings.defaults.set("8K", forKey: TakeSettings.videoQualityKey)
        #expect(settings.recording == .off)
        #expect(settings.videoQuality == .hd1080)
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

    @Test func theModeIsKept() {
        settings.mode = .screen
        #expect(settings.mode == .screen)
        settings.defaults.set("nonsense", forKey: TakeSettings.modeKey)
        #expect(settings.mode == .voice)
        // The modes of the first build: Ear and Both are the voice.
        settings.defaults.set("both", forKey: TakeSettings.modeKey)
        #expect(settings.mode == .voice)
        settings.defaults.set("ear", forKey: TakeSettings.modeKey)
        #expect(settings.mode == .voice)
        #expect(TakeMode.voice.voiced && !TakeMode.screen.voiced)
    }

    @Test func theTextSizeIsKeptInItsRange() {
        settings.textSize = 100
        #expect(settings.textSize == 72)
        settings.textSize = 10
        #expect(settings.textSize == 24)
        settings.defaults.set(5.0, forKey: TakeSettings.textSizeKey)
        #expect(settings.textSize == 24)
        settings.textSize = 52
        #expect(settings.textSize == 52)
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
