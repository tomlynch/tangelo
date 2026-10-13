// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import SwiftUI

struct WelcomeView: View {
    @Environment(Player.self) private var player
    @Environment(ChromeController.self) private var chrome
    private let recents = RecentItems.shared
    private let resume = ResumePoints.shared

    var body: some View {
        let shelf = resume.continueWatching
        let shelfURLs = Set(shelf.map(\.url))
        let otherRecents = recents.urls.filter { !shelfURLs.contains($0) }.prefix(shelf.isEmpty ? 5 : 3)
        let compact = !shelf.isEmpty

        ZStack {
            AmbientBackground()

            GeometryReader { geo in
                ScrollView(.vertical) {
                    VStack(spacing: compact ? 22 : 28) {
                        header(compact: compact)

                        if !shelf.isEmpty {
                            section("Continue Watching") {
                                ScrollView(.horizontal) {
                                    HStack(alignment: .top, spacing: 14) {
                                        ForEach(shelf, id: \.url) { item in
                                            ContinueCard(url: item.url, entry: item.entry)
                                        }
                                    }
                                    .padding(.horizontal, 2)
                                    .padding(.vertical, 4)
                                }
                                .scrollIndicators(.never)
                                .scrollClipDisabled()
                            }
                            .frame(maxWidth: 660)
                        }

                        if !otherRecents.isEmpty {
                            section("Recent") {
                                VStack(spacing: 2) {
                                    ForEach(Array(otherRecents), id: \.self) { url in
                                        RecentRow(url: url) { player.open([url]) }
                                    }
                                }
                                .padding(6)
                                .glassPanel(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .frame(maxWidth: compact ? 660 : 420)
                        }
                    }
                    .padding(32)
                    .padding(.leading, chrome.showingNetwork ? 332 : 0) // clear the network panel
                    .frame(maxWidth: .infinity, minHeight: geo.size.height)
                    .animation(.snappy, value: chrome.showingNetwork)
                }
                .scrollIndicators(.never)
            }
        }
    }

    private func header(compact: Bool) -> some View {
        VStack(spacing: compact ? 18 : 28) {
            VStack(spacing: compact ? 8 : 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: compact ? 60 : 88, height: compact ? 60 : 88)
                    .shadow(color: .black.opacity(0.4), radius: 18, y: 8)
                Text("Tangelo")
                    .font(.system(size: compact ? 24 : 30, weight: .bold, design: .rounded))
                if !compact {
                    Text("Drop a video or song anywhere in this window.")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            HStack(spacing: 10) {
                Button { OpenPanel.chooseMedia() } label: {
                    Label("Open File", systemImage: "folder")
                        .padding(.horizontal, 6)
                }
                .prominentGlassButton()
                .keyboardShortcut(.defaultAction)

                Button { chrome.showingOpenURL = true } label: {
                    Label("Open URL", systemImage: "link")
                        .padding(.horizontal, 6)
                }
                .glassButton()

                Button { withAnimation(.snappy) { chrome.showingNetwork.toggle() } } label: {
                    Label("Network", systemImage: "network")
                        .padding(.horizontal, 6)
                }
                .glassButton()
            }
            .controlSize(compact ? .regular : .large)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.45))
                .padding(.leading, 4)
            content()
        }
    }
}

private struct ContinueCard: View {
    @Environment(Player.self) private var player
    let url: URL
    let entry: ResumePoints.Entry
    @State private var thumbnail: NSImage?
    @State private var hovering = false

    private var remainingText: String {
        guard entry.remaining >= 60 else { return "Less than a minute left" }
        let units: Set<Duration.UnitsFormatStyle.Unit> = entry.remaining >= 3600 ? [.hours, .minutes] : [.minutes]
        return Duration.seconds(entry.remaining).formatted(.units(allowed: units, width: .abbreviated)) + " left"
    }

    var body: some View {
        Button { player.open([url]) } label: {
            VStack(alignment: .leading, spacing: 7) {
                ZStack(alignment: .bottom) {
                    ZStack {
                        if let thumbnail {
                            Image(nsImage: thumbnail).resizable().aspectRatio(contentMode: .fill)
                        } else {
                            LinearGradient(colors: [.white.opacity(0.1), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom)
                            Image(systemName: "film").font(.system(size: 22)).foregroundStyle(.white.opacity(0.35))
                        }
                    }
                    .frame(width: 200, height: 112.5)
                    .clipped()

                    LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 38))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.35))
                        .frame(maxHeight: .infinity)
                        .opacity(hovering ? 1 : 0)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.3))
                            Capsule().fill(.tint).frame(width: max(4, geo.size.width * entry.fraction))
                        }
                    }
                    .frame(height: 4)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 9)
                }
                .frame(width: 200, height: 112.5)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white.opacity(hovering ? 0.35 : 0.08)))
                .scaleEffect(hovering ? 1.03 : 1)
                .shadow(color: .black.opacity(hovering ? 0.4 : 0.2), radius: hovering ? 14 : 6, y: 6)

                VStack(alignment: .leading, spacing: 1) {
                    Text(MediaItem(url: url).displayName)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text(remainingText)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 2)
            }
            .frame(width: 200)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .contextMenu {
            Button("Play from Beginning") {
                ResumePoints.shared.clear(for: url)
                player.open([url])
            }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                .disabled(!url.isFileURL)
            Divider()
            Button("Remove from Continue Watching") {
                withAnimation(.snappy) { ResumePoints.shared.clear(for: url) }
            }
        }
        .task(id: Int(entry.fraction * 40)) {
            thumbnail = await Thumbnails.shared.thumbnail(for: url, at: entry.fraction)
        }
    }
}

private struct RecentRow: View {
    let url: URL
    let action: () -> Void
    @State private var hovering = false

    private var item: MediaItem { MediaItem(url: url) }

    private var symbol: String {
        guard url.isFileURL else { return "globe" }
        let audio = ["mp3", "m4a", "flac", "wav", "aac", "ogg", "opus", "aiff", "alac"]
        return audio.contains(url.pathExtension.lowercased()) ? "music.note" : "film"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 13))
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text(item.detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if let resume = ResumePoints.shared.position(for: url) {
                    Text("Resume \(Player.format(resume))")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.white.opacity(hovering ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// Slow-moving dark ember mesh gradient behind the welcome screen.
private struct AmbientBackground: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let t = Float(context.date.timeIntervalSinceReferenceDate)
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.5 + 0.12 * sin(t * 0.21), 0.5 + 0.1 * cos(t * 0.17)], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1],
                ],
                colors: [
                    Color(red: 0.06, green: 0.045, blue: 0.04), Color(red: 0.17, green: 0.075, blue: 0.04), Color(red: 0.05, green: 0.04, blue: 0.035),
                    Color(red: 0.11, green: 0.06, blue: 0.04), Color(red: 0.34, green: 0.13, blue: 0.04), Color(red: 0.12, green: 0.06, blue: 0.04),
                    Color(red: 0.035, green: 0.03, blue: 0.03), Color(red: 0.10, green: 0.05, blue: 0.035), Color(red: 0.03, green: 0.03, blue: 0.03),
                ]
            )
        }
        .ignoresSafeArea()
    }
}
