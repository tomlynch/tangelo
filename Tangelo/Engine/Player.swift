// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import AppKit
import Observation
import VLCKit

/// The playback model the UI binds to. VLCKit types stay inside the Engine folder
/// so a future Windows/Linux shell only has to reimplement this file against libVLC.
@MainActor
@Observable
final class Player: NSObject {
    static let shared = Player()

    enum Status: Equatable {
        case idle, opening, buffering, playing, paused, ended, failed
    }

    struct Track: Identifiable, Hashable {
        let id: Int32
        let name: String
    }

    private(set) var status: Status = .idle
    private(set) var queue: [MediaItem] = []
    private(set) var currentIndex: Int?
    private(set) var elapsed: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var videoSize: CGSize = .zero
    private(set) var artwork: NSImage?
    private(set) var metadataTitle: String?
    /// Raw tags for Now Playing; `metadataTitle` is the combined display string.
    private(set) var tagTitle: String?
    private(set) var tagArtist: String?
    private(set) var tagAlbum: String?
    private(set) var audioTracks: [Track] = []
    private(set) var subtitleTracks: [Track] = []
    private(set) var selectedAudioTrack: Int32 = -1
    private(set) var selectedSubtitleTrack: Int32 = -1
    private(set) var rate: Float = 1
    private(set) var hud: HUDMessage?
    /// Bumped on every jump in position, so observers (Now Playing) can resync elapsed time.
    private(set) var seekGeneration = 0
    /// When false, playback stops at the end of the current item instead of moving on.
    private(set) var autoAdvance = true
    /// Name of the Chromecast libVLC is rendering to, if any.
    private(set) var castingTo: String?

    /// Set while AirPlay (AVPlayer) has taken over; transport commands go there instead of libVLC.
    @ObservationIgnored private weak var external: ExternalTransport?
    private var externalActive: Bool { external?.isActive == true }
    /// Playback is happening on another device, so the local window shows a placeholder.
    var isRemote: Bool { castingTo != nil || externalActive }

    /// 0...1 maps to libVLC's 0...100; values above 1 are a boost, capped at 1.5.
    var volume: Double = UserDefaults.standard.object(forKey: "volume") as? Double ?? 1 {
        didSet {
            volume = min(max(volume, 0), 1.5)
            mediaPlayer.audio?.volume = Int32((volume * 100).rounded())
            UserDefaults.standard.set(volume, forKey: "volume")
        }
    }

    var isMuted = false {
        didSet { mediaPlayer.audio?.isMuted = isMuted }
    }

    /// Set while the user drags the scrubber, so time updates from libVLC don't fight the drag.
    var scrubPosition: Double?

    var currentItem: MediaItem? { currentIndex.flatMap { queue.indices.contains($0) ? queue[$0] : nil } }
    var hasMedia: Bool { currentItem != nil }
    var isPlaying: Bool { status == .playing || status == .buffering || status == .opening }
    var hasVideo: Bool { videoSize.width > 0 && videoSize.height > 0 }
    var title: String { metadataTitle ?? currentItem?.displayName ?? "Tangelo" }
    var position: Double {
        if let scrubPosition { return scrubPosition }
        return duration > 0 ? min(elapsed / duration, 1) : 0
    }
    var hasNext: Bool { (currentIndex ?? -1) + 1 < queue.count }
    var hasPrevious: Bool { (currentIndex ?? 0) > 0 }

    @ObservationIgnored private let mediaPlayer = VLCMediaPlayer()
    @ObservationIgnored private var lastResumeSave = Date.distantPast
    @ObservationIgnored private var hudTask: Task<Void, Never>?

    override private init() {
        super.init()
        mediaPlayer.delegate = self
    }

    // MARK: - Video output

    func attach(_ view: VLCVideoView) {
        mediaPlayer.drawable = view
    }

    // MARK: - Queue

    func open(_ urls: [URL], replacing: Bool = true) {
        let items = urls.map(MediaItem.init)
        guard !items.isEmpty else { return }
        if replacing || queue.isEmpty {
            saveResumePoint()
            // Opening one episode of a series queues the rest of the season around it.
            if urls.count == 1, let series = EpisodeQueue.series(around: urls[0]) {
                queue = series.urls.map(MediaItem.init)
                play(at: series.index)
            } else {
                queue = items
                play(at: 0)
            }
        } else {
            queue.append(contentsOf: items)
        }
        urls.forEach { RecentItems.shared.note($0) }
    }

    func play(at index: Int) {
        guard queue.indices.contains(index) else { return }
        saveResumePoint()
        currentIndex = index
        resetItemState()

        let item = queue[index]
        let media = VLCMedia(url: item.url)
        media.delegate = self
        mediaPlayer.media = media
        media.parse(options: [.fetchLocal])
        let resume = ResumePoints.shared.position(for: item.url)

        if AirPlay.shared.prepare(item.url, startingAt: resume ?? 0) {
            status = .opening // AVPlayer is playing this on the AirPlay device
            return
        }
        mediaPlayer.play()
        applyAudioSettings()
        pendingResume = resume
    }

    func next() { if hasNext, let i = currentIndex { play(at: i + 1) } }
    func previous() {
        if elapsed > 3 { seek(to: 0) } else if hasPrevious, let i = currentIndex { play(at: i - 1) }
    }

    func remove(at offsets: IndexSet) {
        let removingCurrent = currentIndex.map(offsets.contains) ?? false
        let current = currentItem
        queue.remove(atOffsets: offsets)
        if removingCurrent {
            stop()
        } else if let current {
            currentIndex = queue.firstIndex(of: current)
        }
    }

    func move(from source: IndexSet, to destination: Int) {
        let current = currentItem
        queue.move(fromOffsets: source, toOffset: destination)
        if let current { currentIndex = queue.firstIndex(of: current) }
    }

    func stop() {
        saveResumePoint()
        AirPlay.shared.prepare(nil)
        mediaPlayer.stop()
        currentIndex = nil
        resetItemState()
        status = .idle
    }

    // MARK: - Transport

    func togglePlayPause() {
        guard hasMedia else { return }
        if let external, external.isActive {
            isPlaying ? external.pause() : external.play()
            return
        }
        switch status {
        case .playing, .buffering, .opening:
            pauseRequested = true
            mediaPlayer.pause()
            saveResumePoint()
        case .ended:
            pauseRequested = false
            seek(to: 0)
            mediaPlayer.play()
        default:
            pauseRequested = false
            mediaPlayer.play()
        }
    }

    func seek(to fraction: Double) {
        guard hasMedia else { return }
        let clamped = min(max(fraction, 0), 1)
        if let external, external.isActive {
            external.seek(to: clamped * duration)
        } else {
            mediaPlayer.position = Float(clamped)
        }
        elapsed = clamped * duration
        seekGeneration += 1
    }

    /// Absolute seek without HUD feedback, for gestures and remote commands that show their own.
    func seek(seconds: TimeInterval) {
        guard hasMedia, externalActive || mediaPlayer.isSeekable else { return }
        let target = min(max(seconds, 0), max(duration - 0.5, 0))
        if let external, external.isActive {
            external.seek(to: target)
        } else {
            mediaPlayer.time = VLCTime(int: Int32(target * 1000))
        }
        elapsed = target
        seekGeneration += 1
    }

    func play() { if hasMedia, !isPlaying { togglePlayPause() } }
    func pause() { if isPlaying { togglePlayPause() } }

    /// Remaining seconds before playback rolls into the next queued item, when that's about to happen.
    var upNextCountdown: TimeInterval? {
        guard autoAdvance, hasNext, hasVideo, duration >= 300, status == .playing || status == .paused else { return nil }
        let remaining = duration - elapsed
        return remaining <= 20 ? max(remaining, 0) : nil
    }

    func cancelUpNext() { autoAdvance = false }

    func skip(by seconds: Double) {
        guard hasMedia else { return }
        seek(seconds: elapsed + seconds)
        showHUD(seconds > 0 ? "goforward" : "gobackward", "\(seconds > 0 ? "+" : "−")\(Int(abs(seconds)))s")
    }

    func setRate(_ newRate: Float) {
        let clamped = min(max(newRate, 0.25), 4)
        mediaPlayer.rate = clamped
        external?.setRate(clamped)
        rate = clamped
        showHUD("speedometer", clamped == 1 ? "Normal speed" : String(format: "%.2g×", clamped))
    }

    func nudgeVolume(by delta: Double) {
        isMuted = false
        volume += delta
        showHUD(volumeSymbol, "\(Int((volume * 100).rounded()))%")
    }

    func toggleMute() {
        isMuted.toggle()
        showHUD(volumeSymbol, isMuted ? "Muted" : "\(Int((volume * 100).rounded()))%")
    }

    var volumeSymbol: String {
        if isMuted || volume == 0 { return "speaker.slash.fill" }
        if volume < 0.34 { return "speaker.wave.1.fill" }
        if volume < 0.67 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    // MARK: - Tracks

    func selectAudioTrack(_ id: Int32) {
        mediaPlayer.currentAudioTrackIndex = id
        selectedAudioTrack = id
    }

    func selectSubtitleTrack(_ id: Int32) {
        mediaPlayer.currentVideoSubTitleIndex = id
        selectedSubtitleTrack = id
    }

    func addSubtitleFile(_ url: URL) {
        mediaPlayer.addPlaybackSlave(url, type: .subtitle, enforce: true)
        showHUD("captions.bubble.fill", url.lastPathComponent)
    }

    // MARK: - Other devices

    /// Switches libVLC's output to a Chromecast (or back to this Mac with nil), continuing from the same spot.
    func setRenderer(_ item: VLCRendererItem?, name: String?) {
        castingTo = name
        guard hasMedia else {
            mediaPlayer.setRendererItem(item)
            return
        }
        // libVLC applies a renderer when playback starts, so restart at the current position.
        let resumeAt = elapsed
        mediaPlayer.stop()
        mediaPlayer.setRendererItem(item)
        mediaPlayer.play()
        applyAudioSettings()
        pendingSeek = resumeAt
        showHUD(item == nil ? "macbook" : "tv", name.map { "Casting to \($0)" } ?? "Playing on this Mac")
    }

    /// AirPlay took over: pause libVLC and let `transport` drive playback.
    func handOff(to transport: ExternalTransport) {
        external = transport
        pauseRequested = true
        mediaPlayer.pause()
        showHUD("airplayvideo", "Playing on AirPlay")
    }

    /// AirPlay ended: resume libVLC where the AirPlay device stopped.
    func takeBack(at seconds: TimeInterval, playing: Bool) {
        external = nil
        guard hasMedia else { return }
        if mediaPlayer.state == .stopped || mediaPlayer.state == .ended || mediaPlayer.state == .error {
            pendingSeek = seconds
            if playing { pauseRequested = false; mediaPlayer.play() }
        } else {
            mediaPlayer.time = VLCTime(int: Int32(seconds * 1000))
            if playing { pauseRequested = false; mediaPlayer.play() }
        }
        elapsed = seconds
        seekGeneration += 1
        status = playing ? .playing : .paused
        showHUD("macbook", "Playing on this Mac")
    }

    /// State reported by AirPlay while it's driving playback.
    func externalUpdate(elapsed: TimeInterval, duration: TimeInterval, playing: Bool) {
        self.elapsed = elapsed
        if duration > 0 { self.duration = duration }
        let newStatus: Status = playing ? .playing : .paused
        if status != newStatus { status = newStatus }
        if Date().timeIntervalSince(lastResumeSave) > 5 {
            lastResumeSave = Date()
            saveResumePoint()
        }
    }

    func externalReachedEnd() { reachedEnd() }

    // MARK: - HUD

    func showHUD(_ symbol: String, _ text: String) {
        hud = HUDMessage(symbol: symbol, text: text)
        hudTask?.cancel()
        hudTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            self?.hud = nil
        }
    }

    // MARK: - Private

    @ObservationIgnored private var pendingResume: Double?
    @ObservationIgnored private var pauseRequested = false
    /// Position to restore after a restart that isn't a resume (switching cast target).
    @ObservationIgnored private var pendingSeek: Double?

    private func resetItemState() {
        elapsed = 0
        duration = 0
        videoSize = .zero
        artwork = nil
        metadataTitle = nil
        tagTitle = nil
        tagArtist = nil
        tagAlbum = nil
        autoAdvance = true
        audioTracks = []
        subtitleTracks = []
        selectedAudioTrack = -1
        selectedSubtitleTrack = -1
        scrubPosition = nil
        pendingResume = nil
        pauseRequested = false
        if rate != 1 { mediaPlayer.rate = 1; rate = 1 }
    }

    private func applyAudioSettings() {
        mediaPlayer.audio?.volume = Int32((volume * 100).rounded())
        mediaPlayer.audio?.isMuted = isMuted
    }

    private func refreshTracks() {
        audioTracks = Self.tracks(names: mediaPlayer.audioTrackNames, ids: mediaPlayer.audioTrackIndexes)
        subtitleTracks = Self.tracks(names: mediaPlayer.videoSubTitlesNames, ids: mediaPlayer.videoSubTitlesIndexes)
        selectedAudioTrack = mediaPlayer.currentAudioTrackIndex
        selectedSubtitleTrack = mediaPlayer.currentVideoSubTitleIndex
    }

    private static func tracks(names: [Any], ids: [Any]) -> [Track] {
        zip(names, ids).compactMap { name, id in
            guard let name = name as? String, let id = (id as? NSNumber)?.int32Value else { return nil }
            return Track(id: id, name: name)
        }
    }

    private func refreshMetadata() {
        guard let media = mediaPlayer.media else { return }
        let length = Double(media.length.intValue) / 1000
        if length > 0 { duration = length }
        let meta = media.metaData
        tagTitle = meta.title?.isEmpty == false ? meta.title : nil
        tagArtist = meta.artist?.isEmpty == false ? meta.artist : nil
        tagAlbum = meta.album?.isEmpty == false ? meta.album : nil
        if let title = meta.title, !title.isEmpty, title != currentItem?.url.lastPathComponent {
            metadataTitle = [meta.artist, title].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " · ")
        }
        if artwork == nil, let image = meta.artwork { artwork = image }
    }

    private func saveResumePoint() {
        guard let item = currentItem, duration > 0 else { return }
        ResumePoints.shared.save(elapsed: elapsed, duration: duration, for: item.url)
    }
}

// MARK: - VLCKit delegates (delivered on the main thread by VLCKit)

extension Player: @preconcurrency VLCMediaPlayerDelegate {
    func mediaPlayerStateChanged(_ aNotification: Notification) {
        // While AirPlay drives playback, libVLC is parked and its state is irrelevant.
        guard !externalActive else { return }
        switch mediaPlayer.state {
        case .opening: status = .opening
        case .buffering: if status != .playing && status != .paused { status = .buffering }
        case .playing:
            status = .playing
            refreshTracks()
            refreshMetadata()
        case .paused:
            // At end of file VLCKit 3 pauses on the last frame instead of reporting .ended,
            // so a pause the user didn't ask for in the final moments means the item finished.
            if !pauseRequested, duration > 0, duration - Double(mediaPlayer.time.intValue) / 1000 < 1.5 {
                reachedEnd()
            } else {
                status = .paused
            }
        case .esAdded: refreshTracks()
        case .error: status = .failed
        case .ended:
            reachedEnd()
        case .stopped:
            // Some streams end with .stopped instead; stale stops from a previous item can't match
            // because play(at:) resets elapsed to zero.
            if duration > 0, duration - elapsed < 1.5 {
                reachedEnd()
            } else if status != .idle && status != .ended {
                status = .paused
            }
        @unknown default: break
        }
    }

    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        elapsed = Double(mediaPlayer.time.intValue) / 1000
        if duration == 0 { refreshMetadata() }

        let size = mediaPlayer.videoSize
        if size != videoSize { videoSize = size }

        if let seek = pendingSeek, duration > 0 {
            pendingSeek = nil
            mediaPlayer.time = VLCTime(int: Int32(seek * 1000))
            seekGeneration += 1
        }

        if let resume = pendingResume, duration > 0 {
            pendingResume = nil
            mediaPlayer.time = VLCTime(int: Int32(resume * 1000))
            seekGeneration += 1
            showHUD("clock.arrow.circlepath", "Resumed at \(Self.format(resume))")
        }

        if Date().timeIntervalSince(lastResumeSave) > 5 {
            lastResumeSave = Date()
            saveResumePoint()
        }
    }

    private func reachedEnd() {
        guard status != .ended else { return }
        if let item = currentItem { ResumePoints.shared.clear(for: item.url) }
        if hasNext && autoAdvance {
            // Changing media from inside a libVLC callback can deadlock; hop off it first.
            Task { @MainActor in self.next() }
        } else {
            status = .ended
            elapsed = duration
        }
    }

    static func format(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

extension Player: @preconcurrency VLCMediaDelegate {
    func mediaMetaDataDidChange(_ aMedia: VLCMedia) { refreshMetadata() }
    func mediaDidFinishParsing(_ aMedia: VLCMedia) { refreshMetadata() }
}

struct HUDMessage: Equatable {
    let id = UUID()
    let symbol: String
    let text: String
}
