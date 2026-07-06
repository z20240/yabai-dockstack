import Foundation

/// Quick-select keys assigned to window items while the status menu is open:
/// digits first, then home-row letters, then the remaining bottom row.
public enum MenuQuickKeys {
    public static let sequence: [String] = [
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
        "a", "s", "d", "f", "g", "h", "j", "k", "l",
        "z", "x", "c", "v", "b", "n", "m",
    ]

    /// First `count` keys (clamped to the sequence length; negative → empty).
    public static func keys(count: Int) -> [String] {
        Array(sequence.prefix(max(0, count)))
    }
}
