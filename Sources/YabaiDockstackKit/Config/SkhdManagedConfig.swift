import Foundation

public enum SkhdManagedConfig {
    private static func resolve(_ command: String, _ scriptsDir: String) -> String {
        command.replacingOccurrences(of: "${SCRIPTS}", with: scriptsDir)
    }

    public static func generate(_ bindings: [ShortcutBinding],
                                catalog: [ShortcutAction],
                                scriptsDir: String) -> String {
        // Emit in catalog order for deterministic output.
        let byID = Dictionary(uniqueKeysWithValues: bindings.map { ($0.actionID, $0) })
        var lines: [String] = []
        for action in catalog {
            guard let b = byID[action.id], b.enabled, let hk = b.hotkey else { continue }
            lines.append("\(hk.skhdString) : \(resolve(action.command, scriptsDir))")
        }
        return lines.joined(separator: "\n")
    }

    public static func parse(_ body: String,
                             catalog: [ShortcutAction],
                             scriptsDir: String) -> [ShortcutBinding] {
        // Map resolved command -> actionID for recovery.
        var cmdToID: [String: String] = [:]
        for a in catalog { cmdToID[resolve(a.command, scriptsDir)] = a.id }
        var result: [ShortcutBinding] = []
        for raw in body.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard let colon = line.range(of: " : ") else { continue }
            let lhs = String(line[..<colon.lowerBound]).trimmingCharacters(in: .whitespaces)
            let rhs = String(line[colon.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard let hk = Hotkey.parse(lhs), let id = cmdToID[rhs] else { continue }
            result.append(ShortcutBinding(actionID: id, enabled: true, hotkey: hk))
        }
        return result
    }
}
