import Foundation

/// Read-only view of the user's real skhdrc: catalog-action bindings plus every other line.
public struct FaithfulSkhdView: Equatable {
    public var bindings: [ShortcutBinding]   // one per catalog action, catalog order; unmatched → enabled:false, hotkey:nil
    public var others: [String]              // trimmed raw lines, file order
    public init(bindings: [ShortcutBinding], others: [String]) {
        self.bindings = bindings; self.others = others
    }
}

public enum FaithfulSkhd {
    public static func parse(_ text: String, catalog: [ShortcutAction], scriptsDir: String) -> FaithfulSkhdView {
        var cmdToID: [String: String] = [:]
        for a in catalog {
            let resolved = a.command.replacingOccurrences(of: "${SCRIPTS}", with: scriptsDir)
            cmdToID[FreeformImporter.normalizeCommand(resolved)] = a.id
        }
        var bound: [String: Hotkey] = [:]
        var others: [String] = []
        var continuing = false
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let t = String(raw).trimmingCharacters(in: .whitespaces)
            if continuing {
                others.append(t)
                continuing = t.hasSuffix("\\")
                continue
            }
            if t.isEmpty || t.hasPrefix("#") { continue }
            if t.hasSuffix("\\") { others.append(t); continuing = true; continue }
            if let (hk, cmd) = FreeformImporter.parseSkhdLine(t),
               let id = cmdToID[FreeformImporter.normalizeCommand(cmd)], bound[id] == nil {
                bound[id] = hk
            } else {
                others.append(t)
            }
        }
        let bindings = catalog.map { a in
            ShortcutBinding(actionID: a.id, enabled: bound[a.id] != nil, hotkey: bound[a.id])
        }
        return FaithfulSkhdView(bindings: bindings, others: others)
    }
}
