// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import AppKit
import Observation
import SwiftUI

/// Owns everything about the window that isn't playback: auto-hiding controls,
/// sizing the window to the video, panels, and float-on-top.
@MainActor
@Observable
final class ChromeController {
    static let shared = ChromeController()

    private(set) var controlsVisible = true
    var showingPlaylist = false
    var showingOpenURL = false
    var showingNetwork = false
    var floatOnTop = false {
        didSet { window?.level = floatOnTop ? .floating : .normal }
    }

    /// Small floating always-on-top player snapped to a screen corner.
    private(set) var isMini = false

    @ObservationIgnored weak var window: NSWindow? {
        didSet { if window !== oldValue { observeWindow() } }
    }
    @ObservationIgnored private var savedFrame: NSRect?
    @ObservationIgnored private var pendingMini = false
    @ObservationIgnored private var windowObservers: [NSObjectProtocol] = []
    @ObservationIgnored private var snapTask: Task<Void, Never>?
    /// Scroll gestures leave side panels (playlist, network) alone so they scroll normally.
    @ObservationIgnored var pointerOverPanel = false
    @ObservationIgnored private var hideTask: Task<Void, Never>?
    @ObservationIgnored private var lastFittedSize: CGSize = .zero
    @ObservationIgnored private var lastPointer: CGPoint?

    private static let hideDelay: Duration = .milliseconds(2200)
    private static let exitHideDelay: Duration = .milliseconds(600)

    /// Feed pointer positions here. Hover callbacks also fire when content redraws under a
    /// stationary pointer, so only real movement counts as activity.
    func pointerMoved(to point: CGPoint) {
        defer { lastPointer = point }
        guard let last = lastPointer else { return poke() }
        if hypot(point.x - last.x, point.y - last.y) >= 2 { poke() }
    }

    /// Pointer left the window: hide sooner, since nobody is reaching for the controls.
    func pointerExited() {
        lastPointer = nil
        scheduleHide(after: Self.exitHideDelay)
    }

    /// Call on any user activity: shows controls and restarts the hide timer.
    func poke() {
        show()
        scheduleHide()
    }

    func show() {
        hideTask?.cancel()
        setVisible(true)
    }

    func scheduleHide(after delay: Duration = hideDelay) {
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled else { return }
            let player = Player.shared
            guard player.isPlaying, player.hasVideo, !player.isRemote else { return }
            // Don't pull the bar out from under an open menu or sheet; check again shortly.
            if RunLoop.main.currentMode == .eventTracking || window?.attachedSheet != nil {
                return scheduleHide(after: .seconds(1))
            }
            setVisible(false)
            if window?.isKeyWindow == true { NSCursor.setHiddenUntilMouseMoves(true) }
        }
    }

    private func setVisible(_ visible: Bool) {
        guard visible != controlsVisible else { return }
        withAnimation(.easeInOut(duration: visible ? 0.18 : 0.35)) { controlsVisible = visible }
        if let titlebar = window?.standardWindowButton(.closeButton)?.superview {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = visible ? 0.18 : 0.35
                titlebar.animator().alphaValue = visible ? 1 : 0
            }
        }
    }

    func toggleFullScreen() {
        window?.toggleFullScreen(nil)
    }

    /// Smallest comfortable size for the welcome screen and for low-resolution video.
    private static let comfortableWidth: CGFloat = 960
    private static let comfortableHeight: CGFloat = 600

    /// Sizes the window for a video: its aspect ratio, at least comfortable size (small videos scale up),
    /// at most 75% of the screen, staying centered where it was.
    func fitWindow(to videoSize: CGSize) {
        guard let window, !window.styleMask.contains(.fullScreen) else { return }
        if isMini {
            if videoSize.width > 0 { layoutMini(corner: nil) }
            return
        }
        guard videoSize.width > 0, videoSize.height > 0 else {
            lastFittedSize = .zero
            return
        }
        guard videoSize != lastFittedSize, let screen = window.screen ?? NSScreen.main else { return }
        lastFittedSize = videoSize

        let visible = screen.visibleFrame
        let aspect = videoSize.width / videoSize.height
        var width = max(videoSize.width, Self.comfortableWidth)
        width = min(width, visible.width * 0.75, visible.height * 0.75 * aspect)
        setContentSize(CGSize(width: width, height: width / aspect), on: window, in: visible)
        window.contentAspectRatio = videoSize
    }

    /// Called when playback ends and the welcome screen returns: unlock the aspect ratio and grow back
    /// to a comfortable size if a small video left the window tiny.
    func restoreWelcomeSize() {
        if isMini { exitMini() }
        guard let window, !window.styleMask.contains(.fullScreen) else { return }
        lastFittedSize = .zero
        window.resizeIncrements = NSSize(width: 1, height: 1) // clears contentAspectRatio
        let current = window.contentLayoutRect.size
        guard current.width < Self.comfortableWidth || current.height < Self.comfortableHeight,
              let screen = window.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = CGSize(width: min(max(current.width, Self.comfortableWidth), visible.width * 0.9),
                          height: min(max(current.height, Self.comfortableHeight), visible.height * 0.9))
        setContentSize(size, on: window, in: visible)
    }

    // MARK: - Mini player

    private static let miniWidth: CGFloat = 384
    private static let miniMargin: CGFloat = 16

    private enum Corner { case topLeft, topRight, bottomLeft, bottomRight }

    func toggleMini() { isMini ? exitMini() : enterMini() }

    func enterMini() {
        guard let window, Player.shared.hasMedia, !isMini else { return }
        if window.styleMask.contains(.fullScreen) {
            pendingMini = true // continues once the exit-full-screen animation finishes
            window.toggleFullScreen(nil)
            return
        }
        savedFrame = window.frame
        withAnimation(.snappy) {
            showingPlaylist = false
            isMini = true
        }
        window.level = .floating
        window.collectionBehavior.insert([.canJoinAllSpaces, .fullScreenAuxiliary])
        setTrafficLightsHidden(true)
        Task { @MainActor in
            // Give SwiftUI a moment to relax the window's minimum size before shrinking it.
            try? await Task.sleep(for: .milliseconds(60))
            self.layoutMini(corner: .bottomRight)
        }
    }

    func exitMini() {
        guard let window, isMini else { return }
        withAnimation(.snappy) { isMini = false }
        window.level = floatOnTop ? .floating : .normal
        window.collectionBehavior.remove([.canJoinAllSpaces, .fullScreenAuxiliary])
        setTrafficLightsHidden(false)
        if let savedFrame {
            let video = Player.shared.videoSize
            if video.width > 0 { window.contentAspectRatio = video }
            window.setFrame(savedFrame, display: true, animate: true)
        }
        savedFrame = nil
    }

    private func layoutMini(corner: Corner?) {
        guard let window, let screen = window.screen ?? NSScreen.main else { return }
        let video = Player.shared.videoSize
        let aspect = video.width > 0 && video.height > 0 ? video.width / video.height : 16 / 9
        let content = CGSize(width: Self.miniWidth, height: (Self.miniWidth / aspect).rounded())
        let visible = screen.visibleFrame
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: content))
        let m = Self.miniMargin
        switch corner ?? nearestCorner(to: window.frame, in: visible) {
        case .topLeft: frame.origin = NSPoint(x: visible.minX + m, y: visible.maxY - frame.height - m)
        case .topRight: frame.origin = NSPoint(x: visible.maxX - frame.width - m, y: visible.maxY - frame.height - m)
        case .bottomLeft: frame.origin = NSPoint(x: visible.minX + m, y: visible.minY + m)
        case .bottomRight: frame.origin = NSPoint(x: visible.maxX - frame.width - m, y: visible.minY + m)
        }
        window.contentAspectRatio = CGSize(width: aspect * 1000, height: 1000)
        guard frame != window.frame else { return }
        window.setFrame(frame, display: true, animate: true)
    }

    private func nearestCorner(to frame: NSRect, in visible: NSRect) -> Corner {
        switch (frame.midX < visible.midX, frame.midY < visible.midY) {
        case (true, true): .bottomLeft
        case (true, false): .topLeft
        case (false, true): .bottomRight
        case (false, false): .topRight
        }
    }

    private func setTrafficLightsHidden(_ hidden: Bool) {
        for kind in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window?.standardWindowButton(kind)?.isHidden = hidden
        }
    }

    private func observeWindow() {
        windowObservers.forEach(NotificationCenter.default.removeObserver)
        windowObservers = []
        guard let window else { return }
        let center = NotificationCenter.default
        windowObservers.append(center.addObserver(forName: NSWindow.didMoveNotification, object: window, queue: .main) { _ in
            MainActor.assumeIsolated { ChromeController.shared.windowMoved() }
        })
        windowObservers.append(center.addObserver(forName: NSWindow.didExitFullScreenNotification, object: window, queue: .main) { _ in
            MainActor.assumeIsolated {
                let chrome = ChromeController.shared
                if chrome.pendingMini { chrome.pendingMini = false; chrome.enterMini() }
            }
        })
    }

    /// After the user drags the mini player and lets go, glide it into the nearest corner.
    private func windowMoved() {
        guard isMini else { return }
        snapTask?.cancel()
        snapTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(220))
            guard let self, !Task.isCancelled, isMini, NSEvent.pressedMouseButtons == 0 else { return }
            layoutMini(corner: nil)
        }
    }

    private func setContentSize(_ size: CGSize, on window: NSWindow, in visible: NSRect) {
        let current = window.frame
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
        frame.origin = NSPoint(x: current.midX - frame.width / 2, y: current.midY - frame.height / 2)
        frame.origin.x = min(max(frame.origin.x, visible.minX), visible.maxX - frame.width)
        frame.origin.y = min(max(frame.origin.y, visible.minY), visible.maxY - frame.height)
        window.setFrame(frame, display: true, animate: window.isVisible)
    }
}

/// Grabs the hosting NSWindow and configures it for edge-to-edge video.
struct WindowAccessor: NSViewRepresentable {
    let configure: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = AccessorView()
        view.configure = configure
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class AccessorView: NSView {
        var configure: ((NSWindow) -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { configure?(window) }
        }
    }
}
