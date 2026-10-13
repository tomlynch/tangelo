// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import Foundation
import Observation
import VLCKit

/// Finds SMB shares (Bonjour and Windows network discovery) and DLNA/UPnP media servers, and browses them.
/// libVLC's list callbacks don't promise a thread, so while the browser is visible it polls once a second.
@MainActor
@Observable
final class NetworkBrowser {
    static let shared = NetworkBrowser()

    struct Node: Identifiable, Hashable {
        enum Kind { case share, mediaServer, folder, file }
        let id: String
        let name: String
        let url: URL
        let kind: Kind

        var isContainer: Bool { kind != .file }
    }

    private(set) var shares: [Node] = []
    private(set) var mediaServers: [Node] = []
    private(set) var path: [Node] = []
    private(set) var children: [Node] = []
    private(set) var loading = false
    private(set) var failed = false
    private(set) var searching = false

    @ObservationIgnored private var discoverers: [(name: String, discoverer: VLCMediaDiscoverer)] = []
    @ObservationIgnored private var current: VLCMedia?
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var visibleCount = 0

    /// Call when a browsing UI appears/disappears. Discovery keeps running once started; polling stops when hidden.
    func setVisible(_ visible: Bool) {
        visibleCount = max(visibleCount + (visible ? 1 : -1), 0)
        if visibleCount > 0 { start() } else { pollTask?.cancel(); pollTask = nil }
    }

    func open(_ node: Node) {
        guard node.isContainer else { return }
        path.append(node)
        load(node)
    }

    /// Pops back to `depth` levels (0 = the server list).
    func goBack(to depth: Int) {
        guard depth < path.count else { return }
        path.removeLast(path.count - depth)
        if let last = path.last { load(last) } else { current = nil; children = []; loading = false; failed = false }
    }

    func retry() { if let last = path.last { load(last) } }

    /// Playable files in the folder currently shown.
    var playableFiles: [Node] { children.filter { $0.kind == .file } }

    // MARK: - Private

    private func start() {
        if discoverers.isEmpty {
            for name in ["Bonjour", "dsm", "upnp"] {
                let discoverer = VLCMediaDiscoverer(name: name)
                discoverer.start()
                discoverers.append((name, discoverer))
            }
            searching = true
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(8))
                self?.searching = false
            }
        }
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.poll()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func load(_ node: Node) {
        let media = VLCMedia(url: node.url)
        current = media
        children = []
        failed = false
        loading = true
        media.parse(options: [.parseNetwork], timeout: 15_000)
        poll()
    }

    private func poll() {
        var smb: [Node] = []
        var dlna: [Node] = []
        for (name, discoverer) in discoverers {
            for media in Self.items(of: discoverer.discoveredMedia) {
                guard let node = Self.node(for: media, kind: name == "upnp" ? .mediaServer : .share) else { continue }
                if name == "upnp" { dlna.append(node) } else { smb.append(node) }
            }
        }
        // Bonjour and Windows discovery often find the same machine; keep one entry per name.
        var seen = Set<String>()
        smb = smb.filter { seen.insert($0.name.lowercased()).inserted }
        seen = []
        dlna = dlna.filter { seen.insert($0.id).inserted }
        let byName: (Node, Node) -> Bool = { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        if smb.sorted(by: byName) != shares { shares = smb.sorted(by: byName) }
        if dlna.sorted(by: byName) != mediaServers { mediaServers = dlna.sorted(by: byName) }

        guard let current else { return }
        let found = Self.items(of: current.subitems).compactMap { media -> Node? in
            Self.node(for: media, kind: media.mediaType == .directory ? .folder : .file)
        }
        .sorted { a, b in
            a.isContainer != b.isContainer ? a.isContainer : a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
        if found != children { children = found }

        switch current.parsedStatus {
        case .done:
            loading = false
        case .failed, .timeout:
            loading = false
            failed = children.isEmpty
        default:
            break
        }
    }

    private static func items(of list: VLCMediaList?) -> [VLCMedia] {
        guard let list else { return [] }
        list.lock()
        defer { list.unlock() }
        return (0..<max(list.count, 0)).compactMap { list.media(at: UInt($0)) }
    }

    private static func node(for media: VLCMedia, kind: Node.Kind) -> Node? {
        guard let url = media.url else { return nil }
        let raw = media.metaData.title ?? url.lastPathComponent
        let name = kind == .mediaServer ? cleanServerName(raw) : raw
        guard !name.isEmpty else { return nil }
        return Node(id: url.absoluteString, name: name, url: url, kind: kind)
    }

    /// UPnP servers often announce themselves as "10.0.0.20 - Living Room - uuid:…"; keep the human part.
    private static func cleanServerName(_ name: String) -> String {
        var parts = name.components(separatedBy: " - ")
        if parts.count > 1, parts[0].allSatisfy({ $0.isNumber || $0 == "." }) { parts.removeFirst() }
        if parts.count > 1, let last = parts.last, last.hasPrefix("RINCON_") || last.hasPrefix("uuid:") { parts.removeLast() }
        return parts.joined(separator: " - ")
    }
}
