import XCTest
@testable import YabaiDockstackKit

final class L10nTests: XCTestCase {
    func testResolveAuto() {
        XCTAssertEqual(L10n.resolve(.auto, preferred: ["zh-Hant-TW", "en"]), .zhHant)
        XCTAssertEqual(L10n.resolve(.auto, preferred: ["zh-TW"]), .zhHant)
        XCTAssertEqual(L10n.resolve(.auto, preferred: ["zh-HK"]), .zhHant)
        XCTAssertEqual(L10n.resolve(.auto, preferred: ["ja-JP", "en"]), .ja)
        XCTAssertEqual(L10n.resolve(.auto, preferred: ["en-US"]), .en)
        XCTAssertEqual(L10n.resolve(.auto, preferred: ["de-DE", "fr"]), .en)
        XCTAssertEqual(L10n.resolve(.auto, preferred: ["zh-Hans-CN"]), .en)  // Simplified → en (not supported)
        XCTAssertEqual(L10n.resolve(.auto, preferred: []), .en)
        // First match wins across the list order:
        XCTAssertEqual(L10n.resolve(.auto, preferred: ["de-DE", "ja-JP"]), .ja)
    }

    func testResolveExplicit() {
        XCTAssertEqual(L10n.resolve(.en, preferred: ["ja"]), .en)
        XCTAssertEqual(L10n.resolve(.zhHant, preferred: []), .zhHant)
        XCTAssertEqual(L10n.resolve(.ja, preferred: ["zh-TW"]), .ja)
    }

    func testTableParity() {
        let en = Set(L10nStrings.en.keys)
        let zh = Set(L10nStrings.zhHant.keys)
        let ja = Set(L10nStrings.ja.keys)
        XCTAssertEqual(en, zh, "zh-Hant keys differ from en: \(en.symmetricDifference(zh).sorted())")
        XCTAssertEqual(en, ja, "ja keys differ from en: \(en.symmetricDifference(ja).sorted())")
        for table in [L10nStrings.en, L10nStrings.zhHant, L10nStrings.ja] {
            for (k, v) in table { XCTAssertFalse(v.isEmpty, "empty translation for \(k)") }
        }
    }

    func testCatalogCoverage() {
        for action in ShortcutCatalog.all {
            XCTAssertNotNil(L10nStrings.en["action.\(action.id)"], "missing action.\(action.id)")
        }
        for group in ShortcutGroup.order {
            XCTAssertNotNil(L10nStrings.en["group.\(group)"], "missing group.\(group)")
        }
    }

    func testLookupAndFallback() {
        L10n.current = .zhHant
        XCTAssertEqual(L10n.t("ui.apply"), "套用")
        L10n.current = .ja
        XCTAssertEqual(L10n.t("ui.apply"), "適用")
        L10n.current = .en
        XCTAssertEqual(L10n.t("ui.apply"), "Apply")
        XCTAssertEqual(L10n.t("no.such.key"), "no.such.key")  // key itself as last resort
    }

    /// Every literal L10n.t("…") key in Sources/ must exist in the en table —
    /// a typo'd key would otherwise silently render as the raw key string.
    func testEveryLiteralCallSiteKeyExists() throws {
        let sourcesDir = URL(fileURLWithPath: #filePath)          // …/Tests/YabaiDockstackKitTests/L10nTests.swift
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources")
        let regex = try NSRegularExpression(pattern: #"L10n\.t\("([^"\\]+)"\)"#)
        var checked = 0
        let files = FileManager.default.enumerator(at: sourcesDir, includingPropertiesForKeys: nil)!
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        for file in files {
            guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            for m in regex.matches(in: text, range: range) {
                guard let r = Range(m.range(at: 1), in: text) else { continue }
                let key = String(text[r])
                XCTAssertNotNil(L10nStrings.en[key],
                                "L10n.t(\"\(key)\") in \(file.lastPathComponent) has no en entry")
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 50, "call-site scan found suspiciously few keys — regex or path broken?")
    }
}
