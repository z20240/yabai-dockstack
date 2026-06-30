import AppKit

/// A Raycast-style "Record Hotkey" field: click, press a modifier+key combo,
/// and it captures a `Hotkey`. Escape cancels; the ✕ clears.
public final class RecordHotkeyControl: NSView {
    public var hotkey: Hotkey? { didSet { refreshTitle() } }
    public var onChange: ((Hotkey?) -> Void)?

    private let button = NSButton()
    private let clearButton = NSButton()
    private var recording = false
    private var monitor: Any?

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    public required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)
        button.target = self
        button.action = #selector(toggleRecording)
        clearButton.bezelStyle = .inline
        clearButton.title = "✕"
        clearButton.target = self
        clearButton.action = #selector(clear)
        clearButton.controlSize = .small
        let stack = NSStackView(views: [button, clearButton])
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 130),
        ])
        refreshTitle()
    }

    private func refreshTitle() {
        button.title = recording ? "Recording…" : (hotkey?.displayString ?? "Record Hotkey")
        clearButton.isHidden = hotkey == nil || recording
    }

    @objc private func toggleRecording() {
        recording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        recording = true
        refreshTitle()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] ev in
            guard let self, self.recording else { return ev }
            if ev.type == .keyDown {
                if ev.keyCode == 0x35 { self.stopRecording(); return nil } // escape cancels
                let mods = Self.mods(from: ev.modifierFlags)
                guard !mods.isEmpty else { return nil } // require at least one modifier
                let key = KeyCodeMap.skhdKey(forKeyCode: ev.keyCode, chars: ev.charactersIgnoringModifiers)
                self.hotkey = Hotkey(mods: mods, key: key)
                self.stopRecording()
                self.onChange?(self.hotkey)
                return nil
            }
            return ev
        }
    }

    private func stopRecording() {
        recording = false
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        refreshTitle()
    }

    @objc private func clear() {
        hotkey = nil
        onChange?(nil)
    }

    private static func mods(from flags: NSEvent.ModifierFlags) -> Set<Hotkey.Mod> {
        var s = Set<Hotkey.Mod>()
        if flags.contains(.command) { s.insert(.cmd) }
        if flags.contains(.option) { s.insert(.alt) }
        if flags.contains(.control) { s.insert(.ctrl) }
        if flags.contains(.shift) { s.insert(.shift) }
        return s
    }
}
