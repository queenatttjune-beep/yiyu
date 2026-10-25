import SwiftUI
import YiyuCore

struct MemosPage: View {
    let model: AppModel
    let ui: PanelState

    @State private var query = ""

    var body: some View {
        if let id = ui.openMemoID, let memo = model.memo(id) {
            MemoEditor(memo: memo, model: model, onClose: close)
        } else {
            list
        }
    }

    private var list: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                InputField(
                    text: $query,
                    placeholder: "搜索备忘",
                    leadingIcon: "magnifyingglass",
                    focusRequest: ui.focusRequest,
                    clearsOnSubmit: false
                )
                IconButton(systemName: "square.and.pencil", help: "新建备忘", tint: Theme.gold, size: 14) {
                    ui.openMemoID = model.createMemo()
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 8)
            .padding(.bottom, 4)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    let memos = model.memos(matching: query)
                    if memos.isEmpty {
                        if query.isEmpty {
                            EmptyHint(title: "还没有备忘。", detail: "点右上角的笔新建一条。地址、单号、随手的想法都可以放这里。")
                        } else {
                            EmptyHint(title: "没有找到「\(query)」。", detail: "换个关键词试试。")
                        }
                    }
                    ForEach(memos) { memo in
                        MemoRow(memo: memo, model: model) { ui.openMemoID = memo.id }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func close() {
        ui.openMemoID = nil
        model.pruneEmptyMemos(keeping: nil)
    }
}

private struct MemoRow: View {
    let memo: Memo
    let model: AppModel
    let onOpen: @MainActor () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        if memo.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.gold)
                        }
                        Text(memo.title)
                            .font(Theme.bodyStrong)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                    }
                    if !memo.preview.isEmpty {
                        Text(memo.preview)
                            .font(Theme.caption)
                            .foregroundStyle(Theme.inkMuted)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 6)
                Text(model.labels.relativeDay(DayKey(memo.updatedAt, calendar: model.calendar), today: model.today))
                    .font(Theme.caption)
                    .foregroundStyle(Theme.inkFaint)
            }
            .padding(.horizontal, Theme.rowInset)
            .padding(.vertical, 8)
            .background(isHovering ? Theme.field.opacity(0.5) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button(memo.isPinned ? "取消置顶" : "置顶") { model.toggleMemoPin(memo.id) }
            Divider()
            Button("删除", role: .destructive) { model.deleteMemo(memo.id) }
        }
    }
}

private struct MemoEditor: View {
    let memo: Memo
    let model: AppModel
    let onClose: @MainActor () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 2) {
                Button(action: onClose) {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .semibold))
                        Text("全部备忘")
                            .font(Theme.caption.weight(.semibold))
                    }
                    .foregroundStyle(Theme.gold)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                IconButton(
                    systemName: memo.isPinned ? "pin.fill" : "pin",
                    help: memo.isPinned ? "取消置顶" : "置顶",
                    tint: memo.isPinned ? Theme.gold : Theme.inkMuted,
                    size: 11
                ) { model.toggleMemoPin(memo.id) }
                IconButton(systemName: "trash", help: "删除这条备忘", size: 11) {
                    model.deleteMemo(memo.id)
                    onClose()
                }
            }
            .padding(.leading, Theme.rowInset)
            .padding(.trailing, 8)

            ZStack(alignment: .topLeading) {
                TextEditor(text: Binding(
                    get: { model.memo(memo.id)?.text ?? "" },
                    set: { model.updateMemo(memo.id, text: $0) }
                ))
                .font(Theme.body)
                .foregroundStyle(Theme.ink)
                .lineSpacing(4)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.never)
                .focused($isFocused)

                if memo.text.isEmpty {
                    Text("第一行会当作标题")
                        .font(Theme.body)
                        .foregroundStyle(Theme.inkFaint)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, 11)
            .padding(.top, 6)

            Text("修改于 \(model.labels.relativeDay(DayKey(memo.updatedAt, calendar: model.calendar), today: model.today)) \(memo.updatedAt.formatted(date: .omitted, time: .shortened))")
                .font(Theme.caption)
                .foregroundStyle(Theme.inkFaint)
                .padding(.horizontal, Theme.rowInset)
                .padding(.vertical, 10)
        }
        .onAppear { isFocused = true }
    }
}
