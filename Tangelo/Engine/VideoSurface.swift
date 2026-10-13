// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import SwiftUI
import VLCKit

/// Hosts libVLC's video output. Clicks pass through to SwiftUI so gestures layered above it work.
struct VideoSurface: NSViewRepresentable {
    @Environment(Player.self) private var player

    func makeNSView(context: Context) -> VLCVideoView {
        let view = PassthroughVideoView()
        view.backColor = .black
        view.fillScreen = false
        player.attach(view)
        return view
    }

    func updateNSView(_ nsView: VLCVideoView, context: Context) {}

    private final class PassthroughVideoView: VLCVideoView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override var mouseDownCanMoveWindow: Bool { true }
    }
}
