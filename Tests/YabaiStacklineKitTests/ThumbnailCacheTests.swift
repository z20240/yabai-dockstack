import XCTest
import CoreGraphics
@testable import YabaiStacklineKit

final class ThumbnailCacheTests: XCTestCase {
    private func img() -> CGImage {
        let ctx = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8,
                            bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return ctx.makeImage()!
    }

    func testPutGet() {
        let c = ThumbnailCache(limit: 2)
        c.put(1, img())
        XCTAssertNotNil(c.get(1))
        XCTAssertTrue(c.contains(1))
        XCTAssertNil(c.get(99))
    }

    func testEvictsLeastRecentlyUsed() {
        let c = ThumbnailCache(limit: 2)
        c.put(1, img()); c.put(2, img())
        _ = c.get(1)            // 1 now most-recent
        c.put(3, img())         // evicts 2 (LRU)
        XCTAssertTrue(c.contains(1))
        XCTAssertFalse(c.contains(2))
        XCTAssertTrue(c.contains(3))
    }
}
