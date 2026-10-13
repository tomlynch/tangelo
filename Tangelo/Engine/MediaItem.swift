// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import AppKit
import Observation

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

struct MediaItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL

    init(url: URL) { self.url = url }

    var displayName: String {
        if url.isFileURL { return url.deletingPathExtension().lastPathComponent }
        return url.lastPathComponent.isEmpty ? (url.host() ?? url.absoluteString) : url.lastPathComponent
    }

    var detail: String {
        url.isFileURL ? url.deletingLastPathComponent().lastPathComponent : (url.host() ?? "Stream")
    }
}

/// Remembers where playback stopped so reopening a long file picks up where you left off,
/// and feeds the Continue Watching shelf.
@MainActor
@Observable
final class ResumePoints {
    static let shared = ResumePoints()

    struct Entry: Codable, Equatable {
        var elapsed: TimeInterval
        var duration: TimeInterval
        var updated: Date

        var fraction: Double { duration > 0 ? min(elapsed / duration, 1) : 0 }
        var remaining: TimeInterval { max(duration - elapsed, 0) }
    }

    private static let key = "resumePoints.v2"
    private static let minimumElapsed: TimeInterval = 30
    private static let minimumDuration: TimeInterval = 120
    private static let limit = 200

    private(set) var entries: [URL: Entry] = [:]

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let stored = try? JSONDecoder().decode([String: Entry].self, from: data) {
            entries = Dictionary(uniqueKeysWithValues: stored.compactMap { key, value in URL(string: key).map { ($0, value) } })
        }
        UserDefaults.standard.removeObject(forKey: "resumePoints") // v1 had no durations; nothing worth migrating
    }

    func position(for url: URL) -> TimeInterval? { entries[url]?.elapsed }

    /// Most recently watched unfinished local files that still exist.
    var continueWatching: [(url: URL, entry: Entry)] {
        entries
            .filter { !$0.key.isFileURL || FileManager.default.fileExists(atPath: $0.key.path) }
            .sorted { $0.value.updated > $1.value.updated }
            .prefix(10)
            .map { ($0.key, $0.value) }
    }

    func save(elapsed: TimeInterval, duration: TimeInterval, for url: URL) {
        let nearEnd = elapsed > duration * 0.95
        if duration < Self.minimumDuration || elapsed < Self.minimumElapsed || nearEnd {
            clear(for: url)
            return
        }
        entries[url] = Entry(elapsed: elapsed, duration: duration, updated: .now)
        if entries.count > Self.limit, let oldest = entries.min(by: { $0.value.updated < $1.value.updated })?.key {
            entries.removeValue(forKey: oldest)
        }
        persist()
    }

    func clear(for url: URL) {
        guard entries.removeValue(forKey: url) != nil else { return }
        persist()
    }

    private func persist() {
        let stored = Dictionary(uniqueKeysWithValues: entries.map { ($0.key.absoluteString, $0.value) })
        if let data = try? JSONEncoder().encode(stored) { UserDefaults.standard.set(data, forKey: Self.key) }
    }
}

@MainActor
@Observable
final class RecentItems {
    static let shared = RecentItems()
    private static let key = "recentURLs"
    private static let limit = 8

    private(set) var urls: [URL] = (UserDefaults.standard.stringArray(forKey: key) ?? []).compactMap(URL.init(string:))

    func note(_ url: URL) {
        urls.removeAll { $0 == url }
        urls.insert(url, at: 0)
        urls = Array(urls.prefix(Self.limit))
        UserDefaults.standard.set(urls.map(\.absoluteString), forKey: Self.key)
        if url.isFileURL { NSDocumentController.shared.noteNewRecentDocumentURL(url) }
    }

    func clear() {
        urls = []
        UserDefaults.standard.removeObject(forKey: Self.key)
    }
}
