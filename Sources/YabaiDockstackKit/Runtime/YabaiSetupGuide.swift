import AppKit
import Foundation

/// First-run guidance shown when yabai isn't found. We never silently install a
/// system tool — instead we open Terminal with the install command (visible, so
/// the user can enter sudo and follow yabai's own setup), or the install guide.
public final class YabaiSetupGuide {
    private let guideURL = "https://github.com/koekeishiya/yabai/wiki/Installing-yabai-(latest-release)"

    public var onSetPath: (() -> Void)?

    public init() {}

    public func show() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "yabai not found"
        alert.informativeText = """
        yabai-dockstack is a companion for yabai and needs it to work — every \
        feature reads window/stack state from yabai.

        “Install yabai…” opens Terminal with the Homebrew install command so you \
        can run it yourself. yabai also needs its own setup (start the service, \
        and partially disable SIP for full window management) — see the install \
        guide. yabai-dockstack starts working automatically once yabai is running.

        Already have yabai elsewhere? Use “Set yabai path…”.
        """
        alert.addButton(withTitle: "Install yabai…")     // .alertFirstButtonReturn
        alert.addButton(withTitle: "Open install guide")  // .alertSecondButtonReturn
        alert.addButton(withTitle: "Set yabai path…")     // .alertThirdButtonReturn
        // (Escape / closing the window dismisses without an explicit "Later".)

        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn: installViaTerminal()
        case .alertSecondButtonReturn: open(guideURL)
        case .alertThirdButtonReturn: onSetPath?()
        default: break
        }
    }

    private func brewPath() -> String? {
        ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private func installViaTerminal() {
        guard let brew = brewPath() else {
            // No Homebrew — point them at Homebrew, then the yabai guide.
            open("https://brew.sh")
            open(guideURL)
            return
        }
        let script = """
        #!/bin/bash
        echo "Installing yabai via Homebrew…"
        "\(brew)" install koekeishiya/formulae/yabai && yabai --start-service
        echo ""
        echo "yabai installed. For full window management you may still need to"
        echo "complete yabai's setup (SIP / scripting addition):"
        echo "  \(guideURL)"
        echo ""
        echo "yabai-dockstack will start working automatically once yabai is running."
        """
        let path = NSTemporaryDirectory() + "install-yabai.command"
        do {
            try script.write(toFile: path, atomically: true, encoding: .utf8)
            chmod(path, 0o755)
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        } catch {
            open(guideURL)
        }
    }

    private func open(_ s: String) {
        if let u = URL(string: s) { NSWorkspace.shared.open(u) }
    }
}
