import SwiftUI
import YiyuCore

struct IconButton: View {
    let systemName: String
    var help: String = ""
    var tint: Color = Theme.inkMuted
    var size: CGFloat = 12
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct CheckMark: View {
    let isOn: Bool
    var tint: Color = Theme.gold
    let action: @MainActor () -> Void

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) { action() }
        } label: {
            CheckGlyph(isOn: isOn, tint: tint)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "标记为未完成" : "标记为完成")
    }
}

/// The circle `CheckMark` draws, without the button.
struct CheckGlyph: View {
    let isOn: Bool
    var tint: Color = Theme.gold

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isOn ? tint : tint.opacity(0.6), lineWidth: 1.2)
            if isOn {
                Circle().fill(tint)
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(Theme.paper)
            }
        }
        .frame(width: 16, height: 16)
    }
}

/// A single-line field with a leading glyph and a placeholder that stays legible on 磁青 paper.
struct InputField: View {
    @Binding var text: String
    let placeholder: String
    var leadingIcon: String = "plus"
    var focusRequest: Int = 0
    var clearsOnSubmit = true
    var onSubmit: (String) -> Void = { _ in }

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: leadingIcon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.gold)
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(Theme.body)
                        .foregroundStyle(Theme.inkFaint)
                        .lineLimit(1)
                        .allowsHitTesting(false)
                }
                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .font(Theme.body)
                    .foregroundStyle(Theme.ink)
                    .focused($isFocused)
                    .onSubmit(submit)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.field))
        .onChange(of: focusRequest) { isFocused = true }
    }

    private func submit() {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        onSubmit(value)
        if clearsOnSubmit {
            text = ""
        }
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.caption.weight(.medium))
            .foregroundStyle(Theme.inkMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.rowInset)
            .padding(.top, 14)
            .padding(.bottom, 4)
    }
}

struct EmptyHint: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.serif(15, weight: .medium))
                .foregroundStyle(Theme.ink.opacity(0.85))
            Text(detail)
                .font(Theme.caption)
                .foregroundStyle(Theme.inkMuted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.rowInset)
        .padding(.vertical, 18)
    }
}

struct Notice: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(Theme.caption)
            .foregroundStyle(Theme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.18)))
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
    }
}

/// "已完成 3" row that reveals finished items, with a button to clear them.
struct CompletedFooter: View {
    let count: Int
    let unit: String
    @Binding var isExpanded: Bool
    let onClear: @MainActor () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    Text("已完成 \(count) \(unit)")
                        .font(Theme.caption.weight(.medium))
                }
                .foregroundStyle(Theme.inkMuted)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
            Button("清除", action: onClear)
                .buttonStyle(.plain)
                .font(Theme.caption)
                .foregroundStyle(Theme.inkMuted)
                .help("删除所有已完成的项目")
        }
        .padding(.horizontal, Theme.rowInset)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }
}
