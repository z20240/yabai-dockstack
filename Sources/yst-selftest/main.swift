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
  {"id":2,"pid":101,"app":"Code","title":"projB","frame":{"x":0.0,"y":25.0,"w":800.0,"h":900.0},"display":1,"space":1,"stack-index":2,"has-focus":false,"is-floating":true},
  {"id":3,"pid":102,"app":"Safari","title":"news","frame":{"x":800.0,"y":25.0,"w":800.0,"h":900.0},"display":1,"space":1,"stack-index":0,"has-focus":false},
  {"id":4,"pid":103,"app":"Broken","frame":{"x":0.0},"display":1,"space":1,"stack-index":0}
]
""".data(using: .utf8)!
let wins = YabaiWindow.decodeList(json)
check(wins.count == 3, "skips malformed entry (count == 3)")
check(wins.first { $0.id == 1 }?.title == "projA — Visual Studio Code", "title decoded")
check(wins.first { $0.id == 1 }?.hasFocus == true, "has-focus decoded")
check(wins.first { $0.id == 2 }?.isFloating == true, "is-floating decoded")
check(wins.first { $0.id == 1 }?.isFloating == false, "is-floating defaults to false when key missing")
check(YabaiWindow.decodeList(#"[{"id":5,"pid":1,"app":"G","frame":{"x":0,"y":0,"w":1,"h":1},"display":1,"space":2,"stack-index":0,"has-focus":false,"is-sticky":true}]"#.data(using: .utf8)!).first?.isSticky == true,
      "is-sticky decoded")
check(wins.first { $0.id == 1 }?.isSticky == false, "is-sticky defaults to false when key missing")

print("StackBuilder")
let f = YRect(x: 0, y: 25, w: 800, h: 900)
let other = YRect(x: 800, y: 25, w: 800, h: 900)
let stacks = StackBuilder.build([win(2, "Code", 2, f), win(1, "Code", 1, f, true), win(3, "Safari", 0, other)])
check(stacks.count == 1, "one stack built")
check(stacks.first?.windows.map { $0.id } == [1, 2], "sorted by stack index")
check(stacks.first?.isFocused == true, "stack focused")
check(StackBuilder.build([win(1, "A", 0, f), win(2, "B", 0, f)]).isEmpty, "stack-index 0 is not a stack")
func spaceWin(_ id: Int, _ space: Int, _ idx: Int) -> YabaiWindow {
    YabaiWindow(id: id, pid: id, app: "A", title: "A", frame: f, display: 1, space: space, stackIndex: idx, hasFocus: false)
}
check(StackBuilder.build([spaceWin(1, 1, 1), spaceWin(2, 1, 2)]).first?.key
      != StackBuilder.build([spaceWin(3, 2, 1), spaceWin(4, 2, 2)]).first?.key,
      "same-frame stacks on different spaces get distinct keys")

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
check(!AppConfig.load(from: #"{"style":"flag"}"#.data(using: .utf8)).indicatorClickThrough,
      "indicatorClickThrough defaults off for existing configs")
check(AppConfig.load(from: #"{"indicatorClickThrough":true}"#.data(using: .utf8)).indicatorClickThrough,
      "indicatorClickThrough loads from config")
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
let stickyWin = YabaiWindow(id: 9, pid: 9, app: "S", title: "t", frame: YRect(x: 0, y: 0, w: 1, h: 1), display: 1, space: 5, stackIndex: 0, hasFocus: false, isVisible: true, isFloating: true, isSticky: true)
check(Set(VisibleSpaceFilter.apply(vsfWins + [stickyWin]).map { $0.id }) == [1, 2],
      "sticky window does not mark its reported (hidden) space visible")

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

print("Hotkey")
check(Hotkey.parse("alt + cmd - left") == Hotkey(mods: [.alt, .cmd], key: "left"), "parse basic")
let hk = Hotkey(mods: [.cmd, .alt, .shift], key: "r")
check(hk.skhdString == "shift + alt + cmd - r", "canonical order output")
check(Hotkey.parse(hk.skhdString) == hk, "round-trips")
check(Hotkey.parse("alt + cmd - 0x2A")?.skhdString == "alt + cmd - 0x2A", "keycode preserved")
check(Hotkey.parse("cmd -") == nil, "empty key -> nil")
check(Hotkey(mods: [.cmd, .alt], key: "left").displayString == "⌥⌘←", "display glyphs")

print("YabaiManagedConfig")
var ys = YabaiSettings.defaults
ys.rules = [WindowRule(app: "Finder", mode: .float), WindowRule(app: "iTerm2", mode: .manage)]
let yText = YabaiManagedConfig.generate(ys)
check(yText.contains("yabai -m config layout bsp"), "layout emitted")
check(yText.contains(#"app="Finder" manage=off"#), "float rule -> manage=off")
check(yText.contains(#"app="iTerm2" manage=on"#), "manage rule -> manage=on")
check(YabaiManagedConfig.parse(yText) == ys, "yabai settings round-trip")
var floatMode = YabaiSettings.defaults; floatMode.layout = .float
floatMode.rules = [WindowRule(app: "Finder", mode: .float)]
let floatText = YabaiManagedConfig.generate(floatMode)
check(floatText.contains(#"app=".*" manage=off"#), "float emits global manage=off catch-all (floats all windows)")
check(YabaiManagedConfig.parse(floatText) == floatMode, "float round-trips (.float + real rules, synthetic .* skipped)")
var off = YabaiSettings.defaults; off.layout = .off
off.rules = [WindowRule(app: "Finder", mode: .float)]
let offText = YabaiManagedConfig.generate(off)
check(offText.contains("yabai -m config layout float"), "off emits float layout")
check(!offText.contains(#"app=".*""#), "off has no synthetic catch-all (native feel)")
check(YabaiManagedConfig.parse(offText) == off, "off round-trips")
check(YabaiManagedConfig.parse("") == YabaiSettings.defaults, "empty -> defaults")

print("ShortcutCatalog")
let ids = ShortcutCatalog.all.map { $0.id }
check(Set(ids).count == ids.count, "catalog ids unique")
check(ShortcutCatalog.all.allSatisfy { ShortcutGroup.order.contains($0.group) }, "all groups known")
check(ShortcutCatalog.action(id: "stack-west") != nil, "stack-west present")
let hkX = Hotkey(mods: [.cmd], key: "x")
let conf = ShortcutConflicts.find([
    ShortcutBinding(actionID: "a", enabled: true, hotkey: hkX),
    ShortcutBinding(actionID: "b", enabled: true, hotkey: hkX),
    ShortcutBinding(actionID: "d", enabled: false, hotkey: hkX),
])
check(conf[hkX].map { Set($0) } == Set(["a", "b"]), "conflict finds enabled pair, ignores disabled")

print("SkhdManagedConfig")
let sb = [
    ShortcutBinding(actionID: "focus-left", enabled: true, hotkey: Hotkey(mods: [.alt, .cmd], key: "left")),
    ShortcutBinding(actionID: "balance", enabled: true, hotkey: Hotkey(mods: [.alt, .cmd], key: "0x2A")),
    ShortcutBinding(actionID: "rotate-cw", enabled: false, hotkey: Hotkey(mods: [.alt, .cmd], key: "r")),
]
let sText = SkhdManagedConfig.generate(sb, catalog: ShortcutCatalog.all, scriptsDir: "/S")
check(sText.contains("alt + cmd - 0x2A : yabai -m space --balance"), "binding line emitted")
check(!sText.contains("rotate"), "disabled binding skipped")
let sbParsed = SkhdManagedConfig.parse(sText, catalog: ShortcutCatalog.all, scriptsDir: "/S")
check(sbParsed == sb.filter { $0.enabled }, "skhd round-trip (enabled subset)")
check(SkhdManagedConfig.generate(
    [ShortcutBinding(actionID: "toggle-show-desktop", enabled: true, hotkey: Hotkey(mods: [.cmd], key: "f3"))],
    catalog: ShortcutCatalog.all, scriptsDir: "/opt/s").contains("/opt/s/taggleShowHideDesktop.sh"),
    "script token substituted")

print("ConfigPaths")
let tmpDir = NSTemporaryDirectory() + "yst-paths/"
try? FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
let existing = tmpDir + "b"
FileManager.default.createFile(atPath: existing, contents: Data())
check(ConfigPaths.resolve(candidates: [tmpDir + "a", existing]) == existing, "picks first existing")
check(ConfigPaths.resolve(candidates: ["~/.nope-xyz"]) == ("~/.nope-xyz" as NSString).expandingTildeInPath, "falls back to first")

print("ConfigFileWriter")
let wPath = NSTemporaryDirectory() + "yst-writer.rc"
try? "echo freeform\n".write(toFile: wPath, atomically: true, encoding: .utf8)
let writer = ConfigFileWriter(path: wPath)
try? writer.writeManagedRegion("LINE1")
let wOut = (try? String(contentsOfFile: wPath, encoding: .utf8)) ?? ""
check(wOut.contains("echo freeform"), "freeform preserved on write")
check(ManagedRegion.extract(from: wOut) == "LINE1", "region written")
try? writer.writeManagedRegion("LINE2")
check(ManagedRegion.extract(from: (try? String(contentsOfFile: wPath, encoding: .utf8)) ?? "") == "LINE2", "region replaced not appended")
try? writer.restoreBackup()
check(((try? String(contentsOfFile: wPath, encoding: .utf8)) ?? "").contains("LINE1"), "restore brings back prior (pre-LINE2) state")
try? FileManager.default.removeItem(atPath: wPath)
try? FileManager.default.removeItem(atPath: writer.backupPath)

print("ScriptInstaller")
let sDir = NSTemporaryDirectory() + "yst-scripts/"
do {
    try ScriptInstaller.install(to: sDir)
    check(ScriptInstaller.scriptNames.allSatisfy { FileManager.default.fileExists(atPath: sDir + $0) },
          "all scripts installed")
} catch { check(false, "ScriptInstaller.install threw: \(error)") }
try? FileManager.default.removeItem(atPath: sDir)

print("DefaultTemplate")
check(DefaultTemplate.defaultBindings().count == ShortcutCatalog.all.count, "default bindings cover catalog")
check(DefaultTemplate.defaultYabaiSettings().rules.contains { $0.app == "Finder" }, "default rules include Finder")
let tPath = NSTemporaryDirectory() + "yst-tmpl.rc"
try? FileManager.default.removeItem(atPath: tPath)
let tw = ConfigFileWriter(path: tPath)
check(DefaultTemplate.ensureManagedRegion(in: tw, body: "SEED") == true, "seeds when no region")
check(DefaultTemplate.ensureManagedRegion(in: tw, body: "X") == false, "adopts when region exists")
check(ManagedRegion.extract(from: tw.currentText()) == "SEED", "seed body preserved on adopt")
try? FileManager.default.removeItem(atPath: tPath)
try? FileManager.default.removeItem(atPath: tw.backupPath)

print("ConfigEngine")
let engY = NSTemporaryDirectory() + "yst-eng.rc"
try? FileManager.default.removeItem(atPath: engY)
let eng = ConfigEngine(yabaiPath: "/usr/bin/true", skhdPath: "/usr/bin/true",
                       yabaiConfigPath: engY, skhdConfigPath: engY + ".s", scriptsDir: "/S")
var es = DefaultTemplate.defaultYabaiSettings(); es.gap = 17
eng.manageYabaiConfig = true
try? eng.saveYabai(es)
check(eng.loadYabaiSettings().gap == 17, "engine yabai round-trip")
eng.manageSkhdConfig = true
try? eng.saveSkhd([ShortcutBinding(actionID: "balance", enabled: true, hotkey: Hotkey(mods: [.alt, .cmd], key: "0x2A"))])
let lb = eng.loadBindings()
check(lb.count == ShortcutCatalog.all.count, "loadBindings returns a row per action")
check(lb.first { $0.actionID == "balance" }?.enabled == true, "saved binding enabled")
check(lb.first { $0.actionID == "rotate-cw" }?.enabled == false, "unsaved binding is disabled row")
check(eng.applyYabai().ok, "applyYabai runs (/bin/true)")
try? FileManager.default.removeItem(atPath: engY)
try? FileManager.default.removeItem(atPath: engY + ".s")

// Fix D: .float layout round-trip
print("YabaiManagedConfig float round-trip")
do {
    var floatS = YabaiSettings.defaults; floatS.layout = .float
    check(YabaiManagedConfig.parse(YabaiManagedConfig.generate(floatS)) == floatS, ".float layout round-trips")
}

// Fix D: enabled+nil-hotkey excluded from conflicts
print("ShortcutConflicts nil-hotkey exclusion")
do {
    let hkNil = Hotkey(mods: [.cmd], key: "x")
    let nilBindings = [
        ShortcutBinding(actionID: "a", enabled: true, hotkey: hkNil),
        ShortcutBinding(actionID: "x", enabled: true, hotkey: nil),
    ]
    let nilConflicts = ShortcutConflicts.find(nilBindings)
    check(nilConflicts[hkNil] == nil, "single hotkey binding with nil-hotkey sibling is not a conflict")
    check(!nilConflicts.values.flatMap { $0 }.contains("x"), "nil-hotkey binding absent from conflicts output")
}

// Fix D: restoreBackup throws when no backup exists
print("ConfigFileWriter restoreBackup no-bak throws")
do {
    let noBackupWriter = ConfigFileWriter(path: NSTemporaryDirectory() + "yst-no-bak-\(Int.random(in: 1000...9999)).rc")
    var didThrow = false
    do { try noBackupWriter.restoreBackup() } catch { didThrow = true }
    check(didThrow, "restoreBackup throws when no .bak file exists")
}

// Fix D: shipped defaults do not self-conflict
print("DefaultTemplate no self-conflict")
check(ShortcutConflicts.find(DefaultTemplate.defaultBindings()).isEmpty, "default bindings have no hotkey conflicts")

// Fix B: loadBindings survives duplicate-actionID region
print("ConfigEngine duplicate-actionID region survives")
do {
    let dupPath = NSTemporaryDirectory() + "yst-dup-\(Int.random(in: 1000...9999)).rc"
    let dupBody = "alt + cmd - 0x2A : yabai -m space --balance\nctrl - b : yabai -m space --balance"
    let dupText = ManagedRegion.replace(in: "", with: dupBody)
    try? dupText.write(toFile: dupPath, atomically: true, encoding: .utf8)
    let dupEng = ConfigEngine(yabaiPath: "/usr/bin/true", skhdPath: "/usr/bin/true",
                              yabaiConfigPath: dupPath + ".y", skhdConfigPath: dupPath, scriptsDir: "/S")
    let dupLoaded = dupEng.loadBindings()
    check(dupLoaded.count == ShortcutCatalog.all.count, "loadBindings with duplicate-actionID region returns row per action")
    check(dupLoaded.first { $0.actionID == "balance" }?.enabled == true, "balance enabled despite duplicate binding")
    try? FileManager.default.removeItem(atPath: dupPath)
}

// Fix C: hasMalformedMarkers
print("ManagedRegion hasMalformedMarkers")
do {
    let twoBegins = ManagedRegion.beginLine + "\nFREEFORM-A\n" + ManagedRegion.beginLine + "\nX\n" + ManagedRegion.endLine + "\n"
    check(ManagedRegion.hasMalformedMarkers(in: twoBegins), "two BEGIN markers -> malformed")
    let endFirst = ManagedRegion.endLine + "\n" + ManagedRegion.beginLine + "\n"
    check(ManagedRegion.hasMalformedMarkers(in: endFirst), "END before BEGIN -> malformed")
    check(!ManagedRegion.hasMalformedMarkers(in: ""), "empty -> not malformed")
    let cleanRegion = ManagedRegion.replace(in: "", with: "BODY")
    check(!ManagedRegion.hasMalformedMarkers(in: cleanRegion), "one ordered pair -> not malformed")
}

// Fix C: writeManagedRegion throws and preserves content on malformed markers
print("ConfigFileWriter refuses malformed-marker file")
do {
    let mPath = NSTemporaryDirectory() + "yst-malformed-\(Int.random(in: 1000...9999)).rc"
    let malformed = ManagedRegion.beginLine + "\nFREEFORM-A\n" + ManagedRegion.beginLine + "\nX\n" + ManagedRegion.endLine + "\n"
    try? malformed.write(toFile: mPath, atomically: true, encoding: .utf8)
    let mWriter = ConfigFileWriter(path: mPath)
    var mDidThrow = false
    do { try mWriter.writeManagedRegion("NEW") } catch { mDidThrow = true }
    check(mDidThrow, "writeManagedRegion throws on malformed markers")
    let mAfter = (try? String(contentsOfFile: mPath, encoding: .utf8)) ?? ""
    check(mAfter.contains("FREEFORM-A"), "freeform preserved after refused write")
    try? FileManager.default.removeItem(atPath: mPath)
}

print("ConfigEngine seed-aware")
let edPath = NSTemporaryDirectory() + "yst-eng-def.rc"
try? FileManager.default.removeItem(atPath: edPath)
try? FileManager.default.removeItem(atPath: edPath + ".s")
let ed = ConfigEngine(yabaiPath: "/usr/bin/true", skhdPath: "/usr/bin/true",
                      yabaiConfigPath: edPath, skhdConfigPath: edPath + ".s", scriptsDir: "/S")
check(ed.hasYabaiRegion() == false, "no yabai region on fresh file")
check(ed.loadYabaiSettingsOrDefault().rules.contains { $0.app == "Finder" }, "or-default uses curated yabai default")
check(ed.loadBindingsOrDefault().allSatisfy { $0.enabled }, "or-default bindings all enabled")
var eds = YabaiSettings.defaults; eds.gap = 99
ed.manageYabaiConfig = true
try? ed.saveYabai(eds)
check(ed.hasYabaiRegion() == true, "region present after save")
check(ed.loadYabaiSettingsOrDefault().gap == 99, "or-default uses region when present")
try? FileManager.default.removeItem(atPath: edPath)
try? FileManager.default.removeItem(atPath: edPath + ".s")

print("KeyCodeMap")
check(KeyCodeMap.skhdKey(forKeyCode: 0x7B, chars: nil) == "left", "keycode 0x7B -> left")
check(KeyCodeMap.skhdKey(forKeyCode: 0x31, chars: " ") == "space", "keycode 0x31 -> space")
check(KeyCodeMap.skhdKey(forKeyCode: 0x0F, chars: "R") == "r", "letter lowercased from chars")
check(KeyCodeMap.skhdKey(forKeyCode: 0x2A, chars: "|") == "0x2A", "unknown -> hex fallback (uppercase)")
check(KeyCodeMap.skhdKey(forKeyCode: 0x63, chars: nil) == "f3", "keycode 0x63 -> f3")
check(KeyCodeMap.skhdKey(forKeyCode: 0x2B, chars: ",") == "0x2B", "hex keycodes emit uppercase (skhd requirement)")

print("ShortcutSections")
let secs = ShortcutSections.build(DefaultTemplate.defaultBindings())
check(secs.map { $0.group } == ShortcutGroup.order, "sections in group order")
check(secs.reduce(0) { $0 + $1.rows.count } == ShortcutCatalog.all.count, "rows cover catalog")
check(ShortcutSections.build([]).flatMap { $0.rows }.allSatisfy { !$0.binding.enabled && $0.binding.hotkey == nil }, "missing -> disabled+unbound rows")
let chk = Hotkey(mods: [.alt, .cmd], key: "x")
check(ShortcutSections.conflictingActionIDs([
    ShortcutBinding(actionID: "balance", enabled: true, hotkey: chk),
    ShortcutBinding(actionID: "toggle-fullscreen", enabled: true, hotkey: chk),
]) == Set(["balance", "toggle-fullscreen"]), "conflicting action ids")

print("FreeformImporter helpers")
check(FreeformImporter.normalizeCommand("sh ~/.config/yabai/scripts/focusWindow.sh left")
      == "sh @S@focusWindow.sh left", "normalize collapses tilde script dir")
check(FreeformImporter.normalizeCommand("sh ${SCRIPTS}/focusWindow.sh left")
      == "sh @S@focusWindow.sh left", "normalize collapses ${SCRIPTS}")
check(FreeformImporter.parseSkhdLine("cmd - f3: sh x")?.hotkey == Hotkey(mods: [.cmd], key: "f3"),
      "parseSkhdLine lenient colon")
check(FreeformImporter.parseSkhdLine("# comment") == nil, "parseSkhdLine skips comments")
check(FreeformImporter.parseSkhdLine("cmd - n : a && \\") == nil, "parseSkhdLine skips continuation")
check(FreeformImporter.parseSkhdLine("shift + cmd - g : yabai -m window --grid 2:2:0:0:1:1")?.command == "yabai -m window --grid 2:2:0:0:1:1", "parseSkhdLine keeps colon in command (split on first colon)")

print("FreeformImporter.importSkhd")
let skFile = "cmd - f3: sh ~/.config/yabai/scripts/taggleShowHideDesktop.sh\ncmd - x : custom jq thing\n"
let skRes = FreeformImporter.importSkhd(fileText: skFile,
    current: [ShortcutBinding(actionID: "toggle-show-desktop", enabled: true, hotkey: Hotkey(mods: [.cmd], key: "4"))],
    catalog: ShortcutCatalog.all, scriptsDir: "/Users/me/.config/yabai-dockstack/scripts")
check(skRes.importedCount == 1, "importSkhd matches one binding")
check(skRes.bindings.first { $0.actionID == "toggle-show-desktop" }?.hotkey == Hotkey(mods: [.cmd], key: "f3"),
      "importSkhd: imported value wins")
check(skRes.newText.contains("# [yabai-dockstack imported] cmd - f3:"), "importSkhd comments matched line")
check(skRes.newText.contains("cmd - x : custom jq thing"), "importSkhd leaves unmatched line")

print("FreeformImporter.importYabai")
let ybFile = "yabai -m config layout bsp\nyabai -m config window_gap 6\nyabai -m rule --add app=\"Finder\" manage=off sub-layer=normal\nyabai -m rule --add app=\".*\" sub-layer=normal\necho done\n"
let ybRes = FreeformImporter.importYabai(fileText: ybFile, current: YabaiSettings.defaults)
check(ybRes.settings.layout == .bsp && ybRes.settings.gap == 6, "importYabai reads layout/gap")
check(ybRes.settings.rules == [WindowRule(app: "Finder", mode: .float)], "importYabai imports Finder, skips .*")
check(ybRes.importedCount == 3, "importYabai count (layout, gap, Finder)")
check(ybRes.newText.contains("echo done"), "importYabai leaves shell untouched")
let ybOff = FreeformImporter.importYabai(fileText: "yabai -m config layout off\nyabai -m config layout stack", current: YabaiSettings.defaults)
check(ybOff.importedCount == 0 && ybOff.settings.layout == YabaiSettings.defaults.layout, "importYabai skips layout off/stack")
let ybDup = FreeformImporter.importYabai(fileText: "yabai -m rule --add app=\"Finder\" manage=off sub-layer=normal\nyabai -m rule --add app=\"Finder\" manage=on sub-layer=normal", current: YabaiSettings.defaults)
check(ybDup.settings.rules == [WindowRule(app: "Finder", mode: .manage)], "importYabai rule de-dupe later wins")

print("ConfigEngine import")
let impP = NSTemporaryDirectory() + "yst-imp.skhdrc"
try? "cmd - f3: sh ~/.config/yabai/scripts/taggleShowHideDesktop.sh\n".write(toFile: impP, atomically: true, encoding: .utf8)
let impE = ConfigEngine(yabaiPath: "/usr/bin/true", skhdPath: "/usr/bin/true",
                        yabaiConfigPath: impP + ".y", skhdConfigPath: impP,
                        scriptsDir: "/Users/me/.config/yabai-dockstack/scripts")
impE.manageSkhdConfig = true
check((try? impE.importSkhd()) == 1, "engine importSkhd migrates one binding")
let impText = (try? String(contentsOfFile: impP, encoding: .utf8)) ?? ""
check(impText.contains("# [yabai-dockstack imported] cmd - f3:"), "engine import comments original")
check(ManagedRegion.extract(from: impText) != nil, "engine import creates managed region")
check(impE.loadBindings().first { $0.actionID == "toggle-show-desktop" }?.hotkey == Hotkey(mods: [.cmd], key: "f3"),
      "engine import: action now bound to imported key")
try? FileManager.default.removeItem(atPath: impP)
try? FileManager.default.removeItem(atPath: impP + ".bak")
try? FileManager.default.removeItem(atPath: impP + ".y")

let impY = NSTemporaryDirectory() + "yst-impy.yabairc"
try? FileManager.default.removeItem(atPath: impY)
try? "yabai -m config window_gap 7\n".write(toFile: impY, atomically: true, encoding: .utf8)
let impYE = ConfigEngine(yabaiPath: "/usr/bin/true", skhdPath: "/usr/bin/true",
                         yabaiConfigPath: impY, skhdConfigPath: impY + ".s", scriptsDir: "/S")
impYE.manageYabaiConfig = true
check((try? impYE.importYabai()) == 1, "engine importYabai migrates one setting")
check(impYE.loadYabaiSettings().gap == 7, "engine importYabai: gap reflects imported value")
try? FileManager.default.removeItem(atPath: impY)
try? FileManager.default.removeItem(atPath: impY + ".bak")

let idemP = NSTemporaryDirectory() + "yst-imp-idem.skhdrc"
try? "cmd - f3: sh ~/.config/yabai/scripts/taggleShowHideDesktop.sh\n".write(toFile: idemP, atomically: true, encoding: .utf8)
let idemE = ConfigEngine(yabaiPath: "/usr/bin/true", skhdPath: "/usr/bin/true",
                         yabaiConfigPath: idemP + ".y", skhdConfigPath: idemP,
                         scriptsDir: "/Users/me/.config/yabai-dockstack/scripts")
idemE.manageSkhdConfig = true
_ = try? idemE.importSkhd()
check((try? idemE.importSkhd()) == 0, "importSkhd idempotent (second run imports nothing)")
try? FileManager.default.removeItem(atPath: idemP)
try? FileManager.default.removeItem(atPath: idemP + ".bak")

print("Shortcut symbols")
check(ShortcutCatalog.all.allSatisfy { !$0.symbol.isEmpty }, "every action has a symbol")
let badSymbols = ShortcutCatalog.all.filter {
    NSImage(systemSymbolName: $0.symbol, accessibilityDescription: nil) == nil
}.map(\.id)
check(badSymbols.isEmpty, "all SF Symbol names valid (bad: \(badSymbols))")

print("SpaceTravelPlanner")
let stpSpaces: [SpaceInfo] = [
    SpaceInfo(index: 1, display: 1, isVisible: false), SpaceInfo(index: 2, display: 1, isVisible: true),
    SpaceInfo(index: 3, display: 1, isVisible: false), SpaceInfo(index: 4, display: 1, isVisible: false),
    SpaceInfo(index: 5, display: 1, isVisible: false),
    SpaceInfo(index: 6, display: 2, isVisible: false), SpaceInfo(index: 7, display: 2, isVisible: true),
    SpaceInfo(index: 8, display: 2, isVisible: false),
]
let stpDisplays: [DisplayInfo] = [
    DisplayInfo(index: 1, frame: YRect(x: 0, y: 0, w: 1728, h: 1117)),
    DisplayInfo(index: 2, frame: YRect(x: -942, y: -1080, w: 1920, h: 1080)),
]
check(SpaceTravelPlanner.plan(target: .next, windowSpace: 2, windowDisplay: 1,
                              spaces: stpSpaces, displays: stpDisplays)
      == TravelPlan(steps: [.arrowWalk(direction: .right, count: 1)], sourceSpace: 2, targetSpace: 3),
      "next on same display = one right step")
check(SpaceTravelPlanner.plan(target: .next, windowSpace: 5, windowDisplay: 1,
                              spaces: stpSpaces, displays: stpDisplays)
      == TravelPlan(steps: [.arrowWalk(direction: .left, count: 4)], sourceSpace: 5, targetSpace: 1),
      "next at right edge wraps by walking left")
check(SpaceTravelPlanner.plan(target: .index(8), windowSpace: 2, windowDisplay: 1,
                              spaces: stpSpaces, displays: stpDisplays)
      == TravelPlan(steps: [.moveToDisplay(display: 2, x: -942 + 1920 / 4, y: -1080 + 1080 / 4),
                            .arrowWalk(direction: .right, count: 1)],
                    sourceSpace: 2, targetSpace: 8),
      "cross-display: move to display then walk from its visible space")
check(SpaceTravelPlanner.plan(target: .index(2), windowSpace: 2, windowDisplay: 1,
                              spaces: stpSpaces, displays: stpDisplays) == nil,
      "target == current -> nil")
check(SpaceTarget.parse("prev") == .prev && SpaceTarget.parse("7") == .index(7)
      && SpaceTarget.parse("0") == nil && SpaceTarget.parse("bogus") == nil,
      "SpaceTarget.parse")
check(SpaceInfo.decodeList("""
[{"index":1,"display":2,"is-visible":true}]
""".data(using: .utf8)!) == [SpaceInfo(index: 1, display: 2, isVisible: true)],
      "SpaceInfo.decodeList")

print("SpaceMover.liftDetected")
let liftBase = YRect(x: 100, y: 50, w: 800, h: 600)
check(!SpaceMover.liftDetected(before: liftBase, after: liftBase), "no drift -> not lifted")
check(!SpaceMover.liftDetected(before: liftBase, after: YRect(x: 101, y: 51, w: 800, h: 600)),
      "sub-threshold drift -> not lifted")
check(SpaceMover.liftDetected(before: liftBase, after: YRect(x: 110, y: 55, w: 800, h: 600)),
      "jiggle drift -> lifted")
print("GrabPointPlanner")
let gpFrame = YRect(x: 100, y: 50, w: 1200, h: 800)
let gpPoints = GrabPointPlanner.candidates(frame: gpFrame)
check(gpPoints.count >= 3 && gpPoints.allSatisfy { $0.y == 58 && $0.x >= 240 && $0.x <= 1210 },
      "candidates stay in top strip away from corners")
check(gpPoints.first!.x != gpFrame.x + gpFrame.w / 2 && gpPoints.last!.x == gpFrame.x + gpFrame.w / 2,
      "off-center first, center last")
check(GrabPointPlanner.candidates(frame: YRect(x: 0, y: 0, w: 180, h: 400)) == [CGPoint(x: 90, y: 8)],
      "narrow window falls back to center")
let gpCenter = gpFrame.x + gpFrame.w / 2
check(!GrabPointPlanner.choose(frame: gpFrame,
                               roleAt: { abs($0.x - gpCenter) < 1 ? "AXTextField" : nil })
        .contains { abs($0.x - gpCenter) < 1 },
      "search field at center is skipped")
check(GrabPointPlanner.choose(frame: gpFrame, roleAt: { _ in "AXButton" }) == gpPoints,
      "all-unsafe probe falls back to the unfiltered list")
check(GrabPointPlanner.isSafe(role: nil) && !GrabPointPlanner.isSafe(role: "AXSearchField"),
      "role classification")

print("L10n")
check(L10n.resolve(.auto, preferred: ["zh-Hant-TW"]) == .zhHant, "auto resolves zh-Hant")
check(L10n.resolve(.auto, preferred: ["ja-JP"]) == .ja, "auto resolves ja")
check(L10n.resolve(.auto, preferred: ["de-DE"]) == .en, "auto falls back to en")
check(L10n.resolve(.zhHant, preferred: ["ja"]) == .zhHant, "explicit wins over preferred")
check(Set(L10nStrings.en.keys) == Set(L10nStrings.zhHant.keys)
      && Set(L10nStrings.en.keys) == Set(L10nStrings.ja.keys), "table key parity")
check(!L10nStrings.en.values.contains(""), "no empty en values")
check(ShortcutCatalog.all.allSatisfy { L10nStrings.en["action.\($0.id)"] != nil }, "catalog title coverage")
check(ShortcutGroup.order.allSatisfy { L10nStrings.en["group.\($0)"] != nil }, "group coverage")
L10n.current = .ja
check(L10n.t("ui.apply") == "適用", "ja lookup")
L10n.current = .en
let bogusKey = "bogus" + ".key"  // construct at runtime so regex-based key scan doesn't see it as a literal
check(L10n.t(bogusKey) == bogusKey, "fallback to key")

print("L10n call sites")
let srcDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Sources")
if FileManager.default.fileExists(atPath: srcDir.path),
   let en = Optional(L10nStrings.en),
   let e = FileManager.default.enumerator(at: srcDir, includingPropertiesForKeys: nil) {
    var missing: [String] = []
    var found = 0
    let re = try! NSRegularExpression(pattern: #"L10n\.t\("([^"\\]+)"\)"#)
    for case let url as URL in e where url.pathExtension == "swift" {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
        for m in re.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let r = Range(m.range(at: 1), in: text) else { continue }
            let key = String(text[r]); found += 1
            if en[key] == nil { missing.append("\(url.lastPathComponent): \(key)") }
        }
    }
    check(missing.isEmpty, "all literal L10n.t keys exist (missing: \(missing))")
    check(found > 50, "call-site scan found \(found) keys (>50 expected)")
} else {
    print("  ok: (skipped — Sources/ not found from cwd)")
}

print("MenuQuickKeys")
check(MenuQuickKeys.sequence.count == 26 && Set(MenuQuickKeys.sequence).count == 26,
      "26 unique quick keys")
check(MenuQuickKeys.keys(count: 3) == ["1", "2", "3"], "keys(count:) prefix")
check(MenuQuickKeys.keys(count: 99).count == 26 && MenuQuickKeys.keys(count: -1).isEmpty,
      "keys(count:) clamps")
check(Hotkey.parse("ctrl - 0x2b")?.displayString == "⌃,", "comma hotkey displays as ⌃,")
check(Hotkey.parse("ctrl - 0x2B")?.displayString == "⌃,", "uppercase comma hotkey displays as ⌃,")

print("MRUOrder")
do {
    var m = MRUOrder()
    m.touch(1); m.touch(2); m.touch(3); m.touch(1)
    check(m.ids == [1, 3, 2], "touch moves to front")
    m.prune(keeping: [1, 2])
    check(m.ids == [1, 2], "prune drops dead ids")
}

print("SwitcherModel")
do {
    func sw(_ id: Int, _ app: String, _ space: Int, _ focus: Bool = false,
            title: String = "", visible: Bool = true) -> YabaiWindow {
        YabaiWindow(id: id, pid: id * 10, app: app, title: title.isEmpty ? app : title,
                    frame: YRect(x: 0, y: 0, w: 1, h: 1), display: 1, space: space,
                    stackIndex: 0, hasFocus: focus, isVisible: visible)
    }
    let wins = [sw(1, "Cursor", 1, true), sw(2, "Cursor", 3), sw(3, "Safari", 2)]
    let all = SwitcherModel.build(windows: wins, mru: [1, 3], scope: .allWindows)
    check(all.map { $0.id } == [1, 3, 2], "MRU first, unseen windows follow by space")
    let app = SwitcherModel.build(windows: wins, mru: [1], scope: .currentApp)
    check(Set(app.map { $0.id }) == [1, 2], "currentApp scope filters by focused app")
    let spc = SwitcherModel.build(windows: wins, mru: [1], scope: .currentSpace)
    check(spc.map { $0.id } == [1], "currentSpace scope keeps the focused space")
    let q = SwitcherModel.build(windows: wins, mru: [], scope: .allWindows, query: "saf")
    check(q.map { $0.id } == [3], "query filters case-insensitively")
    check(SwitcherModel.initialIndex(count: 3, firstIsCurrent: true, backward: false) == 1,
          "initial selection lands on the previous window")
    check(SwitcherModel.initialIndex(count: 3, firstIsCurrent: true, backward: true) == 2,
          "backward activation starts at the end")
    let stale = SwitcherModel.build(
        windows: [sw(1, "Cursor", 1, true), sw(2, "Safari", 1), sw(3, "Safari", 2)],
        mru: [2, 1], scope: .currentApp)
    check(Set(stale.map { $0.id }) == [2, 3], "anchor prefers MRU head over stale hasFocus")
}

print("SwitcherKeyMachine")
do {
    let trig = [SwitcherTrigger(keycode: 0x30, mods: [.alt], scope: .allWindows),
                SwitcherTrigger(keycode: 0x32, mods: [.alt], scope: .currentApp)]
    var m = SwitcherKeyMachine()
    check(m.handle(.keyDown(code: 0x30, mods: [.alt]), triggers: trig)
          == .activate(trigger: 0, backward: false), "alt+tab activates")
    check(m.handle(.keyDown(code: 0x30, mods: [.alt]), triggers: trig)
          == .cycle(forward: true), "repeat press cycles")
    check(m.handle(.keyDown(code: 0x30, mods: [.alt, .shift]), triggers: trig)
          == .cycle(forward: false), "shift cycles backward")
    check(m.handle(.keyDown(code: 0x32, mods: [.alt]), triggers: trig)
          == .activate(trigger: 1, backward: false), "second trigger switches scope")
    check(m.handle(.flagsChanged(mods: []), triggers: trig)
          == .commit(consume: false), "modifier release commits")
    check(m.handle(.keyDown(code: 0x30, mods: [.alt, .cmd]), triggers: trig) == .pass,
          "extra modifier is not our shortcut")
    _ = m.handle(.keyDown(code: 0x30, mods: [.alt]), triggers: trig)
    check(m.handle(.keyDown(code: 0x0C, mods: [.alt, .cmd]), triggers: trig) == .quitSelected,
          "cmd+q quits the selected app")
    check(m.handle(.keyDown(code: 0x0D, mods: [.alt, .cmd]), triggers: trig) == .closeSelected,
          "cmd+w closes the selected window")
    check(m.handle(.keyDown(code: 0x35, mods: [.alt]), triggers: trig) == .cancel,
          "escape cancels")
    let shifted = [SwitcherTrigger(keycode: 0x30, mods: [.alt], scope: .allWindows),
                   SwitcherTrigger(keycode: 0x30, mods: [.alt, .shift], scope: .currentSpace)]
    var m2 = SwitcherKeyMachine()
    check(m2.handle(.keyDown(code: 0x30, mods: [.alt, .shift]), triggers: shifted)
          == .activate(trigger: 1, backward: false),
          "exact modifier match beats shift-tolerant ordering")
}

print("SwitcherTriggers + KeyCodeMap reverse")
do {
    var c = AppConfig.defaults
    check(SwitcherTriggers.build(from: c)
          == [SwitcherTrigger(keycode: 0x30, mods: [.alt], scope: .allWindows),
              SwitcherTrigger(keycode: 0x32, mods: [.alt], scope: .currentApp)],
          "default config yields alt+tab / alt+` triggers")
    c.switcherCaptureCmdTab = true
    check(SwitcherTriggers.build(from: c).first
          == SwitcherTrigger(keycode: 0x30, mods: [.cmd], scope: .allWindows),
          "captureCmdTab overrides the all-windows trigger")
    c.switcherHotkeySpace = "tab"   // modifier-less → skipped
    check(!SwitcherTriggers.build(from: c).contains { $0.scope == .currentSpace },
          "modifier-less hotkey is skipped")
    check(KeyCodeMap.keyCode(forSkhdKey: "tab") == 0x30, "reverse map: tab")
    check(KeyCodeMap.keyCode(forSkhdKey: "0x32") == 0x32, "reverse map: hex literal")
    check(KeyCodeMap.keyCode(forSkhdKey: "w") == 0x0D, "reverse map: letter")
    check(KeyCodeMap.keyCode(forSkhdKey: "bogus") == nil, "reverse map: unknown -> nil")
}

print("SwitcherLayout")
do {
    let small = SwitcherLayout.grid(count: 3, maxWidth: 1600, maxHeight: 800)
    check(small.columns == 3 && small.rows == 1 && small.cellWidth == 240,
          "few windows keep base size on one row")
    let big = SwitcherLayout.grid(count: 40, maxWidth: 1200, maxHeight: 600)
    check(big.rows > 1 && big.cellWidth < 240 && big.columns * big.rows >= 40,
          "many windows wrap and shrink but all fit")
}

print("AppConfig switcher fields")
do {
    let old = AppConfig.load(from: #"{"style":"flag"}"#.data(using: .utf8))
    check(old.switcherEnabled && old.switcherHotkeyAll == "alt - tab",
          "pre-switcher config gains switcher defaults")
    check(ShortcutCatalog.action(id: "open-window-switcher") != nil,
          "open-window-switcher action in catalog")
    check(ScriptInstaller.scriptNames.contains("openWindowSwitcher.sh"),
          "switcher socket script ships")
}

print("WindowLabeler")
do {
    func k(_ app: String, _ title: String, _ sib: [String] = []) -> String {
        WindowLabeler.keyword(app: app, title: title, siblingTitles: sib)
    }
    check(k("Code", "Stack.swift — yabai-dockstack") == "yabai-dockstack", "VS Code → workspace")
    check(k("Code", "● Stack.swift — yabai-dockstack — Visual Studio Code") == "yabai-dockstack", "VS Code dirty + app suffix → workspace")
    check(k("Code", "deployer") == "deployer", "VS Code bare folder")
    check(k("Cursor", "main.go — api-server") == "api-server", "Cursor → workspace")
    check(k("IntelliJ IDEA", "shop-backend – OrderService.kt") == "shop-backend", "JetBrains → project")
    check(k("Warp", "~/Project/yabai-dockstack") == "yabai-dockstack", "Warp → cwd leaf")
    check(k("iTerm2", "les@mac: ~/work/foo") == "foo", "iTerm2 user@host: cwd → leaf")
    check(k("Warp", "~") == "~", "home stays ~")
    check(k("Notes", "Notes - Groceries", ["Notes - Work"]) == "Groceries", "siblings → differing segment")
    check(k("Preview", "a.pdf | Page 1", ["b.pdf | Page 1"]) == "a.pdf", "siblings → first differing segment")
    check(k("Gather", "") == "Gather", "empty title → app")
    check(k("Safari", "Safari") == "Safari", "title == app → app")
    check(k("Safari", "蘋果新聞") == "蘋果新聞", "CJK title kept")
    let r = YRect(x: 0, y: 0, w: 1, h: 1)
    let ws = [YabaiWindow(id: 1, pid: 1, app: "Code", title: "a.swift — projA", frame: r, display: 1, space: 1, stackIndex: 0, hasFocus: false),
              YabaiWindow(id: 2, pid: 1, app: "Code", title: "b.swift — projB", frame: r, display: 1, space: 2, stackIndex: 0, hasFocus: false)]
    check(WindowLabeler.keywords(ws) == [1: "projA", 2: "projB"], "batch keywords per window")
    check(SwitcherModel.build(windows: ws, mru: [], scope: .allWindows).map(\.keyword) == ["projA", "projB"],
          "switcher items carry keywords")
    check(SwitcherModel.build(windows: ws, mru: [], scope: .allWindows, query: "projB").first?.keyword == "projB",
          "switcher keyword keeps siblings outside the filtered pool")
    check(WindowMenuModel.build(ws).first?.spaces.flatMap { $0.windows.map(\.keyword) } == ["projA", "projB"],
          "menu entries carry keywords")
}

print("StackReorderPlanner")
do {
    check(StackReorderPlanner.swaps(ids: [1, 2, 3, 4], from: 0, to: 2) == [SwapStep(a: 1, b: 2), SwapStep(a: 1, b: 3)],
          "move down = adjacent swaps")
    check(StackReorderPlanner.swaps(ids: [1, 2, 3, 4], from: 3, to: 1) == [SwapStep(a: 4, b: 3), SwapStep(a: 4, b: 2)],
          "move up = adjacent swaps")
    check(StackReorderPlanner.swaps(ids: [1, 2, 3], from: 1, to: 1).isEmpty, "same index → no swaps")
    check(StackReorderPlanner.swaps(ids: [1, 2, 3], from: 5, to: 0).isEmpty, "from out of range → no swaps")
    check(StackReorderPlanner.swaps(ids: [1, 2, 3], from: 0, to: 3).isEmpty, "to out of range → no swaps")
    check(StackReorderPlanner.dropIndex(offsetFromTop: 70, cell: 32, count: 3) == 2, "drop index from offset")
    check(StackReorderPlanner.dropIndex(offsetFromTop: -5, cell: 32, count: 3) == 0, "drop index clamps low")
    check(StackReorderPlanner.dropIndex(offsetFromTop: 500, cell: 32, count: 3) == 2, "drop index clamps high")
    check(AppConfig.load(from: #"{"style":"flag"}"#.data(using: .utf8)).indicatorDragReorder,
          "drag reorder defaults on")
}

print("WindowFocuser")
do {
    func fakeYabai(focusExit: Int) -> String {
        let path = NSTemporaryDirectory() + "fake-yabai-\(UUID().uuidString)"
        let script = """
        #!/bin/sh
        case "$*" in
          *--focus*) exit \(focusExit) ;;
          *query*) echo '[{"id":7,"pid":42,"app":"Gather","frame":{"x":0,"y":0,"w":1,"h":1},"display":1,"space":1,"stack-index":0,"has-focus":false}]' ;;
        esac
        """
        try? script.write(toFile: path, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        return path
    }
    var reopened: [Int] = []
    WindowFocuser(client: YabaiClient(yabaiPath: fakeYabai(focusExit: 0)), reopen: { reopened.append($0) })
        .focus(windowId: 7)
    check(reopened.isEmpty, "focus success → no reopen")
    WindowFocuser(client: YabaiClient(yabaiPath: fakeYabai(focusExit: 1)), reopen: { reopened.append($0) })
        .focus(windowId: 7)
    check(reopened == [42], "focus failure (tray window, no AX ref) → reopen owning app")
    reopened = []
    WindowFocuser(client: YabaiClient(yabaiPath: fakeYabai(focusExit: 1)), reopen: { reopened.append($0) })
        .focus(windowId: 999)
    check(reopened.isEmpty, "focus failure for unknown window → nothing")
}

print("Menu hover")
check(!AppConfig.load(from: #"{"style":"flag"}"#.data(using: .utf8)).menuOpenOnHover,
      "hover-to-open menu defaults off")

print("WindowStripModel")
do {
    let r = YRect(x: 0, y: 0, w: 1, h: 1)
    let ws = [YabaiWindow(id: 1, pid: 1, app: "Code", title: "a.swift — projA", frame: r, display: 1, space: 1, stackIndex: 0, hasFocus: true),
              YabaiWindow(id: 2, pid: 1, app: "Code", title: "b.swift — projB", frame: r, display: 1, space: 2, stackIndex: 0, hasFocus: false),
              YabaiWindow(id: 3, pid: 2, app: "Safari", title: "news", frame: r, display: 2, space: 3, stackIndex: 0, hasFocus: false)]
    let sp = [SpaceInfo(index: 1, display: 1, isVisible: true),
              SpaceInfo(index: 2, display: 1, isVisible: false),
              SpaceInfo(index: 3, display: 2, isVisible: true, isNativeFullscreen: true)]
    let strips = WindowStripModel.build(windows: ws, spaces: sp, spaceLabels: [2: "web"])
    check(strips.map(\.display) == [1, 2], "one strip per display, ascending")
    check(strips.first?.sections.map(\.name) == ["1", "web"], "sections per space; label or number")
    check(strips.first?.sections.first?.isVisible == true, "visible space flagged")
    check(strips.first?.sections.first?.chips.first?.focused == true, "focused chip flagged")
    check(strips.first?.sections.first?.chips.first?.keyword == "projA", "chip keyword from WindowLabeler")
    check(strips.first?.hidden == false && strips.last?.hidden == true, "hidden when visible space is native fullscreen")
    func fit(_ n: Int, full: Double, compact: Double, available: Double) -> WindowStripModel.Density {
        WindowStripModel.fit(fullWidths: Array(repeating: full, count: n),
                             compactWidths: Array(repeating: compact, count: n),
                             iconWidth: 30, overflowWidth: 30, available: available)
    }
    check(fit(2, full: 100, compact: 50, available: 250) == .full, "fit: full names")
    check(fit(3, full: 100, compact: 60, available: 250) == .compact, "fit: shortened names")
    check(fit(6, full: 100, compact: 60, available: 250) == .iconOnly, "fit: icons only")
    check(fit(30, full: 100, compact: 60, available: 250) == .overflow(visible: 7), "fit: 30 windows overflow into +N")
    check(fit(1, full: 100, compact: 60, available: 10) == .overflow(visible: 0), "fit: no room → only +N")
    let sst = WindowStripModel.DisplayStrip(display: 1, hidden: false, sections: [])
    let sfr = CGRect(x: 0, y: 0, width: 100, height: 100)
    check(WindowStripModel.needsRender(cached: .init(strip: sst, frame: sfr, scale: 1), strip: sst, frame: sfr, scale: 0.8),
          "strip size change → re-render")
    check(AppConfig.load(from: #"{"style":"flag"}"#.data(using: .utf8)).windowStripScale == 0.8, "strip size defaults to 0.8")
    check(SpaceInfo.decodeList(#"[{"index":3,"display":2,"is-visible":true,"is-native-fullscreen":true}]"#.data(using: .utf8)!).first?.isNativeFullscreen == true,
          "is-native-fullscreen decoded")
}

check(!AppConfig.load(from: #"{"style":"flag"}"#.data(using: .utf8)).windowStrip,
      "window strip defaults off")

print("HyperKey")
do {
    let user: [String: UInt64] = ["HIDKeyboardModifierMappingSrc": 30064771299, "HIDKeyboardModifierMappingDst": 30064771300]
    let ours: [String: UInt64] = ["HIDKeyboardModifierMappingSrc": 0x700000039, "HIDKeyboardModifierMappingDst": HyperKeyMapping.f18]
    check(HyperKeyMapping.parse("(null)") == [], "hidutil (null) → no mappings")
    check(HyperKeyMapping.parse("(\n    {\n    HIDKeyboardModifierMappingDst = 30064771300;\n    HIDKeyboardModifierMappingSrc = 30064771299;\n}\n)") == [user],
          "hidutil OpenStep output parsed")
    check(HyperKeyMapping.merged(existing: [user], source: .capsLock) == [user, ours], "merge appends ours, keeps user's")
    check(HyperKeyMapping.merged(existing: [user, ours], source: .none) == [user], "crash cleanup removes only ours")
    check(HyperKeyMapping.merged(existing: [ours], source: .rightCommand).count == 1, "source change → no duplicates")
    check(HyperKeyMapping.hidutilJSON([ours]).contains("\"UserKeyMapping\""), "hidutil JSON shape")
    var r = HyperKeyReducer()
    let seq: [(HyperKeyReducer.Event, HyperKeyReducer.Action)] = [
        (.hyperDown, .pressModifiers), (.hyperDown, .swallow), (.keyDown, .addHyperFlags), (.hyperDown, .swallow),
        (.keyUp, .addHyperFlags), (.hyperUp, .releaseModifiers), (.hyperDown, .pressModifiers), (.hyperUp, .quickPress),
        (.keyDown, .pass), (.hyperUp, .swallow)]
    check(seq.allSatisfy { r.handle($0.0) == $0.1 }, "reducer: press/release modifiers once, chord vs quick press, autorepeat-safe")
    check(Hotkey.parse("hyper - h")?.mods == [.ctrl, .shift, .alt, .cmd], "parse hyper")
    check(Hotkey.parse("meh - h")?.mods == [.ctrl, .shift, .alt], "parse meh")
    Hotkey.showHyperSymbol = true
    check(Hotkey(mods: [.ctrl, .shift, .alt, .cmd], key: "h").displayString == "✦H", "hyper shown as ✦")
    Hotkey.showHyperSymbol = false
    check(Hotkey(mods: [.ctrl, .shift, .alt, .cmd], key: "h").displayString == "⌃⇧⌥⌘H", "hyper glyphs by default")
    let c = AppConfig.load(from: #"{"style":"flag"}"#.data(using: .utf8))
    check(c.hyperKey == "none" && c.hyperQuickPress == "none" && c.hyperIncludeShift && !c.hyperShowSymbol,
          "hyper defaults (off, shift on)")
}

print("Review fixes")
do {
    check(HyperKeyPlan.health(configured: .capsLock, ax: true, running: false) == .start, "health: start when AX granted")
    check(HyperKeyPlan.health(configured: .capsLock, ax: false, running: true) == .stop, "health: stop when AX revoked mid-run")
    check(HyperKeyPlan.health(configured: .capsLock, ax: true, running: true) == .keep, "health: keep when running")
    check(HyperKeyPlan.health(configured: .none, ax: true, running: false) == .keep, "health: off stays off")
    check(HyperKeyPlan.mapping(configured: .capsLock, tapRunning: false) == HyperSource.none, "no remap without a running tap")
    check(HyperKeyPlan.mapping(configured: .capsLock, tapRunning: true) == .capsLock, "remap once tap runs")
    check(HyperKeyMapping.parse("hidutil: error") == nil, "unparseable hidutil output → nil, not []")
    check(HyperKeyMapping.parse("(\n)") == [], "empty hidutil list → []")
    var r = HyperKeyReducer()
    _ = r.handle(.hyperDown); _ = r.handle(.keyDown)
    check(r.handle(.hyperFoundUp) == .releaseModifiers && r.handle(.hyperUp) == .swallow,
          "missed hyper up (secure input) releases modifiers once")
    _ = r.handle(.hyperDown)
    check(r.handle(.hyperFoundUp) == .releaseModifiers, "found-up is never a quick press")
    var h = HoverOpenLogic()
    check(h.pointer(inside: true), "hover arms timer")
    h.menuClosed(pointerInside: true)
    check(!h.timerFired(pointerInside: true), "stale hover timer doesn't reopen a closed menu")
    check(!h.pointer(inside: true), "still suppressed until pointer leaves")
    _ = h.pointer(inside: false)
    check(h.pointer(inside: true) && h.timerFired(pointerInside: true), "re-enter opens again")
    let st = WindowStripModel.DisplayStrip(display: 1, hidden: false, sections: [])
    let fr = CGRect(x: 0, y: 0, width: 100, height: 100)
    check(!WindowStripModel.needsRender(cached: .init(strip: st, frame: fr), strip: st, frame: fr), "same strip+frame → skip")
    check(WindowStripModel.needsRender(cached: .init(strip: st, frame: fr), strip: st, frame: fr.offsetBy(dx: 10, dy: 0)),
          "screen frame change → re-render")
    let icon = CGRect(x: 2422, y: 2171, width: 36, height: 24)
    let active = CGRect(x: 978, y: 1117, width: 1920, height: 1080)
    check(HoverOpenLogic.mirrored(icon, from: active, to: CGRect(x: -942, y: 1117, width: 1920, height: 1080))
          == CGRect(x: 502, y: 2157, width: 36, height: 40), "status icon mirrored onto another external display")
    check(HoverOpenLogic.mirrored(icon, from: active, to: CGRect(x: 0, y: 0, width: 1728, height: 1117))
          == CGRect(x: 1252, y: 1077, width: 36, height: 40), "status icon mirrored onto the laptop display")
}

print("Drag to space: routing")
do {
    check(!SAProbe.available(csrutilOutput: "System Integrity Protection status: enabled."), "SIP fully on → no SA")
    check(SAProbe.available(csrutilOutput: "System Integrity Protection status: disabled."), "SIP off → SA")
    check(SAProbe.available(csrutilOutput: "System Integrity Protection status: enabled (Custom Configuration).\n\nConfiguration:\n"),
          "custom SIP config → SA")
    check(!SAProbe.available(csrutilOutput: nil), "csrutil failed → assume no SA")
    check(MoveRouting.decide(windowSpace: 3, target: 3, saAvailable: true) == .noop, "same space → no-op")
    check(MoveRouting.decide(windowSpace: 2, target: 5, saAvailable: true) == .script, "SA → yabai script")
    check(MoveRouting.decide(windowSpace: 2, target: 5, saAvailable: false) == .sipFree, "no SA → SIP-free walk")
    let hk = Hotkey(mods: [.ctrl, .shift, .alt, .cmd], key: "tab")
    let set = ShortcutBindings.setting([], action: "open-window-switcher", hotkey: hk)
    check(set == [ShortcutBinding(actionID: "open-window-switcher", enabled: true, hotkey: hk)], "binding created")
    check(ShortcutBindings.setting(set, action: "open-window-switcher", hotkey: nil).first?.enabled == false,
          "clearing a binding disables it")
}

print("Drag to space: SpaceMover.moveWindow")
do {
    final class RecSim: SpaceSimulating {
        var walks = 0
        func dragWalk(grabPoints: [CGPoint], direction: ArrowDirection, count: Int,
                      liftCheck: (() -> Bool)?) -> DragWalkOutcome { walks += 1; return .walked(observedAll: true) }
    }
    struct NoProbe: GrabPointProbing { func role(at point: CGPoint) -> String? { nil } }
    let path = NSTemporaryDirectory() + "fake-yabai-\(UUID().uuidString)"
    try? "#!/bin/sh\ncase \"$*\" in *--focus*) exit 1 ;; esac\n".write(toFile: path, atomically: true, encoding: .utf8)
    try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
    let sim = RecSim()
    let mover = SpaceMover(client: YabaiClient(yabaiPath: path), simulator: sim, probe: NoProbe())
    check(mover.moveWindow(id: 7, toSpace: 3) == .focusFailed && sim.walks == 0,
          "unfocusable (tray-closed) window → focusFailed, no simulated walk")
}

print("SpaceInfo focus")
check(SpaceInfo.decodeList(Data(#"[{"index":1,"display":1,"has-focus":true},{"index":2,"display":1}]"#.utf8)).map(\.hasFocus) == [true, false],
      "SpaceInfo decodes has-focus")

print("Drag to space: strip")
do {
    let r = YRect(x: 0, y: 0, w: 1, h: 1)
    let ws = [YabaiWindow(id: 1, pid: 1, app: "A", title: "a", frame: r, display: 1, space: 1, stackIndex: 0, hasFocus: false)]
    let sp = [SpaceInfo(index: 1, display: 1, isVisible: true), SpaceInfo(index: 2, display: 1, isVisible: false)]
    check(WindowStripModel.build(windows: ws, spaces: sp, spaceLabels: [:], includeEmpty: true).first?.sections.map(\.space) == [1, 2],
          "strip lists empty spaces as drop targets")
    check(WindowStripModel.build(windows: ws, spaces: sp, spaceLabels: [:]).first?.sections.map(\.space) == [1],
          "strip hides empty spaces by default")
    let ranges = [(space: 1, minX: 0.0, maxX: 100.0), (space: 2, minX: 110.0, maxX: 200.0)]
    check(WindowStripModel.dropSpace(x: 150, sections: ranges) == 2, "drop over a section")
    check(WindowStripModel.dropSpace(x: 104, sections: ranges) == 1, "drop in a divider gap → nearest section")
    check(WindowStripModel.dropSpace(x: 400, sections: ranges) == nil, "drop beyond the strip → nil")
}

print("Drag to space: review fixes")
do {
    func loggingYabai(focusExit: Int) -> (String, String) {
        let dir = NSTemporaryDirectory() + "fy-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let log = dir + "/log", path = dir + "/yabai"
        let script = """
        #!/bin/sh
        echo "$*" >> \(log)
        case "$*" in
          *"--windows --window"*) echo '{"id":7,"pid":1,"app":"A","frame":{"x":0,"y":0,"w":1,"h":1},"display":1,"space":2,"stack-index":0,"has-focus":true}' ;;
          *query*--windows*) echo '[{"id":7,"pid":1,"app":"A","frame":{"x":0,"y":0,"w":1,"h":1},"display":1,"space":2,"stack-index":0,"has-focus":false}]' ;;
          *--focus*) exit \(focusExit) ;;
        esac
        """
        try? script.write(toFile: path, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        return (path, log)
    }
    let (p1, l1) = loggingYabai(focusExit: 0)
    let c1 = YabaiClient(yabaiPath: p1)
    WindowSpaceMover(client: c1, spaceMover: SpaceMover(client: c1), saAvailable: { true }).moveNow(windowId: 7, toSpace: 3)
    check(((try? String(contentsOfFile: l1, encoding: .utf8)) ?? "").contains("-m window 7 --space 3"),
          "SA path moves by window id with the app's own yabai (no PATH lookup)")
    let (p2, l2) = loggingYabai(focusExit: 1)
    let c2 = YabaiClient(yabaiPath: p2)
    WindowSpaceMover(client: c2, spaceMover: SpaceMover(client: c2), saAvailable: { true }).moveNow(windowId: 7, toSpace: 3)
    check(!((try? String(contentsOfFile: l2, encoding: .utf8)) ?? "").contains("--space"),
          "SA path: focus failed → nothing is sent away")
    let ranges = [(space: 1, minX: 0.0, maxX: 100.0), (space: 2, minX: 110.0, maxX: 200.0)]
    check(WindowStripModel.dropSpace(x: 150, y: -200, height: 20, sections: ranges) == nil, "strip: drop far below cancels")
    check(WindowStripModel.dropSpace(x: 150, y: 10, height: 20, sections: ranges) == 2, "strip: drop on the strip lands")
}

print("Spaces view (PR #4) model")
do {
    func w(_ id: Int, space: Int, scratchpad: String? = nil) -> YabaiWindow {
        YabaiWindow(id: id, pid: id, app: "A", title: "t", frame: YRect(x: 0, y: 0, w: 200, h: 100),
                    display: 1, space: space, stackIndex: 0, hasFocus: false, scratchpad: scratchpad)
    }
    let tiles = SpacesLayout.windowTiles(aspects: [2.0, 2.2, 0.5], width: 400, height: 220)
    let inBounds = tiles.allSatisfy { $0.width > 0 && $0.height > 0 && $0.maxX <= 400 && $0.maxY <= 220 }
    let disjoint = tiles.indices.allSatisfy { i in tiles.indices.allSatisfy { j in i == j || !tiles[i].insetBy(dx: 0.5, dy: 0.5).intersects(tiles[j]) } }
    check(tiles.count == 3 && inBounds && disjoint, "window tiles: 3 positive, in-bounds, non-overlapping rects")
    check(SpacesModel.windowIDsToMove(from: 1, to: 1, windows: [w(1, space: 1)]) == [], "space transfer onto itself moves nothing")
    check(SpacesModel.displayableWindows([w(1, space: 1), w(2, space: 1, scratchpad: "x")]).map(\.id) == [1],
          "scratchpad windows are not displayable")
}

print("Spaces switcher: cards, nav, interaction")
do {
    func win(_ id: Int, space: Int, display: Int = 1, stack: Int = 0) -> YabaiWindow {
        YabaiWindow(id: id, pid: id, app: "A", title: "t\(id)", frame: YRect(x: 0, y: 0, w: 200, h: 100),
                    display: display, space: space, stackIndex: stack, hasFocus: false)
    }
    let spaces = [SpaceInfo(index: 1, display: 1, isVisible: true, hasFocus: true),
                  SpaceInfo(index: 2, display: 1, isVisible: false),
                  SpaceInfo(index: 3, display: 2, isVisible: true, isNativeFullscreen: true)]
    let windows = [win(11, space: 1, stack: 1), win(12, space: 1, stack: 0), win(31, space: 3, display: 2)]
    let items = windows.map { SwitcherItem(id: $0.id, pid: $0.pid, app: $0.app, title: $0.title, space: $0.space,
                                           display: $0.display, hasFocus: false) }
    let cards = SpacesSwitcherModel.build(items: items, windows: windows, spaces: spaces,
                                          labels: [2: "web"], matching: [11, 31])
    check(cards.map(\.space) == [1, 2, 3] && cards.map(\.name) == ["Space 1", "web", "Space 3"],
          "cards: every space incl. empty + fullscreen, display order, label names")
    check(cards[0].tiles.map(\.item.id) == [12, 11] && cards[0].tiles.map(\.matches) == [false, true]
          && cards[0].tiles.first?.aspect == 2, "tiles: stack order, query matches, aspect")
    check(cards[2].isFullscreen && cards[0].hasFocus && cards[1].tiles.isEmpty, "cards: fullscreen / focus flags")
    check(SpacesSwitcherModel.selectable(cards).map(\.id) == [11, 31], "only matching tiles are selectable")

    let rects = [CGRect(x: 0, y: 0, width: 100, height: 50), CGRect(x: 120, y: 0, width: 100, height: 50),
                 CGRect(x: 10, y: 80, width: 100, height: 50)]
    check(SpatialNav.neighbor(of: 1, up: false, rects: rects) == 2, "↓ to the tile below")
    check(SpatialNav.neighbor(of: 2, up: true, rects: rects) == 0, "↑ prefers the tile nearest in x")
    check(SpatialNav.neighbor(of: 0, up: true, rects: rects) == nil && SpatialNav.neighbor(of: 9, up: true, rects: rects) == nil,
          "↑ at the top / bad index → nil")

    let cardRects = [(space: 1, rect: CGRect(x: 0, y: 0, width: 100, height: 100), isFullscreen: false),
                     (space: 3, rect: CGRect(x: 120, y: 0, width: 100, height: 100), isFullscreen: true)]
    check(SpacesInteraction.dropTarget(at: CGPoint(x: 50, y: 50), cards: cardRects, visible: nil) == 1, "drop on a card")
    check(SpacesInteraction.dropTarget(at: CGPoint(x: 150, y: 50), cards: cardRects, visible: nil) == nil,
          "fullscreen card isn't a drop target")
    check(SpacesInteraction.dropTarget(at: CGPoint(x: 110, y: 50), cards: cardRects, visible: nil) == nil, "drop in a gap → nil")
    check(SpacesInteraction.dropTarget(at: CGPoint(x: 50, y: 50), cards: cardRects,
                                       visible: CGRect(x: 0, y: 60, width: 300, height: 100)) == nil,
          "scrolled-away card isn't a drop target")
    check(SpacesInteraction.swapAllowed(source: 1, target: 2, saAvailable: true, fullscreen: [])
          && !SpacesInteraction.swapAllowed(source: 1, target: 1, saAvailable: true, fullscreen: [])
          && !SpacesInteraction.swapAllowed(source: 1, target: 2, saAvailable: false, fullscreen: [])
          && !SpacesInteraction.swapAllowed(source: 1, target: 3, saAvailable: true, fullscreen: [3]),
          "space swap: SA only, not onto itself or a fullscreen space")
    check(SpacesInteraction.cardClick(space: 4, saAvailable: true, recentWindowInSpace: nil) == .focusSpace(4)
          && SpacesInteraction.cardClick(space: 4, saAvailable: false, recentWindowInSpace: 9) == .focusWindow(9)
          && SpacesInteraction.cardClick(space: 4, saAvailable: false, recentWindowInSpace: nil) == .nothing,
          "card click: SA focuses the space, else its recent window, else nothing")
}

print("Spaces switcher: no-follow move, space swap")
do {
    func logged(_ queryWindows: String) -> (String, String) {
        let dir = NSTemporaryDirectory() + "fy-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let log = dir + "/log", path = dir + "/yabai"
        let script = """
        #!/bin/sh
        echo "$*" >> \(log)
        case "$*" in
          *query*--windows*) echo '\(queryWindows)' ;;
          *query*--spaces*) echo '[{"index":2,"display":1},{"index":3,"display":1}]' ;;
        esac
        """
        try? script.write(toFile: path, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        return (path, log)
    }
    func w(_ id: Int, _ space: Int) -> String {
        #"{"id":\#(id),"pid":1,"app":"A","frame":{"x":0,"y":0,"w":1,"h":1},"display":1,"space":\#(space),"stack-index":0,"has-focus":false}"#
    }
    func calls(_ log: String) -> String { (try? String(contentsOfFile: log, encoding: .utf8)) ?? "" }
    let (p1, l1) = logged("[\(w(7, 2))]")
    let c1 = YabaiClient(yabaiPath: p1)
    WindowSpaceMover(client: c1, spaceMover: SpaceMover(client: c1), saAvailable: { true })
        .moveNow(windowId: 7, toSpace: 3, follow: false)
    check(calls(l1).contains("-m window 7 --space 3") && !calls(l1).contains("--focus"),
          "SA move without follow: by id, no focus")
    let both = "[\(w(21, 2)),\(w(22, 2)),\(w(31, 3))]"
    let (p2, l2) = logged(both)
    let c2 = YabaiClient(yabaiPath: p2)
    WindowSpaceMover(client: c2, spaceMover: SpaceMover(client: c2), saAvailable: { true }).swapNow(2, 3)
    check(["window 21 --space 3", "window 22 --space 3", "window 31 --space 2"].allSatisfy { calls(l2).contains($0) },
          "space swap moves both sides' windows (SA)")
    let (p3, l3) = logged(both)
    let c3 = YabaiClient(yabaiPath: p3)
    WindowSpaceMover(client: c3, spaceMover: SpaceMover(client: c3), saAvailable: { false }).swapNow(2, 3)
    check(calls(l3).range(of: #"--space \d"#, options: .regularExpression) == nil, "space swap does nothing without the SA")
}

print("Spaces switcher: config")
do {
    let d = AppConfig.defaults
    check(!d.switcherFollowMove && !d.switcherWallpaper && d.switcherWallpaperPath == "" && d.switcherWallpaperDarkPath == "",
          "follow-move / wallpaper default off")
    let legacy = AppConfig.load(from: #"{"style":"flag"}"#.data(using: .utf8))
    check(!legacy.switcherFollowMove && !legacy.switcherWallpaper && legacy.switcherWallpaperPath == "",
          "a config without the keys loads the defaults")
    let set = AppConfig.load(from: #"{"switcherFollowMove":true,"switcherWallpaperPath":"/tmp/w.heic"}"#.data(using: .utf8))
    check(set.switcherFollowMove && set.switcherWallpaperPath == "/tmp/w.heic", "follow-move / wallpaper keys load")
}

print("Spaces switcher: review fixes")
check(SpacesInteraction.recentWindow(inSpace: 2, mru: [9, 21], tilesInSpace: [22, 21]) == 21
      && SpacesInteraction.recentWindow(inSpace: 2, mru: [9], tilesInSpace: [22, 21]) == 22
      && SpacesInteraction.recentWindow(inSpace: 2, mru: [9], tilesInSpace: []) == nil,
      "card click: recent window by MRU, else the card's first window")
check(SpacesInteraction.moveAllowed(from: 1, to: 2, fullscreen: [])
      && !SpacesInteraction.moveAllowed(from: 1, to: 1, fullscreen: [])
      && !SpacesInteraction.moveAllowed(from: 3, to: 2, fullscreen: [3])
      && !SpacesInteraction.moveAllowed(from: 1, to: 3, fullscreen: [3]),
      "window move: not out of / into a fullscreen space, not onto itself")
check(SpacesInteraction.pillFits(CGSize(width: 80, height: 50)) && !SpacesInteraction.pillFits(CGSize(width: 34, height: 19))
      && !SpacesInteraction.pillFits(CGSize(width: 24, height: 40)), "project pill only on tiles big enough for it")

print("Auto padding & restart")
do {
    let original = Paddings(left: 30, right: 30, top: 8)
    check(AutoPadding.target(original: original, cellSize: 32, stripEnabled: true, stripScale: 0.8)
          == Paddings(left: 34, right: 34, top: 26), "auto padding: indicator + 2, strip height + 6")
    check(AutoPadding.target(original: original, cellSize: 20, stripEnabled: false, stripScale: 0.8)
          == Paddings(left: 22, right: 22, top: 8), "auto padding shrinks with the indicator; strip off keeps top")
    check(AutoPadding.parse("12\n") == 12 && AutoPadding.parse("12.0") == 12 && AutoPadding.parse("unknown key") == nil
          && AutoPadding.parse(nil) == nil, "yabai config value parsing")
    check(Relauncher.arguments(bundlePath: "/Applications/Y.app", executablePath: "/Applications/Y.app/Contents/MacOS/y")
          == ["-c", "sleep 0.5; /usr/bin/open -n '/Applications/Y.app'"]
          && Relauncher.arguments(bundlePath: "/tmp/build", executablePath: "/tmp/build/y")
          == ["-c", "sleep 0.5; '/tmp/build/y' >/dev/null 2>&1 &"], "restart relaunches the bundle (or bare binary)")
    let dir = NSTemporaryDirectory() + "fy-\(UUID().uuidString)"
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    let log = dir + "/log", path = dir + "/yabai"
    try? "#!/bin/sh\necho \"$*\" >> \(log)\n[ $# -eq 3 ] && echo 10\nexit 0\n".write(toFile: path, atomically: true, encoding: .utf8)
    try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
    let c = AutoPaddingController(client: YabaiClient(yabaiPath: path))
    c.update(enabled: true, cellSize: 32, stripEnabled: true, stripScale: 0.8)
    let applied = (try? String(contentsOfFile: log, encoding: .utf8)) ?? ""
    check(applied.contains("-m config left_padding 34") && applied.contains("-m config top_padding 26"),
          "auto padding applied via yabai config")
    c.update(enabled: false, cellSize: 32, stripEnabled: true, stripScale: 0.8)
    let restored = (try? String(contentsOfFile: log, encoding: .utf8)) ?? ""
    check(restored.contains("-m config left_padding 10") && restored.contains("-m config top_padding 10"),
          "turning it off restores the original values")
    check(!AppConfig.defaults.autoPadding && !AppConfig.load(from: #"{"style":"flag"}"#.data(using: .utf8)).autoPadding,
          "auto padding defaults off")
}

print("Search switcher: hover")
check(SpacesInteraction.hoverPasses(gate: nil, pointer: CGPoint(x: 5, y: 5)), "no gate → hover counts")
check(!SpacesInteraction.hoverPasses(gate: CGPoint(x: 100, y: 100), pointer: CGPoint(x: 103, y: 98)),
      "pointer resting where the panel opened → ignored")
check(SpacesInteraction.hoverPasses(gate: CGPoint(x: 100, y: 100), pointer: CGPoint(x: 106, y: 100)),
      "pointer moved → hover counts")
check(SpacesInteraction.actionIndex(selection: 2, count: 5, highlighted: true) == 2, "Enter acts on the highlight")
check(SpacesInteraction.actionIndex(selection: 2, count: 5, highlighted: false) == nil,
      "pointer left every tile → Enter / ⌘W / ⌘Q do nothing")
check(SpacesInteraction.actionIndex(selection: 0, count: 0, highlighted: true) == nil, "no matches → nothing")

print("Window strip: empty slots, cross-display drop")
do {
    let empty = WindowStripModel.SpaceSection(space: 3, name: "3", isVisible: true, chips: [])
    check(WindowStripModel.shows(.init(display: 2, hidden: false, sections: [empty])), "display with only empty spaces gets a strip")
    check(!WindowStripModel.shows(.init(display: 2, hidden: true, sections: [empty])), "fullscreen display gets none")
    check(!WindowStripModel.shows(.init(display: 2, hidden: false, sections: [])), "no spaces → no strip")
    let left = WindowStripModel.DropRegion(frame: CGRect(x: 0, y: 1000, width: 200, height: 20),
                                           sections: [(space: 1, minX: 0, maxX: 100), (space: 2, minX: 110, maxX: 200)])
    let right = WindowStripModel.DropRegion(frame: CGRect(x: 1800, y: 900, width: 200, height: 20),
                                            sections: [(space: 5, minX: 0, maxX: 90), (space: 6, minX: 100, maxX: 200)])
    check(WindowStripModel.dropSpace(screenX: 150, screenY: 1010, regions: [left, right]) == 2, "drop on own display")
    check(WindowStripModel.dropSpace(screenX: 1950, screenY: 910, regions: [left, right]) == 6, "drop on another display")
    check(WindowStripModel.dropSpace(screenX: 1000, screenY: 910, regions: [left, right]) == nil, "between strips → cancel")
    check(WindowStripModel.dropSpace(screenX: 1950, screenY: 500, regions: [left, right]) == nil, "far below → cancel")
}

print("Pin window on top")
do {
    var ps = YabaiSettings.defaults
    ps.rules = [WindowRule(app: "IINA", mode: .pin), WindowRule(app: "Finder", mode: .float)]
    let text = YabaiManagedConfig.generate(ps)
    check(text.contains(#"yabai -m rule --add app="IINA" manage=off sub-layer=above"#), "pin rule floats the app above others")
    check(YabaiManagedConfig.parse(text) == ps, "pin rule round-trips")
    check(FreeformImporter.importYabai(fileText: #"yabai -m rule --add app="^IINA$" manage=off sub-layer=above"#,
                                       current: YabaiSettings.defaults).settings.rules == [WindowRule(app: "^IINA$", mode: .pin)],
          "import recognises a pin rule")
    let pin = ShortcutCatalog.action(id: "pin-window-on-top")
    check(pin?.group == "Shared" && pin?.defaultHotkey == nil && pin?.command == "sh ${SCRIPTS}/togglePinWindow.sh",
          "pin shortcut: Shared, no default hotkey, runs the toggle script")
    check(ScriptInstaller.scriptNames.contains("togglePinWindow.sh"), "toggle script is installed")
}

print("ConfigPaths.autoDetect")
do {
    check(ConfigPaths.lookupOrder(tool: .yabai, xdgConfigHome: "/x", home: "/h")
          == ["/x/yabai/yabairc", "/h/.config/yabai/yabairc", "/h/.yabairc"]
          && ConfigPaths.lookupOrder(tool: .skhd, xdgConfigHome: nil, home: "/h")
          == ["/h/.config/skhd/skhdrc", "/h/.skhdrc"], "lookup order matches yabai/skhd")
    check(ConfigPaths.autoDetect(tool: .yabai, xdgConfigHome: nil, home: "/h", configFlag: nil,
                                 exists: { $0 == "/h/.yabairc" || $0 == "/h/.config/yabai/yabairc" })
          == "/h/.config/yabai/yabairc", "prefers .config over home dotfile")
    check(ConfigPaths.configFlag(inCommandLine: "/opt/homebrew/bin/yabai -c /tmp/my.rc") == "/tmp/my.rc"
          && ConfigPaths.configFlag(inCommandLine: "/opt/homebrew/bin/skhd --config /tmp/s") == "/tmp/s"
          && ConfigPaths.configFlag(inCommandLine: "/opt/homebrew/bin/yabai") == nil
          && ConfigPaths.autoDetect(tool: .yabai, xdgConfigHome: nil, home: "/h",
                                    configFlag: "/tmp/my.rc", exists: { _ in false }) == "/tmp/my.rc",
          "-c / --config flag wins")
    check(ConfigPaths.autoDetect(tool: .skhd, xdgConfigHome: nil, home: "/h", configFlag: nil,
                                 exists: { _ in false }) == "/h/.config/skhd/skhdrc",
          "falls back to first in lookup order")
}

print("AppConfig migration")
do {
    let d1 = Data(#"{"cellSize":24}"#.utf8)
    var c1 = AppConfig.load(from: d1)
    let r1 = c1.migrateManagement(presentKeys: AppConfig.presentKeys(in: d1), hasYabaiRegion: true, hasSkhdRegion: false)
    check(r1 && c1.manageYabaiConfig && !c1.manageSkhdConfig, "absent keys take region presence")
    let d2 = Data(#"{"manageYabaiConfig":false,"manageSkhdConfig":false}"#.utf8)
    var c2 = AppConfig.load(from: d2)
    let r2 = c2.migrateManagement(presentKeys: AppConfig.presentKeys(in: d2), hasYabaiRegion: true, hasSkhdRegion: true)
    check(!r2 && !c2.manageYabaiConfig && !c2.manageSkhdConfig, "explicit false respected")
}

print("")
if failures == 0 { print("ALL SELF-TESTS PASSED") }
else { print("\(failures) SELF-TEST(S) FAILED"); exit(1) }
