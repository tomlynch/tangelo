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
