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
}
