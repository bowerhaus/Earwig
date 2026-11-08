import AVFoundation
import AVKit
import SwiftUI

/// What Finished plays back (plan 010, decision 7): the take's file, or its sound alone.
struct Playback: Identifiable, Equatable {
    var url: URL
    var soundOnly: Bool
    var id: String { url.path + (soundOnly ? "#sound" : "") }
}

/// Plays a take's recording, with the player's own controls. The take has let the audio session
/// go, so playback sets it to `.playback`, heard on the earpiece or the speaker, whichever is
/// connected; Next Take sets it for a take again.
struct PlaybackView: View {
    let playback: Playback
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        NavigationStack {
            VideoPlayer(player: player) {
                if playback.soundOnly {
                    Image(systemName: "waveform")
                        .font(.system(size: 72, weight: .semibold))
                        .foregroundStyle(EarwigTheme.secondaryText)
                        .accessibilityHidden(true)
                }
            }
            .background(EarwigTheme.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(EarwigTheme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playback, mode: .default)
                try session.setActive(true)
            } catch {
                Log.event("playback: session failed: \(error.localizedDescription)")
            }
            let item = await Self.item(for: playback)
            let player = AVPlayer(playerItem: item)
            self.player = player
            player.play()
            Log.event("playback: \(playback.soundOnly ? "sound" : "file") \(playback.url.lastPathComponent)")
        }
        .onDisappear {
            player?.pause()
            player = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    /// The file, or a composition of its sound track alone, so no picture is decoded.
    static func item(for playback: Playback) async -> AVPlayerItem {
        let asset = AVURLAsset(url: playback.url)
        guard playback.soundOnly,
              let track = try? await asset.loadTracks(withMediaType: .audio).first,
              let range = try? await track.load(.timeRange) else { return AVPlayerItem(asset: asset) }
        let composition = AVMutableComposition()
        guard let sound = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
              (try? sound.insertTimeRange(range, of: track, at: .zero)) != nil else { return AVPlayerItem(asset: asset) }
        return AVPlayerItem(asset: composition)
    }
}
