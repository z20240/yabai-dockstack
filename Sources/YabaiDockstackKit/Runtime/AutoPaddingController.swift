import Foundation

/// Applies `AutoPadding` with `yabai -m config` while enabled (never touching
/// yabairc) and puts the user's own values back when disabled or on quit.
public final class AutoPaddingController {
    private let client: YabaiClient
    private var enabled = false
    private var params = (cellSize: 32.0, stripEnabled: false, stripScale: 0.8)
    /// The user's values, read when we took over.
    private var original: Paddings?
    private var applied: Paddings?

    public init(client: YabaiClient) { self.client = client }

    /// The user's own paddings while auto padding is adjusting them; nil when it's off.
    public var userOriginal: Paddings? { enabled ? original : nil }

    public func update(enabled: Bool, cellSize: Double, stripEnabled: Bool, stripScale: Double) {
        self.enabled = enabled
        params = (cellSize, stripEnabled, stripScale)
        if enabled { apply() } else { restore() }
    }

    /// yabai restarts reload yabairc, wiping our values: adopt what it has now
    /// as the user's values and apply again. Called by the 5 s health tick.
    public func heal() {
        guard enabled, let applied, let current = read(), current != applied else { return }
        original = current
        self.applied = nil
        apply()
    }

    public func restore() {
        if let original { write(original) }
        original = nil
        applied = nil
    }

    private func apply() {
        if original == nil { original = read() }
        guard let original else { return }  // yabai unavailable — try again on the next update/heal
        let target = AutoPadding.target(original: original, cellSize: params.cellSize,
                                        stripEnabled: params.stripEnabled, stripScale: params.stripScale)
        guard target != applied else { return }
        write(target)
        applied = target
    }

    private func read() -> Paddings? {
        guard let l = client.configInt("left_padding"), let r = client.configInt("right_padding"),
              let t = client.configInt("top_padding") else { return nil }
        return Paddings(left: l, right: r, top: t)
    }

    private func write(_ p: Paddings) {
        client.setConfig("left_padding", p.left)
        client.setConfig("right_padding", p.right)
        client.setConfig("top_padding", p.top)
    }
}
