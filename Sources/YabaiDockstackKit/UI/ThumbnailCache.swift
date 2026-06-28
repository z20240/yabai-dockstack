import CoreGraphics
import Foundation

/// LRU cache of the most recent thumbnail per window (CGWindowID). Populated while
/// a window is on-screen; serves the last-known image when it later moves to a
/// hidden space (where live capture is impossible).
public final class ThumbnailCache {
    private let limit: Int
    private var store: [Int: CGImage] = [:]
    private var order: [Int] = []   // oldest first
    private let lock = NSLock()

    public init(limit: Int = 200) { self.limit = limit }

    public func put(_ id: Int, _ image: CGImage) {
        lock.lock(); defer { lock.unlock() }
        store[id] = image
        order.removeAll { $0 == id }
        order.append(id)
        while order.count > limit, let oldest = order.first {
            order.removeFirst()
            store[oldest] = nil
        }
    }

    public func get(_ id: Int) -> CGImage? {
        lock.lock(); defer { lock.unlock() }
        guard let img = store[id] else { return nil }
        order.removeAll { $0 == id }
        order.append(id)
        return img
    }

    public func contains(_ id: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return store[id] != nil
    }

    public var count: Int {
        lock.lock(); defer { lock.unlock() }
        return store.count
    }
}
