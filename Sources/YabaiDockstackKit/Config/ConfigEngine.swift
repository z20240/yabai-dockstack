import Foundation

public struct ApplyPlan: Equatable {
    public let regionExists: Bool
    public let linesToComment: Int
    public init(regionExists: Bool, linesToComment: Int) {
        self.regionExists = regionExists; self.linesToComment = linesToComment
    }
    public var needsConfirmation: Bool { !regionExists || linesToComment > 0 }
}

public final class ConfigEngine {
    public var manageYabaiConfig: Bool
    public var manageSkhdConfig: Bool
    private let yabaiPath, skhdPath, scriptsDir: String
    private var yabaiWriter, skhdWriter: ConfigFileWriter
    public private(set) var yabaiConfigPath: String
    public private(set) var skhdConfigPath: String

    public init(yabaiPath: String, skhdPath: String,
                yabaiConfigPath: String, skhdConfigPath: String, scriptsDir: String,
                manageYabaiConfig: Bool = false, manageSkhdConfig: Bool = false) {
        self.manageYabaiConfig = manageYabaiConfig
        self.manageSkhdConfig = manageSkhdConfig
        self.yabaiPath = yabaiPath; self.skhdPath = skhdPath; self.scriptsDir = scriptsDir
        self.yabaiWriter = ConfigFileWriter(path: yabaiConfigPath)
        self.skhdWriter = ConfigFileWriter(path: skhdConfigPath)
        self.yabaiConfigPath = self.yabaiWriter.path
        self.skhdConfigPath = self.skhdWriter.path
    }

    public func setConfigPaths(yabai: String, skhd: String) {
        yabaiWriter = ConfigFileWriter(path: yabai)
        skhdWriter = ConfigFileWriter(path: skhd)
        yabaiConfigPath = yabaiWriter.path
        skhdConfigPath = skhdWriter.path
    }

    public func yabaiFileText() -> String { yabaiWriter.currentText() }
    public func skhdFileText() -> String { skhdWriter.currentText() }
    public func yabaiFileState() -> YabaiFileState { YabaiFileState.parse(yabaiFileText()) }
    public func faithfulSkhd() -> FaithfulSkhdView {
        FaithfulSkhd.parse(skhdFileText(), catalog: ShortcutCatalog.all, scriptsDir: scriptsDir)
    }

    public func yabaiApplyPlan(_ settings: YabaiSettings) -> ApplyPlan {
        let text = yabaiFileText()
        return ApplyPlan(regionExists: ManagedRegion.extract(from: text) != nil,
                         linesToComment: FreeformImporter.importYabai(fileText: text, current: settings).importedCount)
    }

    public func skhdApplyPlan(_ bindings: [ShortcutBinding]) -> ApplyPlan {
        let text = skhdFileText()
        return ApplyPlan(regionExists: ManagedRegion.extract(from: text) != nil,
                         linesToComment: FreeformImporter.importSkhd(fileText: text, current: bindings,
                             catalog: ShortcutCatalog.all, scriptsDir: scriptsDir).importedCount)
    }

    private func malformed(_ what: String, _ verb: String) -> NSError {
        NSError(domain: "ConfigEngine", code: 3, userInfo: [NSLocalizedDescriptionKey:
            "Refusing to \(verb): the \(what) config has malformed yabai-dockstack managed markers (duplicate or unbalanced). Fix them by hand first."])
    }

    public func loadYabaiSettings() -> YabaiSettings {
        guard let body = ManagedRegion.extract(from: yabaiWriter.currentText()) else {
            return YabaiSettings.defaults
        }
        return YabaiManagedConfig.parse(body)
    }

    public func loadBindings() -> [ShortcutBinding] {
        let parsed = ManagedRegion.extract(from: skhdWriter.currentText())
            .map { SkhdManagedConfig.parse($0, catalog: ShortcutCatalog.all, scriptsDir: scriptsDir) } ?? []
        let byID = Dictionary(parsed.map { ($0.actionID, $0) }, uniquingKeysWith: { first, _ in first })
        return ShortcutCatalog.all.map { action in
            byID[action.id] ?? ShortcutBinding(actionID: action.id, enabled: false, hotkey: nil)
        }
    }

    public func saveYabai(_ settings: YabaiSettings) throws {
        try requireYabaiManagement()
        let existing = yabaiWriter.currentText()
        guard !ManagedRegion.hasMalformedMarkers(in: existing) else { throw malformed("yabai", "write") }
        let newText = FreeformImporter.importYabai(fileText: existing, current: settings).newText
        try yabaiWriter.writeRaw(ManagedRegion.replace(in: newText, with: YabaiManagedConfig.generate(settings)))
    }

    public func saveSkhd(_ bindings: [ShortcutBinding]) throws {
        try requireSkhdManagement()
        let existing = skhdWriter.currentText()
        guard !ManagedRegion.hasMalformedMarkers(in: existing) else { throw malformed("skhd", "write") }
        let newText = FreeformImporter.importSkhd(fileText: existing, current: bindings,
                                                  catalog: ShortcutCatalog.all, scriptsDir: scriptsDir).newText
        try skhdWriter.writeRaw(ManagedRegion.replace(in: newText,
            with: SkhdManagedConfig.generate(bindings, catalog: ShortcutCatalog.all, scriptsDir: scriptsDir)))
    }

    public func hasYabaiRegion() -> Bool { ManagedRegion.extract(from: yabaiWriter.currentText()) != nil }
    public func hasSkhdRegion() -> Bool { ManagedRegion.extract(from: skhdWriter.currentText()) != nil }

    public func loadYabaiSettingsOrDefault() -> YabaiSettings {
        hasYabaiRegion() ? loadYabaiSettings() : DefaultTemplate.defaultYabaiSettings()
    }

    public func loadBindingsOrDefault() -> [ShortcutBinding] {
        hasSkhdRegion() ? loadBindings() : DefaultTemplate.defaultBindings()
    }

    public func importSkhd(base: [ShortcutBinding]) throws -> (count: Int, bindings: [ShortcutBinding]) {
        try requireSkhdManagement()
        let existing = skhdWriter.currentText()
        guard !ManagedRegion.hasMalformedMarkers(in: existing) else { throw malformed("skhd", "import") }
        let r = FreeformImporter.importSkhd(fileText: existing, current: base,
                                            catalog: ShortcutCatalog.all, scriptsDir: scriptsDir)
        guard r.importedCount > 0 else { return (0, base) }
        let body = SkhdManagedConfig.generate(r.bindings, catalog: ShortcutCatalog.all, scriptsDir: scriptsDir)
        try skhdWriter.writeRaw(ManagedRegion.replace(in: r.newText, with: body))
        return (r.importedCount, r.bindings)
    }

    public func importYabai(base: YabaiSettings) throws -> (count: Int, settings: YabaiSettings) {
        try requireYabaiManagement()
        let existing = yabaiWriter.currentText()
        guard !ManagedRegion.hasMalformedMarkers(in: existing) else { throw malformed("yabai", "import") }
        let r = FreeformImporter.importYabai(fileText: existing, current: base)
        guard r.importedCount > 0 else { return (0, base) }
        try yabaiWriter.writeRaw(ManagedRegion.replace(in: r.newText, with: YabaiManagedConfig.generate(r.settings)))
        return (r.importedCount, r.settings)
    }

    public func applyYabai() -> (ok: Bool, output: String) {
        guard manageYabaiConfig else { return (false, L10n.t("ui.yabai.notAllowed")) }
        return ConfigApplier.run(yabaiPath, ["--restart-service"])
    }
    private func requireYabaiManagement() throws {
        guard manageYabaiConfig else {
            throw NSError(domain: "ConfigEngine", code: 4, userInfo: [
                NSLocalizedDescriptionKey: L10n.t("ui.yabai.notAllowed")])
        }
    }
    public func applySkhd() -> (ok: Bool, output: String) {
        guard manageSkhdConfig else { return (false, L10n.t("ui.keyboard.notAllowed")) }
        return ConfigApplier.run(skhdPath, ["--reload"])
    }
    private func requireSkhdManagement() throws {
        guard manageSkhdConfig else {
            throw NSError(domain: "ConfigEngine", code: 5, userInfo: [
                NSLocalizedDescriptionKey: L10n.t("ui.keyboard.notAllowed")])
        }
    }
}
