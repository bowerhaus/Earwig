@testable import Earwig
import Testing

struct VoiceCatalogueTests {

    private func voice(_ name: String, _ language: String = "en-GB", _ quality: VoiceInfo.Quality = .enhanced, _ gender: VoiceInfo.Gender = .female) -> VoiceInfo {
        VoiceInfo(identifier: "\(name).\(language).\(quality)", name: name, language: language, quality: quality, gender: gender)
    }

    @Test func stephanieIsThePresenterWhenSheIsThere() throws {
        let voices = [voice("Jamie", "en-GB", .premium, .male), voice("Stephanie"), voice("Serena", "en-GB", .premium)]
        let choice = try #require(VoiceCatalogue.choose(from: voices))
        #expect(choice.presenter.name == "Stephanie")
        #expect(choice.presenterIsPreferred)
        #expect(choice.cue.name == "Jamie")
    }

    @Test func theQualityIsTakenOffANamesEnd() {
        #expect(VoiceInfo.baseName("Stephanie (Enhanced)") == "Stephanie")
        #expect(VoiceInfo.baseName("Jamie (Premium)") == "Jamie")
        #expect(VoiceInfo.baseName("Daniel") == "Daniel")
        #expect(VoiceInfo.baseName("(Odd)") == "(Odd)")
    }

    @Test func aPersonalVoicePickedByHandPresentsButNeverCues() throws {
        let mine = VoiceInfo(identifier: "personal.andy", name: "Andy", language: "en-GB", quality: .compact, gender: .male, isPersonal: true)
        let voices = [mine, voice("Stephanie"), voice("Jamie", "en-GB", .premium, .male)]
        // Not the default.
        #expect(VoiceCatalogue.choose(from: voices)?.presenter.name == "Stephanie")
        let picked = try #require(VoiceCatalogue.choose(from: voices, presenterID: "personal.andy"))
        #expect(picked.presenter == mine)
        #expect(picked.presenterIsPreferred)
        #expect(picked.cue.name == "Stephanie")
        // Gone, the default again.
        #expect(VoiceCatalogue.choose(from: [voice("Stephanie")], presenterID: "personal.andy")?.presenter.name == "Stephanie")
        #expect(VoiceCatalogue.presenterOptions(from: voices + [voice("Daniel", "en-GB", .compact, .male)]).map(\.name) == ["Andy", "Jamie", "Stephanie"])
    }

    @Test func aCompactStephanieIsNotThePreferredVoice() throws {
        let voices = [voice("Stephanie", "en-GB", .compact), voice("Kate", "en-GB", .enhanced)]
        let choice = try #require(VoiceCatalogue.choose(from: voices))
        #expect(choice.presenter.name == "Kate")
        #expect(!choice.presenterIsPreferred)
    }

    @Test func withoutStephanieTheBestBritishVoice() {
        let voices = [voice("Daniel", "en-GB", .compact, .male), voice("Ava", "en-US", .premium), voice("Kate", "en-GB", .enhanced)]
        #expect(VoiceCatalogue.presenter(from: voices)?.name == "Kate")
    }

    @Test func withNoBritishVoiceTheBestEnglishOne() {
        let voices = [voice("Thomas", "fr-FR", .premium, .male), voice("Ava", "en-US", .premium), voice("Karen", "en-AU", .compact)]
        #expect(VoiceCatalogue.presenter(from: voices)?.name == "Ava")
        #expect(VoiceCatalogue.choose(from: [voice("Thomas", "fr-FR")]) == nil)
    }

    @Test func theCueVoiceIsNeverThePresentersAndPrefersTheOtherGender() throws {
        let stephanie = voice("Stephanie")
        let voices = [stephanie, voice("Serena", "en-GB", .premium), voice("Daniel", "en-GB", .compact, .male)]
        #expect(VoiceCatalogue.cue(from: voices, presenter: stephanie)?.name == "Daniel")
        // With only the same gender, the best of the rest.
        #expect(VoiceCatalogue.cue(from: [stephanie, voice("Kate", "en-GB", .compact), voice("Serena", "en-GB", .premium)], presenter: stephanie)?.name == "Serena")
        // With only the presenter's voice, it reads the cues too.
        let alone = try #require(VoiceCatalogue.choose(from: [stephanie]))
        #expect(alone.cue == stephanie)
    }

    @Test func aBritishCueVoiceBeforeAnotherEnglishOne() {
        let stephanie = voice("Stephanie")
        let voices = [stephanie, voice("Aaron", "en-US", .premium, .male), voice("Arthur", "en-GB", .compact, .male)]
        #expect(VoiceCatalogue.cue(from: voices, presenter: stephanie)?.name == "Arthur")
    }

    @Test func aCueVoicePickedByHandReadsTheCues() throws {
        let voices = [voice("Stephanie"), voice("Jamie", "en-GB", .premium, .male), voice("Serena", "en-GB", .premium)]
        let choice = try #require(VoiceCatalogue.choose(from: voices, cueID: "Serena.en-GB.premium"))
        #expect(choice.presenter.name == "Stephanie")
        #expect(choice.cue.name == "Serena")
    }

    @Test func aCueVoiceNoLongerInstalledIsAutomaticAgain() throws {
        let voices = [voice("Stephanie"), voice("Jamie", "en-GB", .premium, .male)]
        let choice = try #require(VoiceCatalogue.choose(from: voices, cueID: "Serena.en-GB.premium"))
        #expect(choice.cue.name == "Jamie")
        // No pick is automatic, as before.
        #expect(VoiceCatalogue.choose(from: voices, cueID: nil)?.cue.name == "Jamie")
    }

    @Test func aPersonalVoiceIsNeverOfferedOrUsedAsTheCueVoice() throws {
        let mine = VoiceInfo(identifier: "personal.andy", name: "Andy", language: "en-GB", quality: .premium, gender: .male, isPersonal: true)
        let voices = [mine, voice("Stephanie"), voice("Jamie", "en-GB", .premium, .male), voice("Daniel", "en-GB", .compact, .male),
                      voice("Ava", "en-US", .premium), voice("Thomas", "fr-FR", .premium, .male)]
        #expect(VoiceCatalogue.cueOptions(from: voices).map(\.name) == ["Jamie", "Stephanie", "Ava"])
        let choice = try #require(VoiceCatalogue.choose(from: voices, cueID: "personal.andy"))
        #expect(choice.cue.name == "Jamie")
    }
}
