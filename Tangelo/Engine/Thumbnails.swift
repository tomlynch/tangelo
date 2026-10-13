// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import AppKit
import CryptoKit
import VLCKit

/// Frame grabs for the Continue Watching shelf and Up Next card, cached in memory and on disk.
@MainActor
final class Thumbnails {
    static let shared = Thumbnails()

    private var memory: [String: NSImage] = [:]
    private var waiting: [String: [CheckedContinuation<NSImage?, Never>]] = [:]
    private var jobs: [String: ThumbnailJob] = [:]

    private let directory: URL = {
        let dir = URL.cachesDirectory.appending(path: "com.tomlynch.tangelo/thumbnails", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// A frame from `url` near `fraction` (0...1). Positions are bucketed so small progress changes reuse the cache.
    func thumbnail(for url: URL, at fraction: Double) async -> NSImage? {
        guard url.isFileURL else { return nil }
        let bucket = Int((min(max(fraction, 0), 1) * 40).rounded())
        let key = SHA256.hash(data: Data("\(url.absoluteString)#\(bucket)".utf8))
            .map { String(format: "%02x", $0) }.joined()

        if let image = memory[key] { return image }
        let file = directory.appending(path: "\(key).jpg")
        if let image = NSImage(contentsOf: file) {
            memory[key] = image
            return image
        }

        return await withCheckedContinuation { continuation in
            waiting[key, default: []].append(continuation)
            guard jobs[key] == nil else { return }

            jobs[key] = ThumbnailJob.start(url: url, at: Double(bucket) / 40, width: 480, saveTo: file) { [weak self] data in
                Task { @MainActor in self?.finish(key: key, data: data) }
            }
        }
    }

    private func finish(key: String, data: Data?) {
        jobs[key] = nil
        let image = data.flatMap(NSImage.init(data:))
        if let image { memory[key] = image }
        waiting.removeValue(forKey: key)?.forEach { $0.resume(returning: image) }
    }
}

/// One frame grab. Receives VLCKit's callback (possibly off the main thread), encodes the frame as JPEG,
/// optionally writes it to disk, and hands the data back. Keep the returned job alive until it completes.
final class ThumbnailJob: NSObject, VLCMediaThumbnailerDelegate, @unchecked Sendable {
    private let destination: URL?
    private let completion: @Sendable (Data?) -> Void
    private var thumbnailer: VLCMediaThumbnailer?

    private init(destination: URL?, completion: @escaping @Sendable (Data?) -> Void) {
        self.destination = destination
        self.completion = completion
    }

    @MainActor
    static func start(url: URL, at fraction: Double, width: CGFloat, saveTo destination: URL? = nil,
                      completion: @escaping @Sendable (Data?) -> Void) -> ThumbnailJob {
        let job = ThumbnailJob(destination: destination, completion: completion)
        let thumbnailer = VLCMediaThumbnailer(media: VLCMedia(url: url), andDelegate: job)
        thumbnailer.thumbnailWidth = width
        thumbnailer.thumbnailHeight = 0 // derived from the video's aspect ratio
        thumbnailer.snapshotPosition = Float(min(max(fraction, 0), 1))
        job.thumbnailer = thumbnailer
        thumbnailer.fetchThumbnail()
        return job
    }

    func mediaThumbnailer(_ mediaThumbnailer: VLCMediaThumbnailer, didFinishThumbnail thumbnail: CGImage) {
        let data = NSBitmapImageRep(cgImage: thumbnail).representation(using: .jpeg, properties: [.compressionFactor: 0.8])
        if let data, let destination { try? data.write(to: destination, options: .atomic) }
        completion(data)
    }

    func mediaThumbnailerDidTimeOut(_ mediaThumbnailer: VLCMediaThumbnailer) {
        completion(nil)
    }
}
