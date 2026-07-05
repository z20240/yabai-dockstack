import Foundation

/// User-facing language choice stored in config.json.
public enum AppLanguage: String, Codable, CaseIterable {
    case auto = "auto"
    case en = "en"
    case zhHant = "zh-Hant"
    case ja = "ja"
}

/// A concrete language after resolving `auto` against the system preference.
public enum ResolvedLanguage: String {
    case en, zhHant, ja
}

public enum L10n {
    /// The active language; set at startup and by the Settings picker.
    public static var current: ResolvedLanguage = .en

    /// Pure resolution: `auto` scans the preferred-locale identifiers in order
    /// and picks the first supported match; anything unsupported falls to en.
    public static func resolve(_ lang: AppLanguage, preferred: [String]) -> ResolvedLanguage {
        switch lang {
        case .en: return .en
        case .zhHant: return .zhHant
        case .ja: return .ja
        case .auto:
            for id in preferred {
                let lower = id.lowercased()
                if lower.hasPrefix("zh-hant") || lower.hasPrefix("zh-tw") || lower.hasPrefix("zh-hk") {
                    return .zhHant
                }
                if lower.hasPrefix("ja") { return .ja }
                if lower.hasPrefix("en") { return .en }
            }
            return .en
        }
    }

    /// Current-language string for `key`, falling back to English, then the key.
    public static func t(_ key: String) -> String {
        let table: [String: String]
        switch current {
        case .en: table = L10nStrings.en
        case .zhHant: table = L10nStrings.zhHant
        case .ja: table = L10nStrings.ja
        }
        return table[key] ?? L10nStrings.en[key] ?? key
    }
}
