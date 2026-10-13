// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import SwiftUI

struct PlayerWindow: View {
    @Environment(Player.self) private var player
    @Environment(ChromeController.self) private var chrome
    @State private var dropTargeted = false

    var body: some View {
        @Bindable var chrome = chrome

        ZStack {
            Color.black

            VideoSurface()
                .opacity(player.hasVideo && !player.isRemote ? 1 : 0)

            if player.hasMedia {
                if player.isRemote {
                    RemotePlaybackView()
                        .transition(.opacity)
                } else if !player.hasVideo && player.status != .opening {
                    NowPlayingView()
                        .transition(.opacity)
                }
                clickLayer
                if !player.isRemote, player.status == .opening || (player.status == .buffering && !player.hasStartedPlayback) {
                    ProgressView().controlSize(chrome.isMini ? .regular : .large).tint(.white)
                }
                if player.status == .failed && !chrome.isMini {
                    FailureCard()
                }
            } else {
                WelcomeView()
                    .transition(.opacity)
            }
        }
        .overlay {
            if chrome.isMini && player.hasMedia {
                MiniPlayerOverlay()
                    .opacity(chrome.controlsVisible ? 1 : 0)
                    .allowsHitTesting(chrome.controlsVisible)
            }
        }
        .overlay(alignment: .top) {
            if player.hasMedia && !chrome.isMini {
                TitleBar()
                    .opacity(chrome.controlsVisible ? 1 : 0)
            }
        }
        .overlay(alignment: .top) {
            if let hud = player.hud, !chrome.isMini {
                HUDView(message: hud)
                    .padding(.top, 52)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    .id(hud.id)
            }
        }
        .overlay(alignment: .bottom) {
            if player.hasMedia && !chrome.isMini {
                ControlBar()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
                    .opacity(chrome.controlsVisible ? 1 : 0)
                    .offset(y: chrome.controlsVisible ? 0 : 12)
                    .allowsHitTesting(chrome.controlsVisible)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !chrome.isMini, player.showsUpNext, let next = player.queue[safe: (player.currentIndex ?? 0) + 1] {
                UpNextCard(next: next)
                    .padding(.trailing, 20)
                    .padding(.bottom, chrome.controlsVisible ? 128 : 24)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .overlay(alignment: .trailing) {
            if chrome.showingPlaylist && !chrome.isMini {
                PlaylistPanel()
                    .padding(.top, 44)
                    .padding(.trailing, 12)
                    .padding(.bottom, player.hasMedia ? 118 : 12)
                    .opacity(chrome.controlsVisible ? 1 : 0)
                    .allowsHitTesting(chrome.controlsVisible)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .overlay(alignment: .leading) {
            if chrome.showingNetwork && !chrome.isMini {
                NetworkPanel()
                    .padding(.top, 44)
                    .padding(.leading, 12)
                    .padding(.bottom, player.hasMedia ? 118 : 12)
                    .opacity(chrome.controlsVisible || !player.hasMedia ? 1 : 0)
                    .allowsHitTesting(chrome.controlsVisible || !player.hasMedia)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2.5, dash: [9, 7]))
                    .foregroundStyle(.white.opacity(0.7))
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(10)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeOut(duration: 0.2), value: player.hud)
        .animation(.snappy, value: player.showsUpNext)
        .animation(.easeInOut(duration: 0.3), value: chrome.controlsVisible)
        .animation(.easeOut(duration: 0.25), value: player.hasMedia)
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .navigationTitle(player.title)
        .onContinuousHover { phase in
            switch phase {
            case .active(let point): chrome.pointerMoved(to: point)
            case .ended: chrome.pointerExited()
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            player.open(urls, replacing: !chrome.showingPlaylist || !player.hasMedia)
            return true
        } isTargeted: { dropTargeted = $0 }
        .onChange(of: player.videoSize) { _, size in chrome.fitWindow(to: size) }
        .onChange(of: player.hasMedia) { _, hasMedia in if !hasMedia { chrome.restoreWelcomeSize() } }
        .onChange(of: player.status) { chrome.poke() }
        .onChange(of: player.hasVideo && !player.isRemote ? player.currentItem?.url : nil, initial: true) { _, url in
            SeekPreviews.shared.prepare(for: url)
        }
        .sheet(isPresented: $chrome.showingOpenURL) { OpenURLSheet() }
        .background(WindowAccessor { window in
            chrome.window = window
            window.backgroundColor = .black
            window.isMovableByWindowBackground = true
            window.tabbingMode = .disallowed
            window.collectionBehavior.insert(.fullScreenPrimary)
            // macOS restores the saved frame after this runs, so check the size once the window is on screen.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(150))
                if !player.hasMedia { chrome.restoreWelcomeSize() }
            }
        })
    }

    /// Click toggles play/pause, double-click toggles full screen (or leaves the mini player).
    /// Dragging moves the window, which matters most for the mini player.
    private var clickLayer: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(WindowDragGesture())
            .simultaneousGesture(
                TapGesture(count: 2).onEnded { chrome.isMini ? chrome.exitMini() : chrome.toggleFullScreen() }
                    .exclusively(before: TapGesture().onEnded {
                        // Status updates arrive from libVLC a moment later, so label by the state we're leaving.
                        let wasPlaying = player.isPlaying
                        player.togglePlayPause()
                        player.showHUD(wasPlaying ? "pause.fill" : "play.fill", wasPlaying ? "Paused" : "Play")
                    })
            )
    }
}

private struct TitleBar: View {
    @Environment(Player.self) private var player

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [.black.opacity(0.6), .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 80)
                .allowsHitTesting(false)
            Text(player.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .padding(.horizontal, 90)
                .padding(.top, 8)
                .allowsHitTesting(false)
        }
    }
}

private struct HUDView: View {
    let message: HUDMessage

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: message.symbol)
                .font(.system(size: 14, weight: .semibold))
            Text(message.text)
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassPanel(in: Capsule())
        .allowsHitTesting(false)
    }
}

private struct FailureCard: View {
    @Environment(Player.self) private var player

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.yellow)
            Text("Couldn’t play this media")
                .font(.headline)
            Text(player.currentItem?.url.isFileURL == true
                 ? "The file may be damaged or in a format that isn’t supported."
                 : "The stream couldn’t be opened. Check the address and your connection.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            HStack {
                Button("Open Another…") { OpenPanel.chooseMedia() }
                if player.hasNext { Button("Skip") { player.next() } }
            }
            .glassButton()
            .padding(.top, 4)
        }
        .padding(24)
        .glassPanel(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
