import AppKit
import CoreGraphics

/// Global CGEventTap implementing hold-to-cycle (⌥⇥-style) switching. This
/// layer only decodes CGEvents and swallows the ones the switcher consumes;
/// all decisions live in the pure SwitcherKeyMachine. Requires Accessibility;
/// the tap runs on the main run loop, so `onOutput` fires on the main thread.
public final class SwitcherKeyTap {
    public var triggers: [SwitcherTrigger] = []
    public var onOutput: ((SwitcherKeyOutput) -> Void)?

    private var machine = SwitcherKeyMachine()
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    public init() {}

    public var isRunning: Bool { tap != nil }

    /// Abort an activation the controller couldn't honor (e.g. no windows) so
    /// the machine stops swallowing keys until the next trigger press.
    public func resetMachine() { machine.deactivate() }

    @discardableResult
    public func start() -> Bool {
        if tap != nil { return true }
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let me = Unmanaged<SwitcherKeyTap>.fromOpaque(refcon).takeUnretainedValue()
                return me.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        tap = port
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        source = src
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }

    public func stop() {
        machine.deactivate()
        if let src = source { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        source = nil
        if let t = tap {
            CGEvent.tapEnable(tap: t, enable: false)
            CFMachPortInvalidate(t)
        }
        tap = nil
    }

    private static func mods(from flags: CGEventFlags) -> Set<Hotkey.Mod> {
        var s = Set<Hotkey.Mod>()
        if flags.contains(.maskCommand) { s.insert(.cmd) }
        if flags.contains(.maskAlternate) { s.insert(.alt) }
        if flags.contains(.maskControl) { s.insert(.ctrl) }
        if flags.contains(.maskShift) { s.insert(.shift) }
        return s
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // The system disables taps that stall; recover instead of going deaf.
            if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
            return Unmanaged.passUnretained(event)
        case .keyUp:
            // keyDowns we swallowed must not leak their keyUps to the app.
            return machine.activeTrigger != nil ? nil : Unmanaged.passUnretained(event)
        case .keyDown, .flagsChanged:
            let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let mods = Self.mods(from: event.flags)
            let input: SwitcherKeyInput = (type == .keyDown)
                ? .keyDown(code: code, mods: mods)
                : .flagsChanged(mods: mods)
            let out = machine.handle(input, triggers: triggers)
            switch out {
            case .pass:
                return Unmanaged.passUnretained(event)
            case .commit(consume: false):
                onOutput?(out)
                return Unmanaged.passUnretained(event)   // modifier release must reach apps
            case .swallow:
                return nil
            default:
                onOutput?(out)
                return nil
            }
        default:
            return Unmanaged.passUnretained(event)
        }
    }
}
