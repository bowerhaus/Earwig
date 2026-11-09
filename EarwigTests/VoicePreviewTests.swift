import Testing
@testable import Earwig

@MainActor
struct VoicePreviewTests {
    @Test func previewReadsTheSamplesWholeFirstLineNotOneWord() {
        #expect(VoicePreview.text == "Morning! We're starting at the old harbour, just as the tide turns.")
    }
}
