// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import SwiftUI

struct ControlBar: View {
    @Environment(Player.self) private var player
    @Environment(ChromeController.self) private var chrome
    @AppStorage("showRemainingTime") private var showRemaining = true

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                volumeCluster
                    .frame(width: 212, alignment: .leading)
                Spacer(minLength: 8)
                transportCluster
                Spacer(minLength: 8)
                optionsCluster
                    .frame(width: 212, alignment: .trailing)
            }

            HStack(spacing: 12) {
                Text(Player.format(player.position * player.duration))
                    .frame(minWidth: 44, alignment: .trailing)
                SlimSlider(
                    value: player.position,
                    onDrag: { player.scrubPosition = $0; chrome.poke() },
                    onCommit: { player.seek(to: $0) },
                    tooltip: { Player.format($0 * player.duration) },
                    preview: { SeekPreviews.shared.image(near: $0) },
                    onHover: { if let value = $0 { SeekPreviews.shared.request(near: value) } }
                )
                .disabled(player.duration == 0)
                Button {
                    showRemaining.toggle()
                } label: {
                    Text(showRemaining
                         ? "−" + Player.format(max(player.duration - player.position * player.duration, 0))
                         : Player.format(player.duration))
                        .frame(minWidth: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                .help(showRemaining ? "Show total duration" : "Show remaining time")
            }
            .font(.system(size: 11.5, weight: .medium).monospacedDigit())
            .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .frame(maxWidth: 720)
        .glassPanel(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var transportCluster: some View {
        HStack(spacing: 6) {
            Button { player.previous() } label: {
                Image(systemName: "backward.end.fill").font(.system(size: 13))
            }
            .buttonStyle(ChromeButtonStyle())
            .opacity(player.queue.count > 1 ? 1 : 0)
            .help("Previous")

            Button { player.skip(by: -10) } label: {
                Image(systemName: "gobackward.10").font(.system(size: 17, weight: .medium))
            }
            .buttonStyle(ChromeButtonStyle(size: 36))
            .help("Back 10 seconds")

            Button { player.togglePlayPause() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 24))
                    .contentTransition(.symbolEffect(.replace.downUp))
            }
            .buttonStyle(ChromeButtonStyle(size: 46))
            .help(player.isPlaying ? "Pause" : "Play")

            Button { player.skip(by: 10) } label: {
                Image(systemName: "goforward.10").font(.system(size: 17, weight: .medium))
            }
            .buttonStyle(ChromeButtonStyle(size: 36))
            .help("Forward 10 seconds")

            Button { player.next() } label: {
                Image(systemName: "forward.end.fill").font(.system(size: 13))
            }
            .buttonStyle(ChromeButtonStyle())
            .opacity(player.queue.count > 1 ? 1 : 0)
            .disabled(!player.hasNext)
            .help("Next")
        }
    }

    private var volumeCluster: some View {
        HStack(spacing: 4) {
            Button { player.toggleMute() } label: {
                Image(systemName: player.volumeSymbol)
                    .font(.system(size: 13))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 20)
            }
            .buttonStyle(ChromeButtonStyle())
            .help(player.isMuted ? "Unmute" : "Mute")

            SlimSlider(
                value: player.isMuted ? 0 : player.volume,
                onDrag: { if let v = $0 { player.isMuted = false; player.volume = v }; chrome.poke() }
            )
            .frame(width: 84)
        }
    }

    private var optionsCluster: some View {
        HStack(spacing: 2) {
            Menu {
                ForEach([0.5, 0.75, 1, 1.25, 1.5, 2] as [Float], id: \.self) { rate in
                    Toggle(rate == 1 ? "Normal" : String(format: "%.2g×", rate),
                           isOn: Binding(get: { player.rate == rate }, set: { _ in player.setRate(rate) }))
                }
            } label: {
                Text(player.rate == 1 ? "1×" : String(format: "%.2g×", player.rate))
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
            }
            .chromeMenu()
            .help("Playback speed")

            Menu {
                if !player.audioTracks.isEmpty {
                    Section("Audio") {
                        Picker("Audio", selection: Binding(get: { player.selectedAudioTrack }, set: player.selectAudioTrack)) {
                            ForEach(player.audioTracks) { Text($0.name).tag($0.id) }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                }
                Section("Subtitles") {
                    if !player.subtitleTracks.isEmpty {
                        Picker("Subtitles", selection: Binding(get: { player.selectedSubtitleTrack }, set: player.selectSubtitleTrack)) {
                            ForEach(player.subtitleTracks) { Text($0.name).tag($0.id) }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                    Button("Add Subtitle File…") { OpenPanel.chooseSubtitles() }
                }
            } label: {
                Image(systemName: player.selectedSubtitleTrack >= 0 ? "captions.bubble.fill" : "captions.bubble")
                    .font(.system(size: 14))
            }
            .chromeMenu()
            .help("Audio and subtitles")

            PlayOnButton()

            Button {
                withAnimation(.snappy) { chrome.showingPlaylist.toggle() }
            } label: {
                Image(systemName: "list.bullet").font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(ChromeButtonStyle())
            .help("Playlist")

            Button { chrome.enterMini() } label: {
                Image(systemName: "pip.enter").font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(ChromeButtonStyle())
            .help("Mini Player")

            Button { chrome.toggleFullScreen() } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(ChromeButtonStyle())
            .help("Full Screen")
        }
    }
}

private extension View {
    func chromeMenu() -> some View {
        menuStyle(.button)
            .buttonStyle(ChromeButtonStyle())
            .menuIndicator(.hidden)
            .fixedSize()
    }
}
