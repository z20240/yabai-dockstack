import Foundation

/// Runtime inputs the yabai / Keyboard panes need beyond the ConfigEngine: live yabai
/// state, auto-padding originals, rc path detection and dockstack's own path override.
/// Injected so panes stay testable; `.none` makes every source a no-op.
public struct RcSources {
    /// What yabai is running now; nil when yabai isn't reachable.
    public var liveYabai: () -> YabaiLiveState?
    /// The user's own paddings while auto padding is adjusting them; nil when it's off.
    public var autoPaddingOriginal: () -> Paddings?
    /// The rc file the tool itself loads (auto-detected); "" when unknown.
    public var detectedPath: (RcTool) -> String
    /// dockstack's configured override for the tool's rc path; "" = auto.
    public var pathOverride: (RcTool) -> String
    /// Persist a new override ("" = reset to auto). Only touches dockstack's own config.
    public var onPathChange: (RcTool, String) -> Void

    public init(liveYabai: @escaping () -> YabaiLiveState?,
                autoPaddingOriginal: @escaping () -> Paddings?,
                detectedPath: @escaping (RcTool) -> String,
                pathOverride: @escaping (RcTool) -> String,
                onPathChange: @escaping (RcTool, String) -> Void) {
        self.liveYabai = liveYabai
        self.autoPaddingOriginal = autoPaddingOriginal
        self.detectedPath = detectedPath
        self.pathOverride = pathOverride
        self.onPathChange = onPathChange
    }

    public static let none = RcSources(liveYabai: { nil }, autoPaddingOriginal: { nil },
                                       detectedPath: { _ in "" }, pathOverride: { _ in "" },
                                       onPathChange: { _, _ in })
}
