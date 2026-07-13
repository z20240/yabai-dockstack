import AppKit
import CoreGraphics

/// Global CGEventTap implementing hold-to-cycle (⌥⇥-style) switching. This
/// layer only decodes CGEvents and swallows the ones the switcher consumes;
/// all decisions live in the pure SwitcherKeyMachine. Requires Accessibility;
/// the tap runs on the main run loop, so `onOutput` fires on the main thread.
public final class SwitcherKeyTap {
    public private(set) var triggers: [SwitcherTrigger] = []
    public var onOutput: ((SwitcherKeyOutput) -> Void)?

    private var machine = SwitcherKeyMachine()
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    /// Keycodes whose keyDown we consumed and whose keyUp hasn't arrived yet.
    /// Their keyUps (and autorepeat keyDowns, e.g. Tab still held after the
    /// modifier release committed) must also be consumed, and nothing else.
    private var swallowedKeys = Set<UInt16>()

    public init() {}

    public var isRunning: Bool { tap != nil }

    /// Abort an activation the controller couldn't honor (e.g. no windows) so
    /// the machine stops swallowing keys until the next trigger press.
    public func resetMachine() { machine.deactivate() }

    /// Swap the trigger set. A hold in progress can't survive a trigger swap
    /// (the active index may point elsewhere or out of range), so bail out.
    public func updateTriggers(_ new: [SwitcherTrigger]) {
        guard new != triggers else { return }
        cancelActiveHold()
        triggers = new
    }

    private func cancelActiveHold() {
        guard machine.activeTrigger != nil else { return }
        machine.deactivate()
        onOutput?(.cancel)
    }

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
        cancelActiveHold()
        swallowedKeys.removeAll()
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
            // The system disables taps that stall; recover instead of going
            // deaf. We may have missed the modifier release meanwhile, so a
            // hold in progress can't be trusted — bail out of it.
            if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
            cancelActiveHold()
            return Unmanaged.passUnretained(event)
        case .keyUp:
            // Consume exactly the keyUps whose keyDown we consumed; keys that
            // were already held when the switcher activated stay untouched.
            let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            return swallowedKeys.remove(code) != nil ? nil : Unmanaged.passUnretained(event)
        case .keyDown, .flagsChanged:
            let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let mods = Self.mods(from: event.flags)
            let input: SwitcherKeyInput = (type == .keyDown)
                ? .keyDown(code: code, mods: mods)
                : .flagsChanged(mods: mods)
            let out = machine.handle(input, triggers: triggers)
            switch out {
            case .pass:
                // Autorepeats of a consumed keyDown stay consumed even after
                // the machine went idle (Tab still held post-commit).
                if type == .keyDown, swallowedKeys.contains(code) { return nil }
                return Unmanaged.passUnretained(event)
            case .commit(consume: false):
                onOutput?(out)
                return Unmanaged.passUnretained(event)   // modifier release must reach apps
            case .swallow:
                if type == .keyDown { swallowedKeys.insert(code) }
                return nil
            default:
                onOutput?(out)
                if type == .keyDown { swallowedKeys.insert(code) }
                return nil
            }
        default:
            return Unmanaged.passUnretained(event)
        }
    }
}
