import Foundation
import Observation
import YiyuCore

/// Owns the skin settings and every change to them; saves them to `appearance.json` shortly after each change.
@MainActor
@Observable
final class AppearanceModel {
    private static let saveDelay: Duration = .milliseconds(600)

    private(set) var settings: AppearanceSettings
    /// Kept apart from `settings` so views that only draw with the skin (the whole panel) are
    /// not redrawn when a skin they don't show is renamed or deleted.
    private(set) var selectedSkin: Skin
    /// Why the saved skins could not be used this session; stays until the app quits.
    private(set) var loadProblem: String?
    private(set) var saveError: String?

    @ObservationIgnored private let store: AppearanceStore?
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    /// Called after the skin in use changes (another pick, or an edit to it).
    @ObservationIgnored var onSkinChanged: ((Skin) -> Void)?

    init(settings: AppearanceSettings, store: AppearanceStore?) {
        self.settings = settings
        self.selectedSkin = SkinBook.selected(settings)
        self.store = store
    }

    var isSelectedBuiltIn: Bool { SkinBook.isBuiltIn(selectedSkin.id) }
    var customSkins: [Skin] { settings.customSkins }

    func select(_ id: String) {
        update { SkinBook.selecting(id, in: $0) }
    }

    func setColor(_ color: ThemeColor, for role: ColorRole) {
        editSelected { $0.with(palette: $0.palette.with(role, color)) }
    }

    func setFont(_ family: String, for role: FontRole) {
        editSelected { $0.with(fonts: $0.fonts.with(role, family)) }
    }

    func setTextSize(_ size: TextSize) {
        editSelected { $0.with(fonts: $0.fonts.with(scale: size.scale)) }
    }

    func rename(_ id: String, to name: String) {
        update { SkinBook.renaming(id, to: name, in: $0) }
    }

    func duplicate(_ id: String) {
        update { SkinBook.duplicating(id, newID: UUID().uuidString, in: $0) }
    }

    func delete(_ id: String) {
        update { SkinBook.removing(id, from: $0) }
    }

    func reportLoadProblem(_ message: String) {
        loadProblem = message
    }

    func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        guard let store else { return }
        do {
            try store.save(settings)
            saveError = nil
        } catch {
            NSLog("Yiyu: saving %@ failed: %@", store.fileURL.path, String(describing: error))
            saveError = "没能保存皮肤设置：\(error.localizedDescription)"
        }
    }

    private func editSelected(_ edit: (Skin) -> Skin) {
        update { SkinBook.editingSelected(in: $0, newID: UUID().uuidString, edit) }
    }

    private func update(_ transform: (AppearanceSettings) -> AppearanceSettings) {
        let next = transform(settings)
        guard next != settings else { return }
        settings = next
        scheduleSave()
        let skin = SkinBook.selected(next)
        guard skin != selectedSkin else { return }
        selectedSkin = skin
        onSkinChanged?(skin)
    }

    private func scheduleSave() {
        guard store != nil else { return }
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.saveDelay)
            } catch {
                return  // Superseded by a newer change.
            }
            self?.saveNow()
        }
    }
}
