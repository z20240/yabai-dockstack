import Foundation

public struct Hotkey: Equatable, Hashable {
    public enum Mod: String, CaseIterable { case ctrl, shift, alt, cmd }
    public var mods: Set<Mod>
    public var key: String

    public init(mods: Set<Mod>, key: String) { self.mods = mods; self.key = key }

    private static let order: [Mod] = [.ctrl, .shift, .alt, .cmd]

    public static func parse(_ s: String) -> Hotkey? {
        // Split on the LAST " - " so mod separators ("+") aren't confused.
        guard let dash = s.range(of: "-", options: .backwards) else { return nil }
        let lhs = s[..<dash.lowerBound].trimmingCharacters(in: .whitespaces)
        let key = s[dash.upperBound...].trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return nil }
        var mods = Set<Mod>()
        if !lhs.isEmpty {
            for token in lhs.split(separator: "+") {
                let t = token.trimmingCharacters(in: .whitespaces)
                guard let m = Mod(rawValue: t) else { return nil }
                mods.insert(m)
            }
        }
        return Hotkey(mods: mods, key: key)
    }

    public var skhdString: String {
        let ordered = Hotkey.order.filter { mods.contains($0) }.map { $0.rawValue }
        let prefix = ordered.isEmpty ? "" : ordered.joined(separator: " + ") + " - "
        return prefix + key
    }

    public var displayString: String {
        let glyphs: [Mod: String] = [.ctrl: "⌃", .shift: "⇧", .alt: "⌥", .cmd: "⌘"]
        let mp = Hotkey.order.filter { mods.contains($0) }.map { glyphs[$0]! }.joined()
        let keyGlyph: String
        switch key.lowercased() {
        case "left": keyGlyph = "←"
        case "right": keyGlyph = "→"
        case "up": keyGlyph = "↑"
        case "down": keyGlyph = "↓"
        case "space": keyGlyph = "Space"
        case "tab": keyGlyph = "⇥"
        case "0x2b": keyGlyph = ","
        case "0x32": keyGlyph = "`"
        default: keyGlyph = key.uppercased()
        }
        return mp + keyGlyph
    }
}
