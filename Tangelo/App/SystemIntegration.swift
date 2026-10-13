// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import AppKit
import IOKit.pwr_mgt
import MediaPlayer
import Observation

/// Connects playback to macOS: Now Playing (Control Center, lock screen), media keys and AirPods,
/// and keeping the display awake while video plays.
@MainActor
final class SystemIntegration {
    static let shared = SystemIntegration()

    private let player = Player.shared
    private var assertion: IOPMAssertionID = 0
    private var assertionKind: String?

    func install() {
        registerRemoteCommands()
        observe()
    }

    /// Re-arms after every change; only coarse properties are tracked, so this doesn't fire on every time tick.
    private func observe() {
        withObservationTracking {
            _ = (player.status, player.currentItem, player.duration, player.rate, player.seekGeneration)
            _ = (player.tagTitle, player.tagArtist, player.tagAlbum, player.artwork, player.hasVideo, player.queue.count)
        } onChange: {
            Task { @MainActor in
                self.update()
                self.observe()
            }
        }
    }

    private func update() {
        updatePowerAssertion()
        updateNowPlaying()
    }

    // MARK: - Sleep

    private func updatePowerAssertion() {
        let wanted: String? = switch (player.isPlaying, player.hasVideo) {
        case (true, true): kIOPMAssertionTypePreventUserIdleDisplaySleep
        case (true, false): kIOPMAssertionTypePreventUserIdleSystemSleep
        default: nil
        }
        guard wanted != assertionKind else { return }

        if assertionKind != nil {
            IOPMAssertionRelease(assertion)
            assertion = 0
        }
        assertionKind = wanted
        if let wanted {
            let reason = player.hasVideo ? "Tangelo is playing video" : "Tangelo is playing audio"
            IOPMAssertionCreateWithName(wanted as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), reason as CFString, &assertion)
        }
    }

    // MARK: - Now Playing

    private func updateNowPlaying() {
        let center = MPNowPlayingInfoCenter.default()
        guard let item = player.currentItem else {
            center.nowPlayingInfo = nil
            center.playbackState = .stopped
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: player.tagTitle ?? item.displayName,
            MPMediaItemPropertyPlaybackDuration: player.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player.elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: player.status == .playing ? Double(player.rate) : 0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: (player.hasVideo ? MPNowPlayingInfoMediaType.video : .audio).rawValue,
            MPNowPlayingInfoPropertyPlaybackQueueIndex: player.currentIndex ?? 0,
            MPNowPlayingInfoPropertyPlaybackQueueCount: player.queue.count,
        ]
        if let artist = player.tagArtist { info[MPMediaItemPropertyArtist] = artist }
        if let album = player.tagAlbum { info[MPMediaItemPropertyAlbumTitle] = album }
        if let artwork = player.artwork {
            let image = artwork
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in image }
        }
        center.nowPlayingInfo = info
        center.playbackState = switch player.status {
        case .playing, .buffering, .opening: .playing
        case .paused: .paused
        default: .stopped
        }

        let commands = MPRemoteCommandCenter.shared()
        commands.nextTrackCommand.isEnabled = player.hasNext
        commands.previousTrackCommand.isEnabled = true
    }

    private func registerRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()

        // Handlers may be called off the main thread; they hop to the main actor and report success immediately.
        func on(_ command: MPRemoteCommand, _ action: @escaping @MainActor @Sendable () -> Void) {
            command.addTarget { @Sendable _ in
                Task { @MainActor in action() }
                return .success
            }
        }

        on(commands.playCommand) { Player.shared.play() }
        on(commands.pauseCommand) { Player.shared.pause() }
        on(commands.togglePlayPauseCommand) { Player.shared.togglePlayPause() }
        on(commands.stopCommand) { Player.shared.pause() }
        on(commands.nextTrackCommand) { Player.shared.next() }
        on(commands.previousTrackCommand) { Player.shared.previous() }

        commands.skipForwardCommand.preferredIntervals = [10]
        commands.skipBackwardCommand.preferredIntervals = [10]
        on(commands.skipForwardCommand) { Player.shared.skip(by: 10) }
        on(commands.skipBackwardCommand) { Player.shared.skip(by: -10) }

        commands.changePlaybackPositionCommand.addTarget { @Sendable event in
            guard let time = (event as? MPChangePlaybackPositionCommandEvent)?.positionTime else { return .commandFailed }
            Task { @MainActor in Player.shared.seek(seconds: time) }
            return .success
        }
    }
}
