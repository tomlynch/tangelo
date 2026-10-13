// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import AVFoundation
import Observation

/// AirPlay video. libVLC can't send video over AirPlay, so for formats AVFoundation can play
/// (MP4, MOV, M4V, HLS, common audio) Tangelo keeps an AVPlayer loaded with the current item.
/// When the user picks an AirPlay device for it, libVLC pauses and AVPlayer takes over at the
/// same position; when AirPlay ends, libVLC resumes where AVPlayer stopped.
@MainActor
@Observable
final class AirPlay: ExternalTransport {
    static let shared = AirPlay()

    /// True when the current item can be AirPlayed.
    private(set) var supported = false
    /// True while video is playing on an AirPlay device.
    private(set) var isActive = false

    @ObservationIgnored let avPlayer: AVPlayer = {
        let player = AVPlayer()
        player.allowsExternalPlayback = true
        player.isMuted = true // never audible locally; only plays while routed to a device
        return player
    }()

    @ObservationIgnored private var observations: [NSKeyValueObservation] = []
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var endObserver: NSObjectProtocol?

    private static let extensions: Set<String> = ["mp4", "m4v", "mov", "m4a", "mp3", "aac", "wav", "aif", "aiff", "m3u8"]

    static func canPlay(_ url: URL) -> Bool {
        extensions.contains(url.pathExtension.lowercased())
    }

    init() {
        observations.append(avPlayer.observe(\.isExternalPlaybackActive, options: [.new]) { player, _ in
            let active = player.isExternalPlaybackActive
            Task { @MainActor in AirPlay.shared.externalPlaybackChanged(active) }
        })
        observations.append(avPlayer.observe(\.timeControlStatus, options: [.new]) { _, _ in
            Task { @MainActor in AirPlay.shared.publishState() }
        })
        timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { _ in
            MainActor.assumeIsolated { AirPlay.shared.publishState() }
        }
        endObserver = NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: nil, queue: .main) { note in
            nonisolated(unsafe) let item = note.object as AnyObject?
            MainActor.assumeIsolated {
                guard AirPlay.shared.isActive, item === AirPlay.shared.avPlayer.currentItem else { return }
                Player.shared.externalReachedEnd()
            }
        }
    }

    /// Loads `url` so the AirPlay button can route it. Returns true if AirPlay is active and has taken over playback.
    @discardableResult
    func prepare(_ url: URL?, startingAt seconds: TimeInterval = 0) -> Bool {
        guard let url, Self.canPlay(url) else {
            supported = false
            avPlayer.replaceCurrentItem(with: nil)
            return false
        }
        supported = true
        avPlayer.replaceCurrentItem(with: AVPlayerItem(url: url))
        guard isActive else { return false }
        avPlayer.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        avPlayer.play()
        return true
    }

    // MARK: - ExternalTransport

    func play() { avPlayer.play() }
    func pause() { avPlayer.pause() }
    func seek(to seconds: TimeInterval) { avPlayer.seek(to: CMTime(seconds: seconds, preferredTimescale: 600)) }
    func setRate(_ rate: Float) { avPlayer.defaultRate = rate; if avPlayer.rate > 0 { avPlayer.rate = rate } }

    // MARK: - Private

    private func externalPlaybackChanged(_ active: Bool) {
        guard active != isActive else { return }
        let player = Player.shared
        if active {
            isActive = true
            let resumeAt = player.elapsed
            let wasPlaying = player.isPlaying
            player.handOff(to: self)
            avPlayer.seek(to: CMTime(seconds: resumeAt, preferredTimescale: 600)) { _ in
                Task { @MainActor in if wasPlaying { AirPlay.shared.avPlayer.play() } }
            }
        } else {
            isActive = false
            let seconds = avPlayer.currentTime().seconds
            let wasPlaying = avPlayer.timeControlStatus != .paused
            avPlayer.pause()
            player.takeBack(at: seconds.isFinite ? seconds : player.elapsed, playing: wasPlaying)
        }
    }

    private func publishState() {
        guard isActive else { return }
        let elapsed = avPlayer.currentTime().seconds
        let duration = avPlayer.currentItem?.duration.seconds ?? 0
        Player.shared.externalUpdate(
            elapsed: elapsed.isFinite ? elapsed : 0,
            duration: duration.isFinite ? duration : 0,
            playing: avPlayer.timeControlStatus != .paused
        )
    }
}

/// Something other than libVLC that can drive playback (AirPlay today).
@MainActor
protocol ExternalTransport: AnyObject {
    var isActive: Bool { get }
    func play()
    func pause()
    func seek(to seconds: TimeInterval)
    func setRate(_ rate: Float)
}
