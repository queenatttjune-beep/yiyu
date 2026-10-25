import Foundation
import Observation

enum PanelTab: String, CaseIterable, Identifiable {
    case today
    case backlog
    case reminders
    case memos
    case diary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "今天"
        case .backlog: "待办"
        case .reminders: "提醒"
        case .memos: "备忘"
        case .diary: "日记"
        }
    }

    var shortcutHint: String {
        let position = (Self.allCases.firstIndex(of: self) ?? 0) + 1
        return "⌘\(position)"
    }
}

/// Window-level UI state shared between the panel controller and the SwiftUI views.
@MainActor
@Observable
final class PanelState {
    var isCollapsed = false
    var tab: PanelTab = .today
    /// Bumped to ask the current page to focus its input field.
    var focusRequest = 0
    /// The memo open in the editor; kept here so it survives switching tabs.
    var openMemoID: UUID?
}

/// Window commands the SwiftUI views can trigger.
struct PanelActions {
    var toggleCollapsed: @MainActor () -> Void
    var expand: @MainActor () -> Void
    var hidePanel: @MainActor () -> Void
    var openDataFolder: @MainActor () -> Void
    var quit: @MainActor () -> Void

    static let preview = PanelActions(
        toggleCollapsed: {}, expand: {}, hidePanel: {}, openDataFolder: {}, quit: {}
    )
}
