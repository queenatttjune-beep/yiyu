import Foundation

public struct ParsedTodo: Equatable, Sendable {
    public let title: String
    public let plannedDay: DayKey?
    /// A date phrase was found but could not be resolved, e.g. November 31.
    public let unresolvedDate: String?
}

/// Local parsing for calendar dates and common spoken task phrasing. Never creates notifications.
public struct TodoInputParser: Sendable {
    public let calendar: Calendar

    public init(calendar: Calendar) { self.calendar = calendar }

    public func parse(_ input: String, now: Date) -> ParsedTodo {
        // Book/song titles and quoted text are content, not scheduling instructions.
        var quotes: [String] = []
        var text = ChineseNumber.normalizingDigits(input).replacing(#/《[^》]*》|「[^」]*」|“[^”]*”|"[^"]*"/#) { match in
            quotes.append(String(match.0))
            return "\u{E000}\(quotes.count - 1)\u{E001}"
        }
        var plannedDay: DayKey?
        var unresolvedDate: String?
        let dates = #/下个?月\s*(?:\d{1,2}|[零一二两三四五六七八九十]{1,3})\s*[日号]|\d{1,2}\s*月\s*\d{1,2}\s*[日号]|(?:下个?|这个?|本)?(?:周|星期|礼拜)[一二三四五六日天1-7]|(?:\d{1,3}|[零一二两三四五六七八九十]{1,3})\s*天\s*(?:以后|之后|后)|大后天|后天|明天|明日|明早|明晚|今天|今日|今早|今晚|今夜|\d{1,2}\s*[日号](?![楼线房门院床机馆厅座栋层室])/#
        for match in text.matches(of: dates) {
            let before = String(text[..<match.range.lowerBound])
            let after = String(text[match.range.upperBound...])
            // Do not turn unsupported recurring or previous-week instructions into a one-off task.
            if ["每", "每个", "上", "下"].contains(where: { before.hasSuffix($0) }) { continue }
            if ["科技", "公司", "集团", "出版社"].contains(where: { after.hasPrefix($0) }) { continue }
            let phrase = String(match.0)
            // Resolve calendar days at midnight: "周日" on Sunday stays today even after 09:00.
            let parsed = QuickTimeParser(calendar: calendar).parse(phrase, now: calendar.startOfDay(for: now))
            guard let date = parsed.fireAt else {
                unresolvedDate = phrase
                break
            }
            plannedDay = DayKey(date, calendar: calendar)
            var rest = after.trimmingCharacters(in: .whitespaces)
            if rest.hasPrefix("的") { rest.removeFirst() }
            text = before + rest
            break // Later dates can describe the task itself: 明天准备后天的会议.
        }
        var title = Self.taskTitle(text)
        for (index, quote) in quotes.enumerated() {
            title = title.replacingOccurrences(of: "\u{E000}\(index)\u{E001}", with: quote)
        }
        return ParsedTodo(title: title, plannedDay: plannedDay, unresolvedDate: unresolvedDate)
    }

    private static let edges = CharacterSet.whitespacesAndNewlines
        .union(CharacterSet(charactersIn: ",，。:：;；!！"))

    private static func taskTitle(_ input: String) -> String {
        var title = input.trimmingCharacters(in: edges)
        let prefixes = ["麻烦帮我", "请帮我", "帮我", "记得", "我要", "我想要", "我想"]
        while let prefix = prefixes.first(where: { title.hasPrefix($0) }) {
            title = String(title.dropFirst(prefix.count)).trimmingCharacters(in: edges)
        }
        let requests = ["把", "将", "写", "交", "买", "还", "发", "做", "看", "读", "去", "整理", "提交", "打印", "不要"]
        for prefix in ["请", "麻烦"] where title.hasPrefix(prefix) {
            let rest = String(title.dropFirst(prefix.count)).trimmingCharacters(in: edges)
            if requests.contains(where: { rest.hasPrefix($0) }) { title = rest }
        }
        // Only reorder a complete, known 把/将 construction; keep qualifiers and negation otherwise.
        if let action = title.wholeMatch(of: #/(?:把|将)\s*(.+?)\s*(提交|整理|检查|修改|打印|完成|发送|写|交|买|还|发|做|看|读)(?:好|完|掉|了|一下|一遍|吧)*/#),
           !["再", "然后", "并", "之后", "以后", "不", "没", "别"].contains(where: { action.1.contains($0) }) {
            title = String(action.2) + action.1.trimmingCharacters(in: .whitespaces)
        }
        return title.trimmingCharacters(in: edges)
    }
}
