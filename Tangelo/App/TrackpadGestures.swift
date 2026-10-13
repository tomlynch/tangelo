// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import AppKit

/// Two-finger horizontal swipe scrubs, vertical swipe changes volume, pinch toggles full screen.
/// A mouse wheel steps volume (vertical) or skips 5s (horizontal).
@MainActor
final class TrackpadGestures {
    static let shared = TrackpadGestures()

    private enum Axis { case horizontal, vertical }

    private var axis: Axis?
    private var pending = CGSize.zero
    private var scrubTarget: TimeInterval?
    private var lastLiveSeek = Date.distantPast
    private var magnification: CGFloat = 0
    private var pinchHandled = false

    private var player: Player { .shared }
    private var chrome: ChromeController { .shared }

    func install() {
        NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .magnify]) { event in
            nonisolated(unsafe) let event = event
            let handled = MainActor.assumeIsolated { self.handle(event) }
            return handled ? nil : event
        }
    }

    private func handle(_ event: NSEvent) -> Bool {
        guard let window = chrome.window, event.window == window, window.attachedSheet == nil,
              player.hasMedia, !chrome.pointerOverPanel else { return false }
        switch event.type {
        case .scrollWheel: return scroll(event)
        case .magnify: return pinch(event, in: window)
        default: return false
        }
    }

    // MARK: - Scroll

    private func scroll(_ event: NSEvent) -> Bool {
        // Momentum after lifting the fingers would keep scrubbing past where the user stopped.
        if !event.momentumPhase.isEmpty { return true }

        guard event.hasPreciseScrollingDeltas else {
            wheel(event)
            return true
        }

        if event.phase.contains(.began) || event.phase.contains(.mayBegin) {
            axis = nil
            pending = .zero
            scrubTarget = nil
        }

        // Normalize to finger direction: positive = fingers moved right / up, whatever the scroll direction setting.
        let inverted = event.isDirectionInvertedFromDevice
        let right = inverted ? event.scrollingDeltaX : -event.scrollingDeltaX
        let up = inverted ? -event.scrollingDeltaY : event.scrollingDeltaY

        if axis == nil {
            pending.width += right
            pending.height += up
            if max(abs(pending.width), abs(pending.height)) > 6 {
                axis = abs(pending.width) > abs(pending.height) ? .horizontal : .vertical
            }
        }

        switch axis {
        case .horizontal: scrub(by: right)
        case .vertical: changeVolume(by: up)
        case nil: break
        }

        if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            if let target = scrubTarget { player.seek(seconds: target) }
            player.scrubPosition = nil
            scrubTarget = nil
            axis = nil
        }
        chrome.poke()
        return true
    }

    private func scrub(by points: CGFloat) {
        guard player.duration > 0 else { return }
        // Longer media scrubs faster: a 4-minute clip moves ~0.15s per point, a 2-hour film ~2s.
        let secondsPerPoint = min(max(player.duration / 1500, 0.1), 2)
        let target = min(max((scrubTarget ?? player.elapsed) + points * secondsPerPoint, 0), player.duration)
        scrubTarget = target
        player.scrubPosition = target / player.duration
        player.showHUD(points >= 0 ? "forward.fill" : "backward.fill",
                       "\(Player.format(target)) / \(Player.format(player.duration))")
        if Date().timeIntervalSince(lastLiveSeek) > 0.12 {
            lastLiveSeek = Date()
            player.seek(seconds: target)
        }
    }

    private func changeVolume(by points: CGFloat) {
        player.isMuted = false
        player.volume += points * 0.004
        player.showHUD(player.volumeSymbol, "\(Int((player.volume * 100).rounded()))%")
    }

    private func wheel(_ event: NSEvent) {
        if abs(event.scrollingDeltaY) >= abs(event.scrollingDeltaX), event.scrollingDeltaY != 0 {
            player.nudgeVolume(by: event.scrollingDeltaY > 0 ? 0.05 : -0.05)
        } else if event.scrollingDeltaX != 0 {
            player.skip(by: event.scrollingDeltaX < 0 ? 5 : -5)
        }
        chrome.poke()
    }

    // MARK: - Pinch

    private func pinch(_ event: NSEvent, in window: NSWindow) -> Bool {
        if event.phase.contains(.began) {
            magnification = 0
            pinchHandled = false
        }
        magnification += event.magnification
        let fullScreen = window.styleMask.contains(.fullScreen)
        if !pinchHandled, (magnification > 0.25 && !fullScreen) || (magnification < -0.25 && fullScreen) {
            pinchHandled = true
            chrome.toggleFullScreen()
        }
        return true
    }
}
