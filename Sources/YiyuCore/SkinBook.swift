import Foundation

/// The skin the user picked and the skins they made. Saved on its own in `appearance.json`.
public struct AppearanceSettings: Equatable, Sendable {
    public static let currentVersion = 1
    public static let `default` = AppearanceSettings()

    public let version: Int
    public let selectedSkinID: String
    public let customSkins: [Skin]

    public init(
        version: Int = AppearanceSettings.currentVersion,
        selectedSkinID: String = Skin.default.id,
        customSkins: [Skin] = []
    ) {
        self.version = version
        self.selectedSkinID = selectedSkinID
        self.customSkins = customSkins
    }

    public func with(selectedSkinID: String? = nil, customSkins: [Skin]? = nil) -> AppearanceSettings {
        AppearanceSettings(
            version: version,
            selectedSkinID: selectedSkinID ?? self.selectedSkinID,
            customSkins: customSkins ?? self.customSkins
        )
    }
}

extension AppearanceSettings: Codable {
    private enum CodingKeys: String, CodingKey {
        case version, selectedSkinID, customSkins
    }

    /// Custom skins that reuse a built-in id or repeat an earlier id could never be picked, so they are dropped.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decoded = try container.decodeIfPresent([Skin].self, forKey: .customSkins) ?? []
        var seen = Set(Skin.builtIns.map(\.id))
        let usable = decoded.filter { seen.insert($0.id).inserted }
        self.init(
            version: try container.decodeIfPresent(Int.self, forKey: .version) ?? AppearanceSettings.currentVersion,
            selectedSkinID: try container.decodeIfPresent(String.self, forKey: .selectedSkinID) ?? Skin.default.id,
            customSkins: usable
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(selectedSkinID, forKey: .selectedSkinID)
        try container.encode(customSkins, forKey: .customSkins)
    }
}

/// Pure operations on the skin settings. Every function returns new settings.
public enum SkinBook {
    public static let maxNameLength = 20

    public static func allSkins(_ settings: AppearanceSettings) -> [Skin] {
        Skin.builtIns + settings.customSkins
    }

    public static func isBuiltIn(_ id: String) -> Bool {
        Skin.builtIns.contains { $0.id == id }
    }

    public static func skin(_ id: String, in settings: AppearanceSettings) -> Skin? {
        allSkins(settings).first { $0.id == id }
    }

    /// The skin in use; the default one if the saved choice no longer exists.
    public static func selected(_ settings: AppearanceSettings) -> Skin {
        skin(settings.selectedSkinID, in: settings) ?? .default
    }

    public static func selecting(_ id: String, in settings: AppearanceSettings) -> AppearanceSettings {
        guard skin(id, in: settings) != nil else { return settings }
        return settings.with(selectedSkinID: id)
    }

    /// Applies `edit` to the selected skin. A built-in skin is never changed: the edit lands on
    /// a new copy called 「我的…」, which becomes the selection. `newID` names that copy.
    public static func editingSelected(
        in settings: AppearanceSettings,
        newID: String,
        _ edit: (Skin) -> Skin
    ) -> AppearanceSettings {
        let current = selected(settings)
        let edited = edit(current)
        guard edited.palette != current.palette || edited.fonts != current.fonts || edited.name != current.name else {
            return settings
        }
        guard !isBuiltIn(current.id) else {
            let copy = Skin(id: newID, name: uniqueName(copyName(of: current), in: settings), palette: edited.palette, fonts: edited.fonts)
            return settings.with(selectedSkinID: newID, customSkins: settings.customSkins + [copy])
        }
        let updated = Skin(id: current.id, name: edited.name, palette: edited.palette, fonts: edited.fonts)
        return settings.with(customSkins: settings.customSkins.map { $0.id == current.id ? updated : $0 })
    }

    /// Adds a copy of any skin and selects it.
    public static func duplicating(_ id: String, newID: String, in settings: AppearanceSettings) -> AppearanceSettings {
        guard let source = skin(id, in: settings) else { return settings }
        let copy = Skin(id: newID, name: uniqueName(copyName(of: source), in: settings), palette: source.palette, fonts: source.fonts)
        return settings.with(selectedSkinID: newID, customSkins: settings.customSkins + [copy])
    }

    /// Renames one of the user's skins. Blank names are ignored; long ones are cut to `maxNameLength`.
    public static func renaming(_ id: String, to name: String, in settings: AppearanceSettings) -> AppearanceSettings {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxNameLength))
        guard !trimmed.isEmpty else { return settings }
        return settings.with(customSkins: settings.customSkins.map { $0.id == id ? $0.with(name: trimmed) : $0 })
    }

    /// Deletes one of the user's skins; if it was in use, the default skin takes over.
    public static func removing(_ id: String, from settings: AppearanceSettings) -> AppearanceSettings {
        guard settings.customSkins.contains(where: { $0.id == id }) else { return settings }
        return settings.with(
            selectedSkinID: settings.selectedSkinID == id ? Skin.default.id : settings.selectedSkinID,
            customSkins: settings.customSkins.filter { $0.id != id }
        )
    }

    private static func copyName(of skin: Skin) -> String {
        isBuiltIn(skin.id) ? "我的\(skin.name)" : skin.name
    }

    private static func uniqueName(_ base: String, in settings: AppearanceSettings) -> String {
        let taken = Set(allSkins(settings).map(\.name))
        guard taken.contains(base) else { return base }
        var number = 2
        while taken.contains("\(base) \(number)") {
            number += 1
        }
        return "\(base) \(number)"
    }
}
