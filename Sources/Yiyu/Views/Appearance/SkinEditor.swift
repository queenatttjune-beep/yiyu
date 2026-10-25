import AppKit
import SwiftUI
import YiyuCore

/// The selected skin's name, colours and fonts. Built-in skins are copied on the first change.
struct SkinEditor: View {
    let model: AppearanceModel
    let requestDeletion: (Skin) -> Void

    var body: some View {
        let skin = model.selectedSkin
        Form {
            Section {
                identity(skin)
            }
            Section("配色") {
                ForEach(ColorRole.allCases, id: \.self) { role in
                    ColorRow(role: role, color: skin.palette[role]) { model.setColor($0, for: role) }
                }
                let hardToRead = skin.palette.hardToReadRoles
                if !hardToRead.isEmpty {
                    Label(
                        "\(hardToRead.map(\.label).joined(separator: "、"))和底色太接近，可能看不清。",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.callout)
                    .foregroundStyle(.orange)
                }
            }
            Section("字体") {
                ForEach(FontRole.allCases, id: \.self) { role in
                    FontRow(role: role, family: skin.fonts[role]) { model.setFont($0, for: role) }
                }
                Picker("字号", selection: Binding(
                    get: { TextSize(nearest: skin.fonts.scale) },
                    set: { model.setTextSize($0) }
                )) {
                    ForEach(TextSize.allCases, id: \.self) { size in
                        Text(size.label).tag(size)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder private func identity(_ skin: Skin) -> some View {
        if model.isSelectedBuiltIn {
            LabeledContent("皮肤", value: skin.name)
            Text("内置皮肤不会被改动。调整下面任何一项，都会另存为一份新的皮肤。")
                .font(.callout)
                .foregroundStyle(.secondary)
        } else {
            SkinNameField(skin: skin) { model.rename(skin.id, to: $0) }
                .id(skin.id)
        }
        HStack {
            Button("复制一份") { model.duplicate(skin.id) }
            if !model.isSelectedBuiltIn {
                Button("删除这个皮肤…", role: .destructive) { requestDeletion(skin) }
            }
        }
    }
}

/// Renames as you type; a blank name is never saved and snaps back when you leave the field.
private struct SkinNameField: View {
    let skin: Skin
    let onRename: (String) -> Void

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        LabeledContent("名称") {
            TextField("名称", text: $draft)
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
                .focused($isFocused)
                .onAppear { draft = skin.name }
                .onChange(of: draft) { _, text in onRename(text) }
                .onSubmit { draft = skin.name }
                .onChange(of: isFocused) { _, focused in
                    if !focused { draft = skin.name }
                }
        }
    }
}

private struct ColorRow: View {
    let role: ColorRole
    let color: ThemeColor
    let onChange: (ThemeColor) -> Void

    var body: some View {
        LabeledContent {
            HStack(spacing: 10) {
                HexField(color: color, onCommit: onChange)
                ColorPicker(role.label, selection: Binding(
                    get: { Color(color) },
                    set: { picked in
                        if let picked = ThemeColor(picked) { onChange(picked) }
                    }
                ), supportsOpacity: false)
                .labelsHidden()
            }
        } label: {
            Text(role.label)
            Text(role.detail)
        }
    }
}

/// The colour as #RRGGBB, for typing or pasting an exact value. Anything else reverts on leaving the field.
private struct HexField: View {
    let color: ThemeColor
    let onCommit: (ThemeColor) -> Void

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("色值", text: $draft)
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .font(.body.monospacedDigit())
            .frame(width: 84)
            .focused($isFocused)
            .onAppear { draft = color.hex }
            .onChange(of: color) { _, newColor in
                if !isFocused { draft = newColor.hex }
            }
            .onSubmit(commit)
            .onChange(of: isFocused) { _, focused in
                if !focused { commit() }
            }
    }

    private func commit() {
        guard let parsed = ThemeColor(hex: draft) else {
            draft = color.hex
            return
        }
        draft = parsed.hex
        onCommit(parsed)
    }
}

/// Chinese typefaces first under their Chinese names; every other installed family one level down.
private struct FontRow: View {
    let role: FontRole
    let family: String
    let onChange: (String) -> Void

    var body: some View {
        let selection = Binding(get: { family }, set: { onChange($0) })
        LabeledContent {
            Menu {
                Picker(role.label, selection: selection) {
                    ForEach(InstalledFonts.recommended) { option in
                        Text(option.label).tag(option.family)
                    }
                    if !InstalledFonts.isAvailable(family) {
                        Text("\(FontCatalog.label(for: family))（这台电脑没有）").tag(family)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                Menu("更多字体") {
                    Picker(role.label, selection: selection) {
                        ForEach(InstalledFonts.others, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            } label: {
                Text(FontCatalog.label(for: family))
            }
            .fixedSize()
        } label: {
            Text(role.label)
            Text(role.detail)
        }
    }
}

/// The font families on this Mac, read once.
@MainActor
private enum InstalledFonts {
    static let families = NSFontManager.shared.availableFontFamilies
    static let recommended = FontCatalog.recommended(installed: Set(families))
    static let others = FontCatalog.others(installed: families)
    private static let familySet = Set(families)

    static func isAvailable(_ family: String) -> Bool {
        family == ThemeFonts.system || familySet.contains(family)
    }
}
