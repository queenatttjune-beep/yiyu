import SwiftUI
import YiyuCore

/// Every skin as a small sheet of its own paper, like the sample pages of a 笺谱.
struct SkinGallery: View {
    let model: AppearanceModel
    let requestDeletion: (Skin) -> Void

    var body: some View {
        let selectedID = model.selectedSkin.id
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                cards(selectedID: selectedID)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
            }
            .onAppear { proxy.scrollTo(selectedID) }
            .onChange(of: selectedID) { _, id in
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id) }
            }
        }
    }

    private func cards(selectedID: String) -> some View {
        HStack(alignment: .top, spacing: 28) {
            group("内置") {
                ForEach(Skin.builtIns) { skin in
                    SkinCard(skin: skin, isSelected: skin.id == selectedID) { model.select(skin.id) }
                        .id(skin.id)
                        .contextMenu {
                            Button("复制一份") { model.duplicate(skin.id) }
                        }
                }
            }
            group("我的") {
                if model.customSkins.isEmpty {
                    Text("改动任何一种颜色或字体，\n就会另存一份在这里。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .frame(height: SkinCard.swatchSize.height + 6)
                }
                ForEach(model.customSkins) { skin in
                    SkinCard(skin: skin, isSelected: skin.id == selectedID) { model.select(skin.id) }
                        .id(skin.id)
                        .contextMenu {
                            Button("复制一份") { model.duplicate(skin.id) }
                            Divider()
                            Button("删除…", role: .destructive) { requestDeletion(skin) }
                        }
                }
            }
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 12) {
                content()
            }
        }
    }
}

struct SkinCard: View {
    static let swatchSize = CGSize(width: 84, height: 90)

    let skin: Skin
    let isSelected: Bool
    let action: @MainActor () -> Void

    private var palette: ThemePalette { skin.palette }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                swatch
                Text(skin.name)
                    .font(.family(skin.fonts.display, size: 13, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .padding(.leading, 4)
                    .frame(width: Self.swatchSize.width + 6, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(skin.name)
        .accessibilityLabel(skin.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Today's date in the skin's heading font and accent, a line of text and a seal.
    private var swatch: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(Calendar.current.component(.day, from: Date()))")
                    .font(.family(skin.fonts.display, size: 26, weight: .semibold))
                    .foregroundStyle(Color(palette.accent))
                    .monospacedDigit()
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(palette.alert))
                    .frame(width: 6, height: 13)
            }
            Capsule().fill(Color(palette.ink)).frame(width: 48, height: 3)
            Capsule().fill(Color(palette.inkMuted)).frame(width: 30, height: 3)
            Spacer(minLength: 0)
            HStack(spacing: 5) {
                Circle().fill(Color(palette.accent)).frame(width: 7, height: 7)
                Capsule().fill(Color(palette.field)).frame(height: 7)
            }
        }
        .padding(10)
        .frame(width: Self.swatchSize.width, height: Self.swatchSize.height, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color(palette.paper)))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
        )
        .padding(3)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2.5)
        )
    }
}
