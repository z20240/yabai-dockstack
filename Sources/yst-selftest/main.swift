// CLT-compatible self-test (no XCTest). Mirrors the unit tests so the pure
// logic can be verified without a full Xcode install. Exits non-zero on failure.
import Foundation
import CoreGraphics
import AppKit
import YabaiDockstackKit

var failures = 0
func check(_ cond: Bool, _ msg: String) {
    if cond { print("  ok: \(msg)") }
    else { failures += 1; print("  FAIL: \(msg)") }
}

func win(_ id: Int, _ app: String, _ idx: Int, _ frame: YRect, _ focus: Bool = false) -> YabaiWindow {
    YabaiWindow(id: id, pid: id, app: app, title: app, frame: frame,
                display: 1, space: 1, stackIndex: idx, hasFocus: focus)
}

print("YabaiWindow.decodeList")
let json = """
[
  {"id":1,"pid":100,"app":"Code","title":"projA — Visual Studio Code","frame":{"x":0.0,"y":25.0,"w":800.0,"h":900.0},"display":1,"space":1,"stack-index":1,"has-focus":true},
  {"id":2,"pid":101,"app":"Code","title":"projB","frame":{"x":0.0,"y":25.0,"w":800.0,"h":900.0},"display":1,"space":1,"stack-index":2,"has-focus":false},
  {"id":3,"pid":102,"app":"Safari","title":"news","frame":{"x":800.0,"y":25.0,"w":800.0,"h":900.0},"display":1,"space":1,"stack-index":0,"has-focus":false},
  {"id":4,"pid":103,"app":"Broken","frame":{"x":0.0},"display":1,"space":1,"stack-index":0}
]
""".data(using: .utf8)!
let wins = YabaiWindow.decodeList(json)
check(wins.count == 3, "skips malformed entry (count == 3)")
check(wins.first { $0.id == 1 }?.title == "projA — Visual Studio Code", "title decoded")
check(wins.first { $0.id == 1 }?.hasFocus == true, "has-focus decoded")

print("StackBuilder")
let f = YRect(x: 0, y: 25, w: 800, h: 900)
let other = YRect(x: 800, y: 25, w: 800, h: 900)
let stacks = StackBuilder.build([win(2, "Code", 2, f), win(1, "Code", 1, f, true), win(3, "Safari", 0, other)])
check(stacks.count == 1, "one stack built")
check(stacks.first?.windows.map { $0.id } == [1, 2], "sorted by stack index")
check(stacks.first?.isFocused == true, "stack focused")
check(StackBuilder.build([win(1, "A", 0, f), win(2, "B", 0, f)]).isEmpty, "stack-index 0 is not a stack")

print("IndicatorLayout")
let screen = YRect(x: 0, y: 0, w: 1600, h: 1000)
let left = IndicatorLayout.place(stackFrame: YRect(x: 100, y: 50, w: 600, h: 800), screenFrame: screen, cellSize: 32, count: 2, offset: 4)
check(left.side == .left, "left-half window -> left edge")
check(left.panel.x == 100 - 32 - 4, "left x correct")
check(left.panel.h == 64, "panel height = cell*count")
let right = IndicatorLayout.place(stackFrame: YRect(x: 900, y: 50, w: 600, h: 800), screenFrame: screen, cellSize: 32, count: 3, offset: 4)
check(right.side == .right, "right-half window -> right edge")
check(right.panel.x == 900 + 600 + 4, "right x correct")
let full = IndicatorLayout.place(stackFrame: YRect(x: 0, y: 50, w: 1600, h: 800), screenFrame: screen, cellSize: 32, count: 2, offset: 4)
check(full.side == .left, "full-width window defaults to left")
let fullR = IndicatorLayout.place(stackFrame: YRect(x: 0, y: 50, w: 1600, h: 800), screenFrame: screen, cellSize: 32, count: 2, offset: 4, fullWidthSide: .right)
check(fullR.side == .right, "full-width side configurable to right")
// confine-to-gap: window inset by 14px padding on a full-width-ish layout
let gapStack = YRect(x: 14, y: 50, w: 1572, h: 800)  // 14px gap each side
let confined = IndicatorLayout.place(stackFrame: gapStack, screenFrame: screen, cellSize: 32, count: 2, offset: 4, confineToGap: true)
check(confined.panel.w == 14, "confined indicator shrinks to the 14px gap")
check(confined.panel.x == 0, "confined left indicator sits flush in the gap (x=0)")
check(confined.panel.h == 28, "confined height = shrunk cell * count")
let noGap = IndicatorLayout.place(stackFrame: YRect(x: 0, y: 50, w: 1600, h: 800), screenFrame: screen, cellSize: 32, count: 1, offset: 4, confineToGap: true)
check(noGap.panel.w == 32, "no gap -> falls back to full cell (overlap)")

print("IndicatorLayout edgeInset")
let inset = IndicatorLayout.place(stackFrame: YRect(x: 0, y: 50, w: 1600, h: 800),
                                  screenFrame: screen, cellSize: 32, count: 1, offset: 4,
                                  edgeInset: 6)
check(inset.panel.x == 6, "clamped left panel respects edgeInset")

print("ColorHex")
check(NSColor(hex: "#FF0000") != nil, "valid hex parses")
check(NSColor(hex: "nope") == nil, "invalid hex -> nil")
let red = NSColor(hex: "FF0000")?.usingColorSpace(.sRGB)
check(red != nil && abs((red?.redComponent ?? 0) - 1.0) < 0.001 && abs((red?.greenComponent ?? 1)) < 0.001,
      "hex FF0000 -> red")

print("CoordinateMapper")
let c = CoordinateMapper.toCocoa(YRect(x: 100, y: 50, w: 32, h: 64), primaryHeight: 1000)
check(c.origin.x == 100 && c.origin.y == 1000 - 50 - 64, "y flipped about primary height")
let c2 = CoordinateMapper.toCocoa(YRect(x: -1158, y: -1015, w: 100, h: 100), primaryHeight: 1000)
check(c2.origin.x == -1158 && c2.origin.y == 1000 - (-1015) - 100, "negative secondary-display coords preserved")

print("AppConfig")
check(AppConfig.load(from: nil) == AppConfig.defaults, "nil -> defaults")
let partial = AppConfig.load(from: #"{"style":"flag","cellSize":24}"#.data(using: .utf8))
check(partial.style == .flag && partial.cellSize == 24 && partial.offset == AppConfig.defaults.offset, "partial merge over defaults")
check(AppConfig.load(from: "not json".data(using: .utf8)) == AppConfig.defaults, "garbage -> defaults")
let tmp = NSTemporaryDirectory() + "yst-selftest-config.json"
var saved = AppConfig.defaults; saved.style = .flag; saved.save(to: tmp)
check(AppConfig.loadFromFile(tmp).style == .flag, "save/reload round-trips")
try? FileManager.default.removeItem(atPath: tmp)

print("RefreshDiff")
func st(_ key: String, _ ids: [Int], _ focused: Bool) -> Stack {
    let ws = ids.map { win($0, "A", $0, YRect(x: 0, y: 0, w: 1, h: 1), focused && $0 == ids.first) }
    return Stack(frame: YRect(x: 0, y: 0, w: 1, h: 1), display: 1, space: 1, windows: ws, isFocused: focused, key: key)
}
check(RefreshDiff.shouldRedraw(old: [st("k", [1, 2], true)], new: [st("k", [1, 2], true)]) == false, "no change")
check(RefreshDiff.shouldRedraw(old: [st("k", [1, 2], true)], new: [st("k", [1, 2], false)]) == true, "focus change")
check(RefreshDiff.shouldRedraw(old: [st("k", [1, 2], true)], new: [st("k", [1, 2, 3], true)]) == true, "membership change")

print("WindowMenuModel")
let menuWins = [
    YabaiWindow(id: 3, pid: 30, app: "C", title: "c", frame: YRect(x: 0, y: 0, w: 1, h: 1), display: 2, space: 5, stackIndex: 1, hasFocus: false),
    YabaiWindow(id: 1, pid: 10, app: "A", title: "a", frame: YRect(x: 0, y: 0, w: 1, h: 1), display: 1, space: 1, stackIndex: 2, hasFocus: false),
    YabaiWindow(id: 2, pid: 20, app: "B", title: "b", frame: YRect(x: 0, y: 0, w: 1, h: 1), display: 1, space: 1, stackIndex: 1, hasFocus: true),
]
let menuGroups = WindowMenuModel.build(menuWins)
check(menuGroups.map { $0.display } == [1, 2], "menu grouped by display, sorted")
check(menuGroups[0].spaces[0].windows.map { $0.id } == [2, 1], "windows ordered by stack index")
check(menuGroups[0].spaces[0].windows[0].pid == 20, "entry carries pid for icon")
let labeled = WindowMenuModel.build(menuWins, spaceLabels: [1: "work"])
check(labeled[0].spaces[0].name == "work", "space name uses custom label when set")
check(labeled[1].spaces[0].name == "Space 5", "space name falls back to index")

print("VisibleSpaceFilter")
let vsfWins = [
    YabaiWindow(id: 1, pid: 1, app: "A", title: "t", frame: YRect(x: 0, y: 0, w: 1, h: 1), display: 1, space: 11, stackIndex: 1, hasFocus: false, isVisible: true),
    YabaiWindow(id: 2, pid: 2, app: "A", title: "t", frame: YRect(x: 0, y: 0, w: 1, h: 1), display: 1, space: 11, stackIndex: 2, hasFocus: false, isVisible: false),
    YabaiWindow(id: 3, pid: 3, app: "B", title: "t", frame: YRect(x: 0, y: 0, w: 1, h: 1), display: 1, space: 5, stackIndex: 1, hasFocus: false, isVisible: false),
]
check(Set(VisibleSpaceFilter.apply(vsfWins).map { $0.id }) == [1, 2],
      "keeps occluded stack members on visible space, drops hidden-space windows")

print("YabaiLocator")
check(YabaiLocator.detect(candidates: ["/no/a", "/no/b"], exists: { _ in false }) == nil,
      "no candidate exists -> nil")
check(YabaiLocator.detect(candidates: ["/no/a", "/yes/b", "/yes/c"],
                          exists: { $0.hasPrefix("/yes") }) == "/yes/b",
      "returns first existing candidate")

print("SignalInstaller")
let specs = SignalInstaller.specs(appBinaryPath: "/Apps/yst.app/Contents/MacOS/yst")
check(specs.count == SignalInstaller.events.count, "one spec per event")
check(specs.first?.label == "yabai-dockstack-window_focused", "label derived from event")
check(specs.first?.action == "\"/Apps/yst.app/Contents/MacOS/yst\" --refresh",
      "action quotes binary path and adds --refresh")

// Socket round-trip: start a listener, send a poke, confirm the callback fires.
print("Socket round-trip")
do {
    let sockPath = NSTemporaryDirectory() + "yst-selftest.sock"
    var poked = false
    let listener = SignalListener(socketPath: sockPath) { poked = true }
    listener.start()
    Thread.sleep(forTimeInterval: 0.1)  // let bind/listen settle
    RefreshClient.sendPoke(socketPath: sockPath)
    // onPoke dispatches to main; pump the main runloop briefly.
    let deadline = Date().addingTimeInterval(2.0)
    while !poked && Date() < deadline {
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }
    listener.stop()
    check(poked, "poke delivered through unix socket to listener callback")
}

// Optional: decode a real `yabai -m query --windows` dump passed as argv[1].
if CommandLine.arguments.count > 1 {
    let path = CommandLine.arguments[1]
    print("Live decode: \(path)")
    let data = (try? Data(contentsOf: URL(fileURLWithPath: path))) ?? Data()
    let liveWins = YabaiWindow.decodeList(data)
    let liveStacks = StackBuilder.build(liveWins)
    check(!liveWins.isEmpty, "live query decoded \(liveWins.count) windows")
    print("  info: \(liveStacks.count) stack(s) detected")
    for s in liveStacks {
        print("    stack \(s.key): \(s.windows.map { "\($0.app)#\($0.stackIndex)" }.joined(separator: ", "))")
    }
}

// Live signal install/uninstall against the real yabai (with cleanup).
// Run: swift run yst-selftest --live-signals
if CommandLine.arguments.contains("--live-signals") {
    print("Live signal install/uninstall")
    if let yabai = YabaiLocator.detect() {
        let client = YabaiClient(yabaiPath: yabai)
        SignalInstaller.install(client: client, appBinaryPath: "/tmp/yst-selftest-binary")
        check(SignalInstaller.isInstalled(client: client), "signals registered with real yabai")
        SignalInstaller.uninstall(client: client)
        check(!SignalInstaller.isInstalled(client: client), "signals cleaned up")
    } else {
        print("  skip: yabai not found")
    }
}

print("AppWindowGrouper")
let agWins = [
    YabaiWindow(id: 3, pid: 3, app: "Cursor", title: "t", frame: YRect(x: 0, y: 0, w: 1, h: 1), display: 1, space: 10, stackIndex: 1, hasFocus: false),
    YabaiWindow(id: 1, pid: 1, app: "Cursor", title: "t", frame: YRect(x: 0, y: 0, w: 1, h: 1), display: 1, space: 2, stackIndex: 2, hasFocus: false),
    YabaiWindow(id: 2, pid: 2, app: "Cursor", title: "t", frame: YRect(x: 0, y: 0, w: 1, h: 1), display: 1, space: 2, stackIndex: 1, hasFocus: false),
    YabaiWindow(id: 9, pid: 9, app: "Safari", title: "t", frame: YRect(x: 0, y: 0, w: 1, h: 1), display: 1, space: 2, stackIndex: 1, hasFocus: false),
]
check(AppWindowGrouper.windows(of: "Cursor", in: agWins).map { $0.id } == [2, 1, 3],
      "AppWindowGrouper filters by app and sorts by space/stack")

print("ThumbnailCache")
let tcache = ThumbnailCache(limit: 2)
let cgctx = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let oneImg = cgctx.makeImage()!
tcache.put(1, oneImg); tcache.put(2, oneImg); _ = tcache.get(1); tcache.put(3, oneImg)
check(tcache.contains(1) && !tcache.contains(2) && tcache.contains(3), "ThumbnailCache evicts LRU")

print("ManagedRegion")
let mrOut = ManagedRegion.replace(in: "echo hi\n", with: "A\nB")
check(ManagedRegion.extract(from: mrOut) == "A\nB", "extract round-trips appended body")
check(mrOut.hasPrefix("echo hi\n"), "freeform preserved before region")
let mr2 = ManagedRegion.replace(in: mrOut + "AFTER\n", with: "C")
check(mr2.hasSuffix("AFTER\n"), "freeform preserved after region")
check(ManagedRegion.extract(from: mr2) == "C", "region body replaced")
check(ManagedRegion.extract(from: "no markers") == nil, "nil when no markers")

print("")
if failures == 0 { print("ALL SELF-TESTS PASSED") }
else { print("\(failures) SELF-TEST(S) FAILED"); exit(1) }
