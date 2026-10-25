import Foundation
import Observation
import YiyuCore

/// Runs one polish at a time for the diary page and remembers the original text so a
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

    let settings: AISettings
    private(set) var phase: Phase = .idle
    private(set) var isOpen = false
    var isShowingSettings = false
    var selectedStyleID = WritingStyle.builtIns[0].id

    private var lastReplacement: Replacement?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private let session: URLSession

    init(settings: AISettings, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
    }

    func open() {
        isOpen = true
        phase = .idle
        isShowingSettings = !settings.isReady
    }

    func close() {
        task?.cancel()
        task = nil
        isOpen = false
        isShowingSettings = false
        phase = .idle
    }

    func polish(_ text: String, style: WritingStyle) {
        task?.cancel()
        let request: URLRequest
        do {
            request = try PolishRequest.make(
                endpoint: settings.endpoint, apiKey: try settings.apiKey(), text: text, style: style
            )
        } catch let error as PolishError {
            phase = .failed(error.userMessage)
            return
        } catch {
            phase = .failed("读不到钥匙串里的密钥：\(error.localizedDescription)")
            return
        }

        phase = .working
        task = Task { [session] in
            let outcome: Phase
            do {
                let (data, response) = try await session.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                outcome = .done(try PolishResponse.text(from: data, status: status))
            } catch let error as PolishError {
                outcome = .failed(error.userMessage)
            } catch {
                guard !Task.isCancelled else { return }
                NSLog("Yiyu: polishing failed: %@", String(describing: error))
                outcome = .failed(PolishError.network(error.localizedDescription).userMessage)
            }
            guard !Task.isCancelled else { return }
            self.phase = outcome
        }
    }

    /// Puts the polished text into the diary and keeps the original for undo.
    func accept(into model: AppModel, day: DayKey) {
        guard case .done(let polished) = phase else { return }
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
