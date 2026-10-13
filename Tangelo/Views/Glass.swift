// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import SwiftUI

extension View {
    /// Liquid Glass on macOS 26+, a translucent material on macOS 15.
    func glassPanel<S: Shape>(in shape: S) -> some View {
        modifier(GlassPanel(shape: shape))
    }

    @ViewBuilder
    func prominentGlassButton() -> some View {
        if #available(macOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }

    /// Borderless icon menu matching `ChromeButtonStyle`.
    func chromeMenu() -> some View {
        menuStyle(.button)
            .buttonStyle(ChromeButtonStyle())
            .menuIndicator(.hidden)
            .fixedSize()
    }

    @ViewBuilder
    func glassButton() -> some View {
        if #available(macOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }
}

private struct GlassPanel<S: Shape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular.tint(.black.opacity(0.36)), in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(.white.opacity(0.1), lineWidth: 1))
        }
    }
}

/// Round, borderless icon button with a soft hover highlight, used across the control bar.
struct ChromeButtonStyle: ButtonStyle {
    var size: CGFloat = 32

    func makeBody(configuration: Configuration) -> some View {
        HoverHighlight(size: size, pressed: configuration.isPressed) { configuration.label }
    }
}

private struct HoverHighlight<Label: View>: View {
    let size: CGFloat
    let pressed: Bool
    @ViewBuilder let label: Label
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        label
            .foregroundStyle(.white.opacity(isEnabled ? (hovering ? 1 : 0.88) : 0.35))
            .frame(width: size, height: size)
            .background(Circle().fill(.white.opacity(pressed ? 0.22 : hovering && isEnabled ? 0.12 : 0)))
            .scaleEffect(pressed ? 0.92 : 1)
            .contentShape(Circle())
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}
