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
try? eng.saveYabai(es)
check(eng.loadYabaiSettings().gap == 17, "engine yabai round-trip")
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
check((try? impYE.importYabai()) == 1, "engine importYabai migrates one setting")
check(impYE.loadYabaiSettings().gap == 7, "engine importYabai: gap reflects imported value")
try? FileManager.default.removeItem(atPath: impY)
try? FileManager.default.removeItem(atPath: impY + ".bak")

let idemP = NSTemporaryDirectory() + "yst-imp-idem.skhdrc"
try? "cmd - f3: sh ~/.config/yabai/scripts/taggleShowHideDesktop.sh\n".write(toFile: idemP, atomically: true, encoding: .utf8)
let idemE = ConfigEngine(yabaiPath: "/usr/bin/true", skhdPath: "/usr/bin/true",
                         yabaiConfigPath: idemP + ".y", skhdConfigPath: idemP,
                         scriptsDir: "/Users/me/.config/yabai-dockstack/scripts")
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

print("")
if failures == 0 { print("ALL SELF-TESTS PASSED") }
else { print("\(failures) SELF-TEST(S) FAILED"); exit(1) }
