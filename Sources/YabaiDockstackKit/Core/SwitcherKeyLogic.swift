import Foundation

/// A hold-to-cycle trigger: keycode + required modifiers + which windows to show.
public struct SwitcherTrigger: Equatable {
    public let keycode: UInt16
    public let mods: Set<Hotkey.Mod>
    public let scope: SwitcherScope

    public init(keycode: UInt16, mods: Set<Hotkey.Mod>, scope: SwitcherScope) {
        self.keycode = keycode; self.mods = mods; self.scope = scope
    }
}

public enum SwitcherTriggers {
    /// Keycode of Tab, used for the ⌘⇥ capture override.
    public static let tabKeycode: UInt16 = 0x30

    /// Parse the config's hotkey strings into triggers. Empty string = disabled;
    /// unparseable or modifier-less entries are skipped (hold-to-cycle needs a
    /// modifier to release). `switcherCaptureCmdTab` replaces the all-windows
    /// key with ⌘⇥, suppressing the system switcher while the app runs.
    public static func build(from config: AppConfig) -> [SwitcherTrigger] {
        var out: [SwitcherTrigger] = []
        func add(_ s: String, _ scope: SwitcherScope) {
            guard let hk = Hotkey.parse(s), !hk.mods.isEmpty,
                  let code = KeyCodeMap.keyCode(forSkhdKey: hk.key) else { return }
            out.append(SwitcherTrigger(keycode: code, mods: hk.mods, scope: scope))
        }
        if config.switcherCaptureCmdTab {
            out.append(SwitcherTrigger(keycode: tabKeycode, mods: [.cmd], scope: .allWindows))
        } else {
            add(config.switcherHotkeyAll, .allWindows)
        }
        add(config.switcherHotkeyApp, .currentApp)
        add(config.switcherHotkeySpace, .currentSpace)
        return out
    }
}

public enum SwitcherKeyInput: Equatable {
    case keyDown(code: UInt16, mods: Set<Hotkey.Mod>)
    case flagsChanged(mods: Set<Hotkey.Mod>)
}

public enum SwitcherKeyOutput: Equatable {
    case pass                              // not ours; deliver to the app
    case swallow                           // ours; consume, no action
    case activate(trigger: Int, backward: Bool)
    case cycle(forward: Bool)
    case move(dx: Int, dy: Int)
    case commit(consume: Bool)             // consume=false when driven by modifier release
    case cancel
    case closeSelected
}

/// Pure state machine behind the switcher's CGEventTap: keycodes + modifiers in,
/// switcher actions out. Owns only the "which trigger is being held" state; the
/// tap layer does CGEvent conversion and swallowing.
public struct SwitcherKeyMachine: Equatable {
    public private(set) var activeTrigger: Int?

    public init() { activeTrigger = nil }

    /// Abort an activation the controller couldn't honor (e.g. no windows).
    public mutating func deactivate() { activeTrigger = nil }

    /// Required mods must all be held; extra shift is tolerated (it's the
    /// "backward" flag); any other extra modifier means a different shortcut.
    private static func matches(_ t: SwitcherTrigger, code: UInt16, mods: Set<Hotkey.Mod>) -> Bool {
        guard t.keycode == code, t.mods.isSubset(of: mods) else { return false }
        return mods.subtracting(t.mods).isSubset(of: [.shift])
    }

    public mutating func handle(_ input: SwitcherKeyInput,
                                triggers: [SwitcherTrigger]) -> SwitcherKeyOutput {
        switch input {
        case let .keyDown(code, mods):
            if let active = activeTrigger, active < triggers.count {
                if Self.matches(triggers[active], code: code, mods: mods) {
                    let backward = mods.subtracting(triggers[active].mods).contains(.shift)
                    return .cycle(forward: !backward)
                }
                // A different trigger key with its modifiers held switches scope.
                if let idx = triggers.indices.first(where: {
                    Self.matches(triggers[$0], code: code, mods: mods)
                }) {
                    activeTrigger = idx
                    return .activate(trigger: idx, backward: false)
                }
                switch code {
                case 0x24, 0x4C: activeTrigger = nil; return .commit(consume: true)  // return / enter
                case 0x35: activeTrigger = nil; return .cancel                       // escape
                case 0x7B: return .move(dx: -1, dy: 0)
                case 0x7C: return .move(dx: 1, dy: 0)
                case 0x7E: return .move(dx: 0, dy: -1)
                case 0x7D: return .move(dx: 0, dy: 1)
                case 0x0D: return .closeSelected                                     // w
                default: return .swallow
                }
            }
            if let idx = triggers.indices.first(where: {
                Self.matches(triggers[$0], code: code, mods: mods)
            }) {
                activeTrigger = idx
                let backward = mods.subtracting(triggers[idx].mods).contains(.shift)
                return .activate(trigger: idx, backward: backward)
            }
            return .pass
        case let .flagsChanged(mods):
            guard let active = activeTrigger, active < triggers.count else { return .pass }
            if !triggers[active].mods.isSubset(of: mods) {
                activeTrigger = nil
                return .commit(consume: false)
            }
            return .pass
        }
    }
}
