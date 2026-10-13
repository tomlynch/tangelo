// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import Foundation

/// Finds the other episodes of a show next to an opened file, so playback can roll into the next one.
/// Deliberately conservative: only files that look like numbered episodes of the same show are queued,
/// so opening a random video in Downloads doesn't queue the whole folder.
enum EpisodeQueue {
    static let videoExtensions: Set<String> = [
        "mkv", "mp4", "m4v", "mov", "avi", "webm", "wmv", "flv", "ts", "m2ts", "mpg", "mpeg", "ogv", "3gp",
    ]

    struct Episode {
        let url: URL
        let show: String
        let season: Int
        let number: Int
    }

    /// Returns the season's files in order and the index of `url` among them, or nil if `url` isn't an episode
    /// or has no siblings.
    static func series(around url: URL) -> (urls: [URL], index: Int)? {
        guard url.isFileURL, let opened = parse(url) else { return nil }
        let folder = url.deletingLastPathComponent()
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        ) else { return nil }

        let episodes = contents
            .filter { videoExtensions.contains($0.pathExtension.lowercased()) }
            .compactMap(parse)
            .filter { $0.show == opened.show }
            .sorted {
                ($0.season, $0.number) != ($1.season, $1.number)
                    ? ($0.season, $0.number) < ($1.season, $1.number)
                    : $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending
            }

        guard episodes.count > 1,
              let index = episodes.firstIndex(where: { $0.url.standardizedFileURL == url.standardizedFileURL })
        else { return nil }
        return (episodes.map(\.url), index)
    }

    // S01E02, s1.e2, S01 E02 · 1x02 · Episode 2, Ep.02, E02
    // Regex isn't Sendable, but these are never mutated after initialization.
    nonisolated(unsafe) private static let patterns: [(regex: Regex<AnyRegexOutput>, hasSeason: Bool)] = [
        (try! Regex(#"(?i)\bs(\d{1,2})[ ._-]?e(\d{1,3})"#), true),
        (try! Regex(#"(?i)\b(\d{1,2})x(\d{2,3})\b"#), true),
        (try! Regex(#"(?i)\b(?:episode|ep|e)[ ._-]?(\d{1,3})\b"#), false),
    ]

    static func parse(_ url: URL) -> Episode? {
        let name = url.deletingPathExtension().lastPathComponent
        for pattern in patterns {
            guard let match = name.firstMatch(of: pattern.regex) else { continue }
            let numbers = match.output.dropFirst().compactMap { $0.substring.flatMap { Int($0) } }
            let season = pattern.hasSeason ? numbers.first ?? 0 : 0
            guard let number = numbers.last else { continue }
            let prefix = name[..<match.range.lowerBound]
            let show = prefix.lowercased().filter { $0.isLetter || $0.isNumber }
            return Episode(url: url, show: show, season: season, number: number)
        }
        return nil
    }
}
