import SwiftUI
import YiyuCore

struct DiaryPage: View {
    private static let recentDayCount = 14

    let model: AppModel
    let ui: PanelState

    /// `nil` follows today, so the page moves to the new day at midnight.
    @State private var pickedDay: DayKey?
    /// The day being typed into; holds still if midnight passes mid-sentence.
    @State private var editingDay: DayKey?
    @FocusState private var isEditorFocused: Bool
    @Environment(DiaryPolisher.self) private var polisher

    private var day: DayKey { pickedDay ?? editingDay ?? model.today }
    private var isToday: Bool { day == model.today }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            dayHeader
            if polisher.isOpen {
                PolishPanel(model: model, day: day, polisher: polisher)
            } else {
                editor
                footer
            }
        }
        .onChange(of: day) {
            polisher.close()
        }
    }

    private var dayHeader: some View {
        HStack(spacing: 4) {
            IconButton(systemName: "chevron.left", help: "前一天") { move(by: -1) }
            VStack(alignment: .leading, spacing: 2) {
                Text(model.labels.headerDate(day))
                    .font(Theme.serif(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("农历\(model.labels.lunarDate(day))")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.inkMuted)
            }
            IconButton(systemName: "chevron.right", help: "后一天") { move(by: 1) }
                .disabled(isToday)
                .opacity(isToday ? 0.3 : 1)
            Spacer()
            if !isToday {
                Button("回到今天") { pickedDay = nil }
                    .buttonStyle(.plain)
                    .font(Theme.caption.weight(.semibold))
                    .foregroundStyle(Theme.gold)
            }
            if !polisher.isOpen {
                if polisher.canUndo(in: model, day: day) {
                    Button("撤销润色") { polisher.undo(in: model, day: day) }
                        .buttonStyle(.plain)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.inkMuted)
                        .help("换回润色前的原文")
                }
                Button(action: polisher.open) {
                    Label("润色", systemImage: "wand.and.stars")
                        .font(Theme.caption.weight(.semibold))
                        .foregroundStyle(Theme.gold)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .overlay(Capsule().strokeBorder(Theme.goldFaint, lineWidth: 1))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("用 AI 把这一天的日记润色成你喜欢的风格")
            }
        }
        .padding(.horizontal, 8)
        .padding(.trailing, 8)
    }

    private var editor: some View {
        let text = model.diaryText(for: day)
        return ZStack(alignment: .topLeading) {
            TextEditor(text: Binding(
                get: { model.diaryText(for: day) },
                set: { model.writeDiary($0, for: day) }
            ))
            .font(Theme.serif(14.5))
            .foregroundStyle(Theme.ink)
            .lineSpacing(7)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.never)
            .focused($isEditorFocused)
            .onChange(of: isEditorFocused) { _, focused in
                editingDay = focused ? day : nil
            }

            if text.isEmpty {
                Text(isToday ? "今天过得怎么样？" : "这一天没有写日记。")
                    .font(Theme.serif(14.5))
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
        }
        .padding(.horizontal, 11)
        .padding(.top, 10)
        .id(day)
    }

    private var footer: some View {
        HStack(spacing: 5) {
            ForEach(recentDays, id: \.self) { recent in
                Button { pickedDay = recent == model.today ? nil : recent } label: {
                    Circle()
                        .fill(model.diaryDays.contains(recent) ? Theme.gold : Color.clear)
                        .overlay(Circle().strokeBorder(Theme.inkFaint, lineWidth: model.diaryDays.contains(recent) ? 0 : 1))
                        .frame(width: 7, height: 7)
                        .padding(2)
                        .overlay(Circle().strokeBorder(recent == day ? Theme.gold : Color.clear, lineWidth: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(model.labels.headerDate(recent))
            }
            Spacer()
            Text("\(DiaryBook.characterCount(model.diaryText(for: day))) 字")
                .font(Theme.caption.monospacedDigit())
                .foregroundStyle(Theme.inkFaint)
        }
        .padding(.horizontal, Theme.rowInset)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }

    /// The last two weeks, oldest first, ending today.
    private var recentDays: [DayKey] {
        (0..<Self.recentDayCount).reversed().map { model.today.adding(days: -$0, calendar: model.calendar) }
    }

    private func move(by days: Int) {
        let target = day.adding(days: days, calendar: model.calendar)
        pickedDay = target >= model.today ? nil : target
    }
}
