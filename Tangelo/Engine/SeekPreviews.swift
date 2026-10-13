// Copyright (c) 2026 Tom Lynch
// SPDX-License-Identifier: MIT

import AppKit
import Observation

/// Frames for the seek-bar hover preview. Generated in the background for local video, coarse to fine
/// (every 10%, then 5%, then the rest) so a usable preview exists within seconds. Hovering a spot
/// jumps it to the front of the queue.
@MainActor
@Observable
final class SeekPreviews {
    static let shared = SeekPreviews()

    private static let slots = 60
    private static let concurrency = 2

    private(set) var frames: [Int: NSImage] = [:]

    @ObservationIgnored private var url: URL?
    @ObservationIgnored private var queue: [Int] = []
    @ObservationIgnored private var jobs: [Int: ThumbnailJob] = [:]
    @ObservationIgnored private var generation = 0

    /// Starts generating previews for `url`, or clears them when nil or not a local file.
    func prepare(for url: URL?) {
        guard url != self.url else { return }
        generation += 1
        self.url = nil
        frames = [:]
        queue = []
        jobs = [:]
        guard let url, url.isFileURL else { return }
        self.url = url

        var order: [Int] = []
        for step in [Self.slots / 10, Self.slots / 20, 1] {
            for slot in stride(from: 0, to: Self.slots, by: max(step, 1)) where !order.contains(slot) {
                order.append(slot)
            }
        }
        queue = order
        pump()
    }

    /// Moves the slot under the pointer to the front of the queue.
    func request(near fraction: Double) {
        let slot = Self.slot(for: fraction)
        guard frames[slot] == nil, jobs[slot] == nil, let index = queue.firstIndex(of: slot) else { return }
        queue.remove(at: index)
        queue.insert(slot, at: 0)
        pump()
    }

    /// The closest generated frame to `fraction`, if any are ready yet.
    func image(near fraction: Double) -> NSImage? {
        let target = Self.slot(for: fraction)
        if let exact = frames[target] { return exact }
        return frames.min { abs($0.key - target) < abs($1.key - target) }?.value
    }

    private static func slot(for fraction: Double) -> Int {
        min(max(Int(fraction * Double(slots)), 0), slots - 1)
    }

    private func pump() {
        guard let url else { return }
        while jobs.count < Self.concurrency, !queue.isEmpty {
            let slot = queue.removeFirst()
            let generation = generation
            let fraction = (Double(slot) + 0.5) / Double(Self.slots)
            jobs[slot] = ThumbnailJob.start(url: url, at: fraction, width: 320) { [weak self] data in
                Task { @MainActor in self?.finish(slot: slot, generation: generation, data: data) }
            }
        }
    }

    private func finish(slot: Int, generation: Int, data: Data?) {
        guard generation == self.generation else { return }
        jobs[slot] = nil
        if let image = data.flatMap(NSImage.init(data:)) { frames[slot] = image }
        pump()
    }
}
