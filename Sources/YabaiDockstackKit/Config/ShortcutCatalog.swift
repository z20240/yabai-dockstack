import Foundation

public struct ShortcutAction: Equatable {
    public let id: String
    public let title: String
    public let group: String
    public let command: String        // may contain ${SCRIPTS}
    public let defaultHotkey: Hotkey?
    public let symbol: String
    public init(_ id: String, _ title: String, _ group: String, _ command: String, _ defaultHotkey: Hotkey?, symbol: String = "keyboard") {
        self.id = id; self.title = title; self.group = group; self.command = command; self.defaultHotkey = defaultHotkey; self.symbol = symbol
    }
}

public enum ShortcutGroup {
    public static let order = ["General", "Shared", "BSP Mode", "Floating Mode"]
}

public enum ShortcutCatalog {
    private static func hk(_ s: String) -> Hotkey? { Hotkey.parse(s) }

    public static let all: [ShortcutAction] = [
        // General
        .init("restart-services", "Restart yabai & skhd", "General",
              "yabai --restart-service && skhd --reload", hk("ctrl + alt + cmd - r"), symbol: "arrow.clockwise"),
        .init("toggle-show-desktop", "Show / hide desktop icons", "General",
              "sh ${SCRIPTS}/taggleShowHideDesktop.sh", hk("cmd - f3"), symbol: "eye.slash"),
        .init("close-window", "Close focused window", "General",
              "yabai -m window --close", hk("alt + cmd - backspace"), symbol: "xmark.circle"),
        .init("open-window-menu", "Open window menu", "General",
              "sh ${SCRIPTS}/openWindowMenu.sh", hk("ctrl - 0x2B"),
              symbol: "list.bullet.rectangle"),

        // Shared (floating + tiling)
        .init("toggle-float-center", "Float / unfloat & center", "Shared",
              "yabai -m window --toggle float ; yabai -m window --grid 12:12:1:1:9:9",
              hk("ctrl + alt + cmd - space"), symbol: "macwindow.on.rectangle"),
        .init("send-display-prev", "Send window to previous display", "Shared",
              "sh ${SCRIPTS}/moveWindowToLeft.sh display", hk("ctrl + alt - left"), symbol: "arrow.left.to.line"),
        .init("send-display-next", "Send window to next display", "Shared",
              "sh ${SCRIPTS}/moveWindowToRight.sh display", hk("ctrl + alt - right"), symbol: "arrow.right.to.line"),
        .init("send-space-prev", "Send window to previous space", "Shared",
              "sh ${SCRIPTS}/moveWindowToLeft.sh space", hk("ctrl + cmd - left"), symbol: "arrow.left.square"),
        .init("send-space-next", "Send window to next space", "Shared",
              "sh ${SCRIPTS}/moveWindowToRight.sh space", hk("ctrl + cmd - right"), symbol: "arrow.right.square"),
        .init("send-space-1", "Send window to space 1", "Shared", "sh ${SCRIPTS}/moveWindowToLeft.sh 1", hk("ctrl + cmd - 1"), symbol: "1.square"),
        .init("send-space-2", "Send window to space 2", "Shared", "sh ${SCRIPTS}/moveWindowToLeft.sh 2", hk("ctrl + cmd - 2"), symbol: "2.square"),
        .init("send-space-3", "Send window to space 3", "Shared", "sh ${SCRIPTS}/moveWindowToLeft.sh 3", hk("ctrl + cmd - 3"), symbol: "3.square"),
        .init("send-space-4", "Send window to space 4", "Shared", "sh ${SCRIPTS}/moveWindowToLeft.sh 4", hk("ctrl + cmd - 4"), symbol: "4.square"),
        .init("send-space-5", "Send window to space 5", "Shared", "sh ${SCRIPTS}/moveWindowToLeft.sh 5", hk("ctrl + cmd - 5"), symbol: "5.square"),
        .init("send-space-6", "Send window to space 6", "Shared", "sh ${SCRIPTS}/moveWindowToLeft.sh 6", hk("ctrl + cmd - 6"), symbol: "6.square"),
        .init("send-space-7", "Send window to space 7", "Shared", "sh ${SCRIPTS}/moveWindowToLeft.sh 7", hk("ctrl + cmd - 7"), symbol: "7.square"),
        .init("send-space-8", "Send window to space 8", "Shared", "sh ${SCRIPTS}/moveWindowToLeft.sh 8", hk("ctrl + cmd - 8"), symbol: "8.square"),
        .init("send-space-9", "Send window to space 9", "Shared", "sh ${SCRIPTS}/moveWindowToLeft.sh 9", hk("ctrl + cmd - 9"), symbol: "9.square"),
        .init("focus-left", "Focus / move left (mode-aware)", "Shared",
              "sh ${SCRIPTS}/focusWindow.sh left", hk("alt + cmd - left"), symbol: "chevron.left"),
        .init("focus-right", "Focus / move right (mode-aware)", "Shared",
              "sh ${SCRIPTS}/focusWindow.sh right", hk("alt + cmd - right"), symbol: "chevron.right"),
        .init("focus-up", "Focus / move up (mode-aware)", "Shared",
              "sh ${SCRIPTS}/focusWindow.sh up", hk("alt + cmd - up"), symbol: "chevron.up"),
        .init("focus-down", "Focus / move down (mode-aware)", "Shared",
              "sh ${SCRIPTS}/focusWindow.sh down", hk("alt + cmd - down"), symbol: "chevron.down"),

        // BSP Mode
        .init("balance", "Equalize window sizes", "BSP Mode", "yabai -m space --balance", hk("alt + cmd - 0x2A"), symbol: "equal.square"),
        .init("toggle-fullscreen", "Toggle fullscreen zoom", "BSP Mode",
              "yabai -m window --toggle zoom-fullscreen", hk("alt + cmd - space"), symbol: "arrow.up.left.and.arrow.down.right"),
        .init("toggle-gaps", "Toggle gaps & padding", "BSP Mode",
              "yabai -m space --toggle padding; yabai -m space --toggle gap", hk("alt + cmd - g"), symbol: "squareshape.split.2x2.dotted"),
        .init("rotate-cw", "Rotate clockwise", "BSP Mode", "yabai -m space --rotate 270", hk("alt + cmd - r"), symbol: "rotate.right"),
        .init("rotate-ccw", "Rotate counter-clockwise", "BSP Mode", "yabai -m space --rotate 90", hk("shift + alt + cmd - r"), symbol: "rotate.left"),
        .init("stack-west", "Stack onto window to the left", "BSP Mode",
              "yabai -m window west --stack $(yabai -m query --windows --window | jq -r '.id')",
              hk("shift + alt + cmd - left"), symbol: "arrow.turn.down.left"),
        .init("stack-east", "Stack onto window to the right", "BSP Mode",
              "yabai -m window east --stack $(yabai -m query --windows --window | jq -r '.id')",
              hk("shift + alt + cmd - right"), symbol: "arrow.turn.down.right"),
        .init("focus-stack-prev", "Focus previous in stack", "BSP Mode",
              "yabai -m window --focus stack.prev || yabai -m window --focus stack.last", hk("shift + alt + cmd - up"), symbol: "chevron.up.square"),
        .init("focus-stack-next", "Focus next in stack", "BSP Mode",
              "yabai -m window --focus stack.next || yabai -m window --focus stack.first", hk("shift + alt + cmd - down"), symbol: "chevron.down.square"),
        .init("swap-west", "Swap window left", "BSP Mode", "yabai -m window --swap west", hk("ctrl + alt + cmd - left"), symbol: "rectangle.2.swap"),
        .init("swap-east", "Swap window right", "BSP Mode", "yabai -m window --swap east", hk("ctrl + alt + cmd - right"), symbol: "rectangle.2.swap"),
        .init("swap-north", "Swap window up", "BSP Mode", "yabai -m window --swap north", hk("ctrl + alt + cmd - up"), symbol: "rectangle.2.swap"),
        .init("swap-south", "Swap window down", "BSP Mode", "yabai -m window --swap south", hk("ctrl + alt + cmd - down"), symbol: "rectangle.2.swap"),
        .init("resize-left", "Resize narrower", "BSP Mode",
              "yabai -m window --resize left:-20:0 || yabai -m window --resize right:-20:0", hk("ctrl + alt + cmd - home"), symbol: "arrow.left.and.right.square"),
        .init("resize-right", "Resize wider", "BSP Mode",
              "yabai -m window --resize right:20:0 || yabai -m window --resize left:20:0", hk("ctrl + alt + cmd - end"), symbol: "arrow.left.and.right.square"),
        .init("resize-up", "Resize shorter", "BSP Mode",
              "yabai -m window --resize top:0:-20 || yabai -m window --resize bottom:0:-20", hk("ctrl + alt + cmd - pageup"), symbol: "arrow.up.and.down.square"),
        .init("resize-down", "Resize taller", "BSP Mode",
              "yabai -m window --resize top:0:20 || yabai -m window --resize bottom:0:20", hk("ctrl + alt + cmd - pagedown"), symbol: "arrow.up.and.down.square"),

        // Floating Mode
        .init("grid-top-left", "Move to top-left corner", "Floating Mode", "yabai -m window --grid 2:2:0:0:1:1", hk("alt + cmd - home"), symbol: "arrow.up.left.square"),
        .init("grid-top-right", "Move to top-right corner", "Floating Mode", "yabai -m window --grid 2:2:1:0:1:1", hk("alt + cmd - pageup"), symbol: "arrow.up.right.square"),
        .init("grid-bottom-left", "Move to bottom-left corner", "Floating Mode", "yabai -m window --grid 2:2:0:1:1:1", hk("alt + cmd - pagedown"), symbol: "arrow.down.left.square"),
        .init("grid-bottom-right", "Move to bottom-right corner", "Floating Mode", "yabai -m window --grid 2:2:1:1:1:1", hk("alt + cmd - end"), symbol: "arrow.down.right.square"),
    ]

    public static func action(id: String) -> ShortcutAction? { all.first { $0.id == id } }
}
