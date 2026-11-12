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
    /// What one skhdrc line is to the panel.
    enum LineRole: Equatable {
        /// The first line (whole file, managed region included) binding this catalog action.
        case binding(actionID: String, hotkey: Hotkey)
        /// Shown raw under "Other shortcuts": non-catalog bindings, later duplicates,
        /// directives, modes, continuation lines, and indented (not representable) lines.
        case other
        /// Blank or comment.
        case skip
    }

    /// The single classification behind both the panel (`parse`) and the importer, so
    /// Apply comments out exactly the lines the panel represents.
    static func classify(_ lines: [String], catalog: [ShortcutAction], scriptsDir: String) -> [LineRole] {
        var cmdToID: [String: String] = [:]
        for a in catalog {
            let resolved = a.command.replacingOccurrences(of: "${SCRIPTS}", with: scriptsDir)
            cmdToID[FreeformImporter.normalizeCommand(resolved)] = a.id
        }
        var bound = Set<String>()
        var continuing = false
        return lines.map { raw in
            let t = raw.trimmingCharacters(in: .whitespaces)
            if continuing {
                continuing = t.hasSuffix("\\")
                return .other
            }
            if t.isEmpty || t.hasPrefix("#") { return .skip }
            if t.hasSuffix("\\") { continuing = true; return .other }
            if !FreeformImporter.isIndented(raw),
               let (hk, cmd) = FreeformImporter.parseSkhdLine(t),
               let id = cmdToID[FreeformImporter.normalizeCommand(cmd)], !bound.contains(id) {
                bound.insert(id)
                return .binding(actionID: id, hotkey: hk)
            }
            return .other
        }
    }

    public static func parse(_ text: String, catalog: [ShortcutAction], scriptsDir: String) -> FaithfulSkhdView {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var bound: [String: Hotkey] = [:]
        var others: [String] = []
        for (line, role) in zip(lines, classify(lines, catalog: catalog, scriptsDir: scriptsDir)) {
            switch role {
            case .binding(let id, let hk): bound[id] = hk
            case .other: others.append(line.trimmingCharacters(in: .whitespaces))
            case .skip: break
            }
        }
        let bindings = catalog.map { a in
            ShortcutBinding(actionID: a.id, enabled: bound[a.id] != nil, hotkey: bound[a.id])
        }
        return FaithfulSkhdView(bindings: bindings, others: others)
    }
}
