import Foundation

public struct ShortcutRow: Equatable {
    public let action: ShortcutAction
    public var binding: ShortcutBinding
    public init(action: ShortcutAction, binding: ShortcutBinding) { self.action = action; self.binding = binding }
}

public struct ShortcutSection: Equatable {
    public let group: String
    public let rows: [ShortcutRow]
}

public enum ShortcutSections {
    public static func build(_ bindings: [ShortcutBinding]) -> [ShortcutSection] {
        let byID = Dictionary(bindings.map { ($0.actionID, $0) }, uniquingKeysWith: { first, _ in first })
        return ShortcutGroup.order.map { group in
            let rows = ShortcutCatalog.all.filter { $0.group == group }.map { action -> ShortcutRow in
                let binding = byID[action.id] ?? ShortcutBinding(actionID: action.id, enabled: false, hotkey: nil)
                return ShortcutRow(action: action, binding: binding)
            }
            return ShortcutSection(group: group, rows: rows)
        }
    }

    public static func conflictingActionIDs(_ bindings: [ShortcutBinding]) -> Set<String> {
        var ids = Set<String>()
        for (_, actionIDs) in ShortcutConflicts.find(bindings) { ids.formUnion(actionIDs) }
        return ids
    }
}
