import SwiftUI
import YiyuCore

/// Shown in place of the diary editor: pick a style, let the AI rewrite the day's entry,
/// then use that version or leave the original alone.
struct PolishPanel: View {
    let model: AppModel
    let day: DayKey
    @Bindable var polisher: DiaryPolisher

    @State private var isAddingStyle = false

    private var selectedStyle: WritingStyle {
        model.writingStyles.first { $0.id == polisher.selectedStyleID } ?? WritingStyle.builtIns[0]
    }

    private var diaryText: String { model.diaryText(for: day) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if polisher.isShowingSettings {
                AISettingsForm(settings: polisher.settings) { polisher.isShowingSettings = false }
            } else {
                styleChips
                if isAddingStyle {
                    NewStyleForm(model: model) { newID in
                        isAddingStyle = false
                        if let newID { polisher.selectedStyleID = newID }
                    }
                } else {
                    Text(selectedStyle.instruction)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.inkMuted)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                result
                actions
                Text("这一天的日记会发给 \(serviceName)。")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .padding(.horizontal, Theme.rowInset)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack(spacing: 2) {
            Text(polisher.isShowingSettings ? "AI 设置" : "润色这一天")
                .font(Theme.serif(15, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Spacer()
            if !polisher.isShowingSettings {
                IconButton(systemName: "gearshape", help: "AI 设置", size: 12) { polisher.isShowingSettings = true }
            }
            IconButton(systemName: "xmark", help: "收起，回到日记", size: 11) { polisher.close() }
        }
    }

    private var styleChips: some View {
        WrapLayout(spacing: 6) {
            ForEach(model.writingStyles) { style in
                StyleChip(title: style.name, isSelected: style.id == polisher.selectedStyleID) {
                    polisher.selectedStyleID = style.id
                }
                .contextMenu {
                    if !style.isBuiltIn {
                        Button("删除这个风格", role: .destructive) {
                            if polisher.selectedStyleID == style.id {
                                polisher.selectedStyleID = WritingStyle.builtIns[0].id
                            }
                            model.removeStyle(style.id)
                        }
                    }
                }
            }
            StyleChip(title: "＋ 自定义", isSelected: false, isOutlined: true) { isAddingStyle.toggle() }
        }
    }

    @ViewBuilder private var result: some View {
        switch polisher.phase {
        case .idle:
            Text("原文不会被改动。看过润色后的版本，再决定用不用。")
                .font(Theme.caption)
                .foregroundStyle(Theme.inkMuted)
            Spacer(minLength: 0)
        case .working:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("正在润色……")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.inkMuted)
            }
            Spacer(minLength: 0)
        case .done(let text):
            ScrollView {
                Text(text)
                    .font(Theme.diary(14.5))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(7)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .scrollIndicators(.never)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.field.opacity(0.6)))
            .frame(maxHeight: .infinity)
        case .failed(let message):
            Text(message)
                .font(Theme.caption)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.seal.opacity(0.18)))
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private var actions: some View {
        HStack(spacing: 8) {
            if case .done = polisher.phase {
                Button("用这一版") { polisher.accept(into: model) }
                    .buttonStyle(PanelButtonStyle(isPrimary: true))
                Button("再写一版") { polisher.polish(diaryText, style: selectedStyle) }
                    .buttonStyle(PanelButtonStyle(isPrimary: false))
            } else {
                Button(polisher.phase == .working ? "润色中" : "开始润色") {
                    polisher.polish(diaryText, style: selectedStyle)
                }
                .buttonStyle(PanelButtonStyle(isPrimary: true))
                .disabled(polisher.phase == .working || DiaryBook.characterCount(diaryText) == 0)
            }
        }
    }

    private var serviceName: String {
        URL(string: polisher.settings.endpoint.baseURL)?.host ?? polisher.settings.endpoint.baseURL
    }
}

private struct StyleChip: View {
    let title: String
    let isSelected: Bool
    var isOutlined = false
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.text(12.5, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Theme.paper : (isOutlined ? Theme.gold : Theme.ink))
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(Capsule().fill(isSelected ? Theme.gold : (isOutlined ? Color.clear : Theme.field)))
                .overlay(Capsule().strokeBorder(isOutlined ? Theme.goldFaint : Color.clear, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Name a style and describe it in a sentence; it is saved with the rest of the data.
private struct NewStyleForm: View {
    let model: AppModel
    let onFinish: @MainActor (String?) -> Void

    @State private var name = ""
    @State private var instruction = ""
    @State private var problem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FormField(label: "名字", text: $name, placeholder: "比如：汪曾祺")
            FormField(label: "要求", text: $instruction, placeholder: "比如：平淡有味，多写吃食和草木")
            if let problem {
                Text(problem)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.seal)
            }
            HStack(spacing: 8) {
                Button("添加这个风格", action: add)
                    .buttonStyle(PanelButtonStyle(isPrimary: true))
                Button("取消") { onFinish(nil) }
                    .buttonStyle(PanelButtonStyle(isPrimary: false))
            }
        }
    }

    private func add() {
        let before = Set(model.data.customStyles.map(\.id))
        model.addStyle(name: name, instruction: instruction)
        guard let added = model.data.customStyles.first(where: { !before.contains($0.id) }) else {
            problem = "名字和要求都要填，而且名字不能和已有风格重复。"
            return
        }
        onFinish(added.id)
    }
}

/// Lays children out left to right, wrapping onto new lines when the row is full.
struct WrapLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        subviews.indices.reduce(into: [Row()]) { rows, index in
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row(indices: [index], width: size.width, height: size.height))
            } else {
                rows[rows.count - 1].indices.append(index)
                rows[rows.count - 1].width = needed
                rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
            }
        }
    }
}
