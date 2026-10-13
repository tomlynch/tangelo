// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import SwiftUI

/// A thin track that thickens on hover, used for both the seek bar and the volume slider.
struct SlimSlider: View {
    /// Current value, 0...1.
    let value: Double
    /// Upper bound for display (volume can boost past 1).
    var maximum: Double = 1
    /// Called continuously while dragging with the new value; nil when the drag ends.
    let onDrag: (Double?) -> Void
    /// Called once when the drag ends.
    var onCommit: (Double) -> Void = { _ in }
    /// Optional text shown in a bubble above the pointer while hovering.
    var tooltip: ((Double) -> String)?
    /// Optional frame shown above the tooltip while hovering (seek previews).
    var preview: ((Double) -> NSImage?)?
    /// Reports the hovered value (nil when the pointer leaves), so previews can be prioritized.
    var onHover: ((Double?) -> Void)?

    @State private var hoverX: CGFloat?
    @State private var dragging = false

    private var active: Bool { hoverX != nil || dragging }

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let fraction = min(max(value / maximum, 0), 1)
            let trackHeight: CGFloat = active ? 6 : 4

            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.2))
                if let hoverX, tooltip != nil {
                    Capsule().fill(.white.opacity(0.18))
                        .frame(width: min(max(hoverX, 0), width))
                }
                Capsule().fill(.white)
                    .frame(width: max(trackHeight, width * fraction))
            }
            .frame(height: trackHeight)
            .overlay(alignment: .leading) {
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                    .frame(width: 13, height: 13)
                    .offset(x: width * fraction - 6.5)
                    .opacity(active ? 1 : 0)
                    .scaleEffect(dragging ? 1.15 : 1)
            }
            .overlay(alignment: .bottomLeading) {
                if let hoverX, let tooltip {
                    let value = Double(min(max(hoverX, 0), width) / width) * maximum
                    HoverBubble(x: hoverX, trackWidth: width, text: tooltip(value), image: preview?(value))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let point):
                    hoverX = point.x
                    onHover?(Double(min(max(point.x / width, 0), 1)) * maximum)
                case .ended:
                    hoverX = nil
                    onHover?(nil)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        dragging = true
                        hoverX = drag.location.x
                        onDrag(Double(min(max(drag.location.x / width, 0), 1)) * maximum)
                    }
                    .onEnded { drag in
                        dragging = false
                        let final = Double(min(max(drag.location.x / width, 0), 1)) * maximum
                        onCommit(final)
                        onDrag(nil)
                    }
            )
            .animation(.easeOut(duration: 0.15), value: active)
        }
        .frame(height: 20)
    }
}

/// The tooltip (and optional preview frame) above a slider, centered on `x` and kept within the track.
/// Laid out on a zero-width anchor that's offset to the pointer, so the bubble's own width never shifts it.
struct HoverBubble: View {
    let x: CGFloat
    let trackWidth: CGFloat
    let text: String
    let image: NSImage?

    private static let previewWidth: CGFloat = 176

    var body: some View {
        // Keep a wide preview from hanging past the ends of the bar.
        let half = image == nil ? 0 : Self.previewWidth / 2
        let center = min(max(x, half), max(trackWidth - half, half))

        VStack(spacing: 5) {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Self.previewWidth)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.white.opacity(0.35), lineWidth: 1))
                    .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
            }
            Text(text)
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.black.opacity(0.75), in: Capsule())
        }
        .fixedSize()
        .frame(width: 0, height: 0, alignment: .bottom)
        .offset(x: center, y: -16)
        .allowsHitTesting(false)
    }
}
