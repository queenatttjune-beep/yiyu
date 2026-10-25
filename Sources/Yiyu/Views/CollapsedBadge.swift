import SwiftUI
import YiyuCore

/// The collapsed panel: a small round badge with a little reader in it. Click to open, drag to move.
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
                .overlay(LittleReader().padding(2))
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

/// A small person with a topknot, sitting and reading, drawn in gold on 磁青.
/// Laid out on a 44 × 44 grid and scaled to fit.
struct LittleReader: View {
    private static let grid: CGFloat = 44

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / Self.grid
            context.translateBy(
                x: (size.width - Self.grid * scale) / 2,
                y: (size.height - Self.grid * scale) / 2
            )
            context.scaleBy(x: scale, y: scale)
            draw(in: &context)
        }
        // The canvas reads the skin while drawing, outside `body`, so it would not repaint on its own.
        .id(Theme.skin)
        .accessibilityHidden(true)
    }

    private func draw(in context: inout GraphicsContext) {
        let gold = GraphicsContext.Shading.color(Theme.gold)
        let paper = GraphicsContext.Shading.color(Theme.paper)

        // Robe: narrow at the shoulders, flaring to a rounded hem.
        var robe = Path()
        robe.move(to: CGPoint(x: 22, y: 23))
        robe.addCurve(to: CGPoint(x: 11, y: 37), control1: CGPoint(x: 15, y: 23.5), control2: CGPoint(x: 11.5, y: 30))
        robe.addQuadCurve(to: CGPoint(x: 33, y: 37), control: CGPoint(x: 22, y: 40.5))
        robe.addCurve(to: CGPoint(x: 22, y: 23), control1: CGPoint(x: 32.5, y: 30), control2: CGPoint(x: 29, y: 23.5))
        context.fill(robe, with: gold)

        // Head and topknot.
        context.fill(Path(ellipseIn: CGRect(x: 15.5, y: 9.5, width: 13, height: 13)), with: gold)
        context.fill(Path(ellipseIn: CGRect(x: 19.2, y: 5, width: 5.6, height: 5.6)), with: gold)
        var hairpin = Path()
        hairpin.move(to: CGPoint(x: 17.5, y: 8.4))
        hairpin.addLine(to: CGPoint(x: 26.8, y: 6.8))
        context.stroke(hairpin, with: paper, lineWidth: 0.9)

        // Eyes cast down at the book, and a touch of blush.
        for x in [19.6, 24.4] {
            var eye = Path()
            eye.move(to: CGPoint(x: x - 1.3, y: 16.6))
            eye.addQuadCurve(to: CGPoint(x: x + 1.3, y: 16.6), control: CGPoint(x: x, y: 18))
            context.stroke(eye, with: paper, style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
        }
        for x in [17.8, 26.2] {
            context.fill(
                Path(ellipseIn: CGRect(x: x - 1.2, y: 18.6, width: 2.4, height: 1.4)),
                with: .color(Theme.seal.opacity(0.55))
            )
        }

        // An open book held in front, with a crease down the middle.
        var book = Path()
        book.move(to: CGPoint(x: 22, y: 29.5))
        book.addQuadCurve(to: CGPoint(x: 14.5, y: 28.2), control: CGPoint(x: 18, y: 27.6))
        book.addLine(to: CGPoint(x: 15.2, y: 33.6))
        book.addQuadCurve(to: CGPoint(x: 22, y: 34.6), control: CGPoint(x: 18.6, y: 33))
        book.addQuadCurve(to: CGPoint(x: 28.8, y: 33.6), control: CGPoint(x: 25.4, y: 33))
        book.addLine(to: CGPoint(x: 29.5, y: 28.2))
        book.addQuadCurve(to: CGPoint(x: 22, y: 29.5), control: CGPoint(x: 26, y: 27.6))
        context.fill(book, with: .color(Theme.ink))
        var crease = Path()
        crease.move(to: CGPoint(x: 22, y: 29.6))
        crease.addLine(to: CGPoint(x: 22, y: 34.4))
        context.stroke(crease, with: .color(Theme.inkMuted), lineWidth: 0.6)
    }
}
