import SwiftUI
import YiyuCore

/// The collapsed panel: a small round badge drawn as a moon gate. Click to open, drag to move.
struct CollapsedBadge: View {
    private static let idleOpacity = 0.78

    let model: AppModel
    let onExpand: @MainActor () -> Void
    let onDragEnd: @MainActor () -> Void

    @State private var isHovering = false
    @State private var isHopping = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var badge: PanelBadge {
        PanelBadge(todaySummary: model.todaySummary, dueReminders: model.dueReminders.count)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(Theme.paper)
                .overlay(Circle().strokeBorder(Theme.goldFaint, lineWidth: 0.8))
                .overlay(MoonGateMark().padding(2))
            if badge.needsAttention {
                Circle()
                    .fill(Theme.seal)
                    .overlay(Circle().strokeBorder(Theme.paper, lineWidth: 1.5))
                    .frame(width: 11, height: 11)
                    .offset(x: -2, y: 2)
            }
        }
        .frame(width: PanelBadge.size, height: PanelBadge.size)
        .scaleEffect(isHopping ? 1.12 : 1, anchor: .bottom)
        .opacity(isHovering || badge.needsAttention ? 1 : Self.idleOpacity)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .overlay(WindowDragArea(hint: badge.hint, onClick: onExpand, onDragEnd: onDragEnd))
        .onHover { isHovering = $0 }
        .onChange(of: model.firedReminders.count) { old, new in
            if new > old { hop() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(badge.hint)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "展开") { onExpand() }
    }

    /// One small hop when a reminder goes off, so the badge is noticed without staying busy.
    private func hop() {
        guard !reduceMotion else { return }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.45)) { isHopping = true }
        Task {
            try? await Task.sleep(for: .milliseconds(260))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isHopping = false }
        }
    }
}
