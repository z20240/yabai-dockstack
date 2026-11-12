import AppKit

/// The "Apply will comment out N hand-written line(s)" confirmation, shared by the
/// yabai and Keyboard panes. Runs as a sheet on `window` (synchronously, via a modal
/// session) or as an app-modal alert when there is no window.
public enum ApplyConfirmAlert {
    /// Returns true when the user chose Apply.
    public static func run(plan: ApplyPlan, path: String, window: NSWindow?) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.t("ui.apply.confirmTitle")
        alert.informativeText = String(format: L10n.t("ui.apply.confirmBody"), plan.linesToComment,
                                       (path as NSString).abbreviatingWithTildeInPath)
        alert.addButton(withTitle: L10n.t("ui.apply"))
        alert.addButton(withTitle: L10n.t("ui.cancel"))
        guard let window else { return alert.runModal() == .alertFirstButtonReturn }
        alert.beginSheetModal(for: window) { NSApp.stopModal(withCode: $0) }
        return NSApp.runModal(for: alert.window) == .alertFirstButtonReturn
    }
}
