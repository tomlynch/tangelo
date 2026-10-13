// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import SwiftUI

/// Browses SMB shares and DLNA/UPnP media servers on the local network.
struct NetworkPanel: View {
    @Environment(Player.self) private var player
    @Environment(ChromeController.self) private var chrome
    private let browser = NetworkBrowser.shared

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)
            Group {
                if browser.path.isEmpty {
                    serverList
                } else {
                    folderContents
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(width: 320)
        .glassPanel(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onHover { chrome.pointerOverPanel = $0 }
        .onAppear { browser.setVisible(true) }
        .onDisappear {
            browser.setVisible(false)
            chrome.pointerOverPanel = false
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            if !browser.path.isEmpty {
                Button { browser.goBack(to: browser.path.count - 1) } label: {
                    Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(ChromeButtonStyle(size: 28))
                .help("Back")
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(browser.path.last?.name ?? "Network")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text(browser.path.count > 1 ? browser.path.dropLast().map(\.name).joined(separator: " › ") : subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Spacer()
            Button { withAnimation(.snappy) { chrome.showingNetwork = false } } label: {
                Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(ChromeButtonStyle(size: 28))
            .help("Close")
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var subtitle: String {
        if browser.path.count == 1 { return browser.path[0].kind == .mediaServer ? "Media server" : "Shared folders" }
        return "Shares and media servers nearby"
    }

    private var serverList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                section("Shared Folders", nodes: browser.shares, symbol: "externaldrive.connected.to.line.below")
                section("Media Servers", nodes: browser.mediaServers, symbol: "server.rack")
            }
            .padding(10)
        }
        .scrollIndicators(.never)
    }

    @ViewBuilder
    private func section(_ title: String, nodes: [NetworkBrowser.Node], symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.45))
                .padding(.horizontal, 6)
                .padding(.bottom, 4)
            if nodes.isEmpty {
                HStack(spacing: 8) {
                    if browser.searching { ProgressView().controlSize(.small) }
                    Text(browser.searching ? "Searching…" : "None found")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
            ForEach(nodes) { node in
                NodeRow(node: node, symbol: symbol) { browser.open(node) }
            }
        }
    }

    private var folderContents: some View {
        ZStack {
            if browser.children.isEmpty {
                if browser.loading {
                    ProgressView().controlSize(.regular)
                } else if browser.failed {
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle").font(.system(size: 24)).foregroundStyle(.yellow)
                        Text("Couldn’t open this location").font(.system(size: 13, weight: .medium))
                        Button("Try Again") { browser.retry() }.glassButton()
                    }
                } else {
                    Text("This folder is empty").font(.system(size: 13)).foregroundStyle(.white.opacity(0.5))
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(browser.children) { node in
                            NodeRow(node: node, symbol: Self.symbol(for: node)) {
                                node.isContainer ? browser.open(node) : play(node)
                            }
                        }
                    }
                    .padding(10)
                }
                .scrollIndicators(.never)
            }
        }
    }

    /// Plays the chosen file with the rest of the folder's files queued after it.
    private func play(_ node: NetworkBrowser.Node) {
        let files = browser.playableFiles
        guard let index = files.firstIndex(of: node) else { return }
        player.open(Array(files[index...]).map(\.url))
        withAnimation(.snappy) { chrome.showingNetwork = false }
    }

    private static func symbol(for node: NetworkBrowser.Node) -> String {
        if node.isContainer { return "folder.fill" }
        let audio: Set<String> = ["mp3", "m4a", "flac", "wav", "aac", "ogg", "opus", "aiff", "alac", "wma"]
        return audio.contains(node.url.pathExtension.lowercased()) ? "music.note" : "film"
    }
}

private struct NodeRow: View {
    let node: NetworkBrowser.Node
    let symbol: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 13))
                    .foregroundStyle(node.isContainer ? AnyShapeStyle(.tint) : AnyShapeStyle(.white.opacity(0.75)))
                    .frame(width: 22)
                Text(node.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Spacer(minLength: 4)
                if node.isContainer {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .background(.white.opacity(hovering ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
