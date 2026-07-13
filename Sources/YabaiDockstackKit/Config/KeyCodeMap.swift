import Foundation

/// Maps a macOS virtual keycode (NSEvent.keyCode) to the key literal skhd expects.
public enum KeyCodeMap {
    private static let named: [UInt16: String] = [
        0x7B: "left", 0x7C: "right", 0x7D: "down", 0x7E: "up",
        0x31: "space", 0x24: "return", 0x30: "tab", 0x35: "escape",
        0x33: "backspace", 0x75: "delete",
        0x73: "home", 0x77: "end", 0x74: "pageup", 0x79: "pagedown",
        0x7A: "f1", 0x78: "f2", 0x63: "f3", 0x76: "f4", 0x60: "f5", 0x61: "f6",
        0x62: "f7", 0x64: "f8", 0x65: "f9", 0x6D: "f10", 0x67: "f11", 0x6F: "f12",
    ]

    public static func skhdKey(forKeyCode code: UInt16, chars: String?) -> String {
        if let n = named[code] { return n }
        if let c = chars?.lowercased(), c.count == 1,
           let scalar = c.unicodeScalars.first,
           (("a"..."z").contains(c) || ("0"..."9").contains(c)),
           scalar.isASCII {
            return c
        }
        return String(format: "0x%02X", code)
    }

    /// Letters/digits on the ANSI layout — reverse of what `chars` capture gives.
    private static let ansi: [String: UInt16] = [
        "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04, "g": 0x05,
        "z": 0x06, "x": 0x07, "c": 0x08, "v": 0x09, "b": 0x0B, "q": 0x0C,
        "w": 0x0D, "e": 0x0E, "r": 0x0F, "y": 0x10, "t": 0x11,
        "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "6": 0x16, "5": 0x17,
        "9": 0x19, "7": 0x1A, "8": 0x1C, "0": 0x1D,
        "o": 0x1F, "u": 0x20, "i": 0x22, "p": 0x23, "l": 0x25, "j": 0x26,
        "k": 0x28, "n": 0x2D, "m": 0x2E,
    ]

    /// Reverse mapping for the switcher's event tap: skhd key literal -> keycode.
    public static func keyCode(forSkhdKey key: String) -> UInt16? {
        let k = key.lowercased()
        if let named = named.first(where: { $0.value == k })?.key { return named }
        if let code = ansi[k] { return code }
        if k.hasPrefix("0x"), let v = UInt16(k.dropFirst(2), radix: 16) { return v }
        return nil
    }
}
