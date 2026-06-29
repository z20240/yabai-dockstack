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
        let byID = Dictionary(uniqueKeysWithValues: parsed.map { ($0.actionID, $0) })
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

    public func applyYabai() -> (ok: Bool, output: String) {
        ConfigApplier.run(yabaiPath, ["--restart-service"])
    }
    public func applySkhd() -> (ok: Bool, output: String) {
        ConfigApplier.run(skhdPath, ["--reload"])
    }
}
