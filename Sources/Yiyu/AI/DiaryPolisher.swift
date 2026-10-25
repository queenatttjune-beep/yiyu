import Foundation
import Observation
import YiyuCore

/// Runs one polish at a time for one diary day and remembers the original text so a
/// replaced entry can be put back.
@MainActor
@Observable
final class DiaryPolisher {
    enum Phase: Equatable {
        case idle
        case working
        case done(String)
        case failed(String)
    }

    private struct Replacement {
        let day: DayKey
        let original: String
        let polished: String
    }

    private nonisolated static let keychainDeniedMessage =
        "没能读取钥匙串里的密钥，可能是在系统弹窗里点了拒绝。再润色一次，弹窗出现时选「始终允许」。"

    let settings: AISettings
    private(set) var phase: Phase = .idle
    /// The day the panel is polishing; results only ever go back into this day.
    private(set) var targetDay: DayKey?
    var isShowingSettings = false
    var selectedStyleID = WritingStyle.builtIns[0].id

    private var lastReplacement: Replacement?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private let session: URLSession

    init(settings: AISettings, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
    }

    var isOpen: Bool { targetDay != nil }

    func open(for day: DayKey) {
        task?.cancel()
        targetDay = day
        phase = .idle
        isShowingSettings = !settings.isReady
    }

    func close() {
        task?.cancel()
        task = nil
        targetDay = nil
        isShowingSettings = false
        phase = .idle
    }

    func polish(_ text: String, style: WritingStyle) {
        task?.cancel()
        guard DiaryBook.characterCount(text) > 0 else {
            phase = .failed(PolishError.emptyDiary.userMessage)
            return
        }
        let endpoint = settings.endpoint
        let readKey = settings.keyReader()
        phase = .working
        task = Task { [session] in
            let outcome = await Self.run(endpoint: endpoint, readKey: readKey, text: text, style: style, session: session)
            guard !Task.isCancelled else { return }
            self.phase = outcome
        }
    }

    private nonisolated static func run(
        endpoint: AIEndpoint,
        readKey: @escaping @Sendable () throws -> String?,
        text: String,
        style: WritingStyle,
        session: URLSession
    ) async -> Phase {
        let key: String?
        do {
            key = try await Task.detached(operation: readKey).value
        } catch {
            NSLog("Yiyu: reading the AI key from the keychain failed: %@", String(describing: error))
            return .failed(keychainDeniedMessage)
        }
        do {
            let request = try PolishRequest.make(endpoint: endpoint, apiKey: key, text: text, style: style)
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            return .done(try PolishResponse.text(from: data, status: status))
        } catch let error as PolishError {
            return .failed(error.userMessage)
        } catch {
            let nsError = error as NSError
            NSLog("Yiyu: polishing failed: %@ %ld", nsError.domain, nsError.code)
            return .failed(PolishError.network(error.localizedDescription).userMessage)
        }
    }

    /// Puts the polished text into the day it was made for and keeps the original for undo.
    func accept(into model: AppModel) {
        guard case .done(let polished) = phase, let day = targetDay else { return }
        lastReplacement = Replacement(day: day, original: model.diaryText(for: day), polished: polished)
        model.writeDiary(polished, for: day)
        close()
    }

    /// Undo is offered only while the entry still holds exactly the polished text,
    /// so it can never throw away edits made afterwards.
    func canUndo(in model: AppModel, day: DayKey) -> Bool {
        guard let replacement = lastReplacement, replacement.day == day else { return false }
        return model.diaryText(for: day) == replacement.polished
    }

    func undo(in model: AppModel, day: DayKey) {
        guard canUndo(in: model, day: day), let replacement = lastReplacement else { return }
        model.writeDiary(replacement.original, for: day)
        lastReplacement = nil
    }
}
