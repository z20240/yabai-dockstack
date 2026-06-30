import Foundation

public final class ConfigEngine {
    private let yabaiPath, skhdPath, scriptsDir: String
    private let yabaiWriter, skhdWriter: ConfigFileWriter

    public init(yabaiPath: String, skhdPath: String,
                yabaiConfigPath: String, skhdConfigPath: String, scriptsDir: String) {
        self.yabaiPath = yabaiPath; self.skhdPath = skhdPath; self.scriptsDir = scriptsDir
        self.yabaiWriter = ConfigFileWriter(path: yabaiConfigPath)
        self.skhdWriter = ConfigFileWriter(path: skhdConfigPath)
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
        try yabaiWriter.writeManagedRegion(YabaiManagedConfig.generate(settings))
    }

    public func saveSkhd(_ bindings: [ShortcutBinding]) throws {
        try skhdWriter.writeManagedRegion(
            SkhdManagedConfig.generate(bindings, catalog: ShortcutCatalog.all, scriptsDir: scriptsDir))
    }

    public func hasYabaiRegion() -> Bool { ManagedRegion.extract(from: yabaiWriter.currentText()) != nil }
    public func hasSkhdRegion() -> Bool { ManagedRegion.extract(from: skhdWriter.currentText()) != nil }

    public func loadYabaiSettingsOrDefault() -> YabaiSettings {
        hasYabaiRegion() ? loadYabaiSettings() : DefaultTemplate.defaultYabaiSettings()
    }

    public func loadBindingsOrDefault() -> [ShortcutBinding] {
        hasSkhdRegion() ? loadBindings() : DefaultTemplate.defaultBindings()
    }

    public func importSkhd() throws -> Int {
        let existing = skhdWriter.currentText()
        guard !ManagedRegion.hasMalformedMarkers(in: existing) else {
            throw NSError(domain: "ConfigEngine", code: 3, userInfo: [NSLocalizedDescriptionKey:
                "Refusing to import: the skhd config has malformed yabai-dockstack managed markers (duplicate or unbalanced). Fix them by hand first."])
        }
        let r = FreeformImporter.importSkhd(fileText: existing, current: loadBindingsOrDefault(),
                                            catalog: ShortcutCatalog.all, scriptsDir: scriptsDir)
        guard r.importedCount > 0 else { return 0 }
        let body = SkhdManagedConfig.generate(r.bindings, catalog: ShortcutCatalog.all, scriptsDir: scriptsDir)
        try skhdWriter.writeRaw(ManagedRegion.replace(in: r.newText, with: body))
        return r.importedCount
    }

    public func importYabai() throws -> Int {
        let existing = yabaiWriter.currentText()
        guard !ManagedRegion.hasMalformedMarkers(in: existing) else {
            throw NSError(domain: "ConfigEngine", code: 3, userInfo: [NSLocalizedDescriptionKey:
                "Refusing to import: the yabai config has malformed yabai-dockstack managed markers (duplicate or unbalanced). Fix them by hand first."])
        }
        let r = FreeformImporter.importYabai(fileText: existing, current: loadYabaiSettingsOrDefault())
        guard r.importedCount > 0 else { return 0 }
        try yabaiWriter.writeRaw(ManagedRegion.replace(in: r.newText, with: YabaiManagedConfig.generate(r.settings)))
        return r.importedCount
    }

    public func applyYabai() -> (ok: Bool, output: String) {
        ConfigApplier.run(yabaiPath, ["--restart-service"])
    }
    public func applySkhd() -> (ok: Bool, output: String) {
        ConfigApplier.run(skhdPath, ["--reload"])
    }
}
