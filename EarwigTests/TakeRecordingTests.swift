import AVFoundation
@testable import Earwig
import Foundation
import SwiftData
import Testing

/// The recording's writer against made-up frames and mic buffers on chosen host times (plan 010,
/// step 2), writing real files in a temporary folder.
struct TakeRecordingTests {

    private let folder: URL = {
        let url = FileManager.default.temporaryDirectory.appending(path: "TakeRecordingTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private static let rate = 48_000.0
    private static let frames: AVAudioFrameCount = 1024

    /// A mic buffer of a quiet tone, as the tap gives them: standard float at 48 kHz.
    private static func micBuffer() -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        for index in 0..<Int(frames) { buffer.floatChannelData![0][index] = 0.1 * sin(Float(index) * 0.05) }
        return buffer
    }

    /// A small grey frame stamped at `host` seconds on the host clock.
    private static func frame(at host: TimeInterval) -> CMSampleBuffer {
        var pixels: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, 64, 48, kCVPixelFormatType_32BGRA, nil, &pixels)
        var format: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixels!, formatDescriptionOut: &format)
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 30),
                                        presentationTimeStamp: CMTime(seconds: host, preferredTimescale: 1_000_000_000), decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixels!, formatDescription: format!,
                                                 sampleTiming: &timing, sampleBufferOut: &sample)
        return sample!
    }

    private static let videoSettings: [String: Any] = [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 64, AVVideoHeightKey: 48]

    private func writer(video: Bool, endWait: TimeInterval = RecordingWriter.endWait) throws -> (RecordingWriter, DispatchQueue) {
        let queue = DispatchQueue(label: "test.recording")
        let url = folder.appending(path: video ? "take.mov" : "take.m4a")
        let writer = try RecordingWriter(url: url, queue: queue, video: video ? Self.videoSettings : nil, rotation: 90,
                                         clock: nil, sampleRate: Self.rate, endWait: endWait)
        return (writer, queue)
    }

    /// The mic's buffers and, for video, the camera's frames from `from` to `to` host seconds, in
    /// the order they were taken, as a take hands them over: the writer drops whatever runs too far
    /// ahead of the other track.
    private func feed(_ writer: RecordingWriter, _ queue: DispatchQueue, from: TimeInterval, to: TimeInterval, frames: Bool = true) {
        var sound = from
        var picture = from
        while sound < to || (frames && picture < to) {
            if !frames || sound <= picture, sound < to {
                writer.appendAudio(Self.micBuffer(), hostTime: sound)
                sound += Double(Self.frames) / Self.rate
            } else {
                let sample = Self.frame(at: picture)
                queue.async { writer.appendVideo(sample) }
                picture += 1.0 / 30
                // A camera's pace, sped up: the writer drops frames it is handed faster than it encodes.
                usleep(4_000)
            }
        }
    }

    /// Asks for the end at `end`, then hands over what comes after it was asked for, as the mic
    /// and the camera go on after a take ends.
    private func finish(_ writer: RecordingWriter, at end: TimeInterval, then more: () -> Void) async throws -> RecordingResult? {
        async let ended = writer.finish(at: end)
        try await Task.sleep(for: .milliseconds(50))
        more()
        return await ended
    }

    private func tracks(_ url: URL) async throws -> (audio: CMTimeRange?, video: CMTimeRange?, duration: Double) {
        let asset = AVURLAsset(url: url)
        let audio = try await asset.loadTracks(withMediaType: .audio).first
        let video = try await asset.loadTracks(withMediaType: .video).first
        let audioRange = try await audio?.load(.timeRange)
        let videoRange = try await video?.load(.timeRange)
        return (audioRange, videoRange, try await asset.load(.duration).seconds)
    }

    @Test func soundAloneIsWrittenFromTheStartToTheEnd() async throws {
        let (writer, queue) = try writer(video: false)
        let start = HostClock.now - 20
        writer.begin(at: start)
        feed(writer, queue, from: start - 0.5, to: start + 1.2, frames: false)
        let result = try #require(await finish(writer, at: start + 1.5) {
            feed(writer, queue, from: start + 1.2, to: start + 2.2, frames: false)
        })
        #expect(!result.video)
        #expect(result.url.pathExtension == "m4a")
        #expect(abs(result.duration - 1.5) < 0.05)
        let file = try await tracks(result.url)
        #expect(file.video == nil)
        #expect(abs(file.duration - 1.5) < 0.1)
    }

    @Test func videoStartsOnAFrameWithTheSoundBeforeItTrimmed() async throws {
        let (writer, queue) = try writer(video: true)
        let start = HostClock.now - 20
        writer.begin(at: start)
        // Sound from before the start; the first frame a tenth of a second after it.
        feed(writer, queue, from: start - 0.5, to: start + 0.1, frames: false)
        feed(writer, queue, from: start + 0.1, to: start + 1.2)
        let result = try #require(await finish(writer, at: start + 1.6) {
            feed(writer, queue, from: start + 1.2, to: start + 2.2)
        })
        #expect(result.video)
        #expect(abs(result.duration - 1.5) < 0.05)
        let file = try await tracks(result.url)
        let video = try #require(file.video)
        let audio = try #require(file.audio)
        // Both begin at the file's start, the first frame.
        #expect(video.start.seconds < 0.01)
        #expect(audio.start.seconds < 0.03)
        #expect(abs(file.duration - 1.5) < 0.1)
        // The frames handed over after the end was asked for reach it.
        #expect(abs(video.duration.seconds - 1.5) < 0.1)
    }

    @Test func videoStoppedHalfwayLeavesTheSoundToTheEnd() async throws {
        let (writer, queue) = try writer(video: true)
        let start = HostClock.now - 20
        writer.begin(at: start)
        feed(writer, queue, from: start, to: start + 1.0)
        writer.stopVideo(reason: "the phone was locked")
        feed(writer, queue, from: start + 1.0, to: start + 1.8, frames: false)
        let result = try #require(await finish(writer, at: start + 2.0) {
            feed(writer, queue, from: start + 1.8, to: start + 2.5, frames: false)
        })
        #expect(result.videoStopReason == "the phone was locked")
        let stoppedAt = try #require(result.videoStoppedAt)
        #expect(abs(stoppedAt - 0.97) < 0.05)
        let file = try await tracks(result.url)
        #expect(abs((file.video?.duration.seconds ?? 0) - 1.0) < 0.1)
        #expect(abs((file.audio?.duration.seconds ?? 0) - 2.0) < 0.1)
    }

    @Test func videoStoppedBeforeAnyFrameKeepsTheSound() async throws {
        let (writer, queue) = try writer(video: true)
        let start = HostClock.now - 20
        writer.begin(at: start)
        // The camera was interrupted while framing: no frame comes, the sound is kept (review C3).
        feed(writer, queue, from: start, to: start + 0.5, frames: false)
        writer.stopVideo(reason: "the camera stopped")
        let result = try #require(await finish(writer, at: start + 1.0) {
            feed(writer, queue, from: start + 0.5, to: start + 1.2, frames: false)
        })
        #expect(result.videoStoppedAt == 0)
        let file = try await tracks(result.url)
        #expect(file.video == nil || file.video?.duration.seconds == 0)
        #expect(abs((file.audio?.duration.seconds ?? 0) - 1.0) < 0.1)
    }

    @Test func noFramesComingEndsAfterTheWaitWithTheSound() async throws {
        let (writer, queue) = try writer(video: true, endWait: 0.2)
        let start = HostClock.now - 20
        writer.begin(at: start)
        feed(writer, queue, from: start, to: start + 0.5)
        let result = try #require(await finish(writer, at: start + 1.0) {
            feed(writer, queue, from: start + 0.5, to: start + 1.2, frames: false)
        })
        #expect(abs(result.duration - 1.0) < 0.05)
    }

    @Test func nothingWrittenIsNoRecording() async throws {
        let (writer, _) = try writer(video: false)
        writer.begin(at: HostClock.now - 20)
        #expect(await writer.finish(at: HostClock.now - 19) == nil)
    }
}

/// Where recordings go, and which are kept (plan 010, decision 6).
struct RecordingStoreTests {

    private let store = RecordingStore(documents: FileManager.default.temporaryDirectory
        .appending(path: "RecordingStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory))

    private let defaults: UserDefaults = {
        let name = "RecordingStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }()

    /// Makes a recording's file, as the writer would, and returns its path relative to Documents.
    private func record(step: Int, take: Int, size: Int = 1000) throws -> String {
        let url = try store.url(scriptTitle: "The Harbour Walk", step: step, take: take, video: true)
        try Data(count: size).write(to: url)
        return try #require(store.relativePath(of: url))
    }

    private func exists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: store.url(forRelativePath: path).path)
    }

    @Test func aRecordingIsNamedAsTheSlateSaysIt() throws {
        let url = try store.url(scriptTitle: "The Harbour Walk", step: 3, take: 2, video: true)
        #expect(url.lastPathComponent == "Step 3 Take 2.mov")
        #expect(store.relativePath(of: url) == "Recordings/The Harbour Walk/Step 3 Take 2.mov")
        #expect(RecordingStore.fileName(step: 1, take: 4, video: false) == "Step 1 Take 4.m4a")
    }

    @Test func aNameAlreadyTakenIsNeverWrittenOver() throws {
        let first = try record(step: 1, take: 1)
        let second = try store.url(scriptTitle: "The Harbour Walk", step: 1, take: 1, video: true)
        #expect(second.lastPathComponent == "Step 1 Take 1 2.mov")
        #expect(exists(first))
    }

    @Test func aTitleIsMadeSafeAsAFolder() {
        #expect(RecordingStore.folderName("Rosie's Walk: 2/3") == "Rosie's Walk- 2-3")
        #expect(RecordingStore.folderName("  ") == "Untitled")
        #expect(RecordingStore.folderName(".hidden") == "hidden")
    }

    @Test func withKeepOffEachRecordingReplacesTheLast() throws {
        let first = try record(step: 1, take: 1)
        #expect(store.started(first, keep: false, defaults: defaults) == nil)
        let second = try record(step: 1, take: 2)
        #expect(store.started(second, keep: false, defaults: defaults) == first)
        #expect(!exists(first))
        #expect(exists(second))
    }

    @Test func withKeepOnEveryRecordingIsKept() throws {
        let first = try record(step: 1, take: 1)
        store.started(first, keep: true, defaults: defaults)
        let second = try record(step: 1, take: 2)
        #expect(store.started(second, keep: true, defaults: defaults) == nil)
        #expect(exists(first))
        #expect(exists(second))
    }

    @Test func turningKeepOffReplacesOnlyRecordingsMadeWithItOff() throws {
        let kept = try record(step: 1, take: 1)
        store.started(kept, keep: true, defaults: defaults)
        let unkept = try record(step: 1, take: 2)
        #expect(store.started(unkept, keep: false, defaults: defaults) == nil)
        let next = try record(step: 1, take: 3)
        #expect(store.started(next, keep: false, defaults: defaults) == unkept)
        #expect(exists(kept))
    }

    @Test func aRecordingThatCameToNothingIsDiscarded() throws {
        let path = try record(step: 1, take: 1)
        store.started(path, keep: false, defaults: defaults)
        store.discard(path, defaults: defaults)
        #expect(!exists(path))
        let next = try record(step: 1, take: 2)
        #expect(store.started(next, keep: false, defaults: defaults) == nil)
    }

    @Test func theSizeAndDeleteAll() throws {
        _ = try record(step: 1, take: 1, size: 1000)
        _ = try record(step: 2, take: 1, size: 500)
        #expect(store.size() == 1500)
        try store.deleteAll(defaults: defaults)
        #expect(store.size() == 0)
        #expect(defaults.string(forKey: RecordingStore.lastUnkeptKey) == nil)
    }
}

/// A take's recording as its script keeps it (plan 010, decision 6; review T1).
@MainActor
struct ScriptTakeRecorderTests {

    /// Held for as long as its context is used, or the test host crashes (CLAUDE.md).
    private let container = ModelContainerFactory.inMemory()

    private let store = RecordingStore(documents: FileManager.default.temporaryDirectory
        .appending(path: "ScriptTakeRecorderTests-\(UUID().uuidString)", directoryHint: .isDirectory))

    private let defaults: UserDefaults = {
        let name = "ScriptTakeRecorderTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }()

    @Test func withKeepOffTheLastTakeAloneNamesARecording() throws {
        let context = container.mainContext
        let script = try ScriptImporter(context: context).paste(Fixtures.harbourWalk).script
        func recorder(take: Int) throws -> (ScriptTakeRecorder, String) {
            let url = try store.url(scriptTitle: script.title, step: 1, take: take, video: false)
            try Data(count: 10).write(to: url)
            let path = try #require(store.relativePath(of: url))
            let place = ScriptTakeRecorder.Recording(path: path, keep: false, store: store, defaults: defaults)
            return (ScriptTakeRecorder(script: script, stepIndex: 0, number: take, context: context, recording: place), path)
        }
        let (first, firstPath) = try recorder(take: 1)
        first.started(at: Date())
        #expect(first.take?.recordingPath == firstPath)

        // The second replaces the first: its file goes, and the first take no longer names it.
        let (second, secondPath) = try recorder(take: 2)
        second.started(at: Date())
        #expect(first.take?.recordingPath == nil)
        #expect(second.take?.recordingPath == secondPath)
        #expect(!FileManager.default.fileExists(atPath: store.url(forRelativePath: firstPath).path))

        // A recording that came to nothing leaves no file and no path.
        second.recordingFinished(nil)
        #expect(second.take?.recordingPath == nil)
        #expect(!FileManager.default.fileExists(atPath: store.url(forRelativePath: secondPath).path))
    }
}
