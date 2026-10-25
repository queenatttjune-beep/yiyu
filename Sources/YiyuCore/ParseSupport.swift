import Foundation

enum ChineseNumber {
    private static let digits: [Character: Int] = [
        "零": 0, "一": 1, "二": 2, "两": 2, "三": 3, "四": 4,
        "五": 5, "六": 6, "七": 7, "八": 8, "九": 9,
    ]

    /// Parses "12", "十", "十二", "二十", "二十三", "两" or "零五". Returns nil for anything else.
    static func value<S: StringProtocol>(_ token: S) -> Int? {
        if let number = Int(token) { return number }
        if token.count == 2, token.first == "零" {
            return singleDigit(token.dropFirst())
        }
        guard let tenIndex = token.firstIndex(of: "十") else {
            guard token.count == 1, let character = token.first else { return nil }
            return digits[character]
        }
        let left = token[..<tenIndex]
        let right = token[token.index(after: tenIndex)...]
        let tens = left.isEmpty ? 1 : singleDigit(left)
        let ones = right.isEmpty ? 0 : singleDigit(right)
        guard let tens, let ones else { return nil }
        return tens * 10 + ones
    }

    static func weekday<S: StringProtocol>(_ token: S) -> Int? {
        switch token {
        case "日", "天", "7": return 7
        default:
            guard let number = value(token), (1...6).contains(number) else { return nil }
            return number
        }
    }

    /// Turns full-width digits (０-９) into ASCII so the patterns below can read them.
    static func normalizingDigits(_ text: String) -> String {
        String(text.map { character -> Character in
            guard let scalar = character.unicodeScalars.first,
                  character.unicodeScalars.count == 1,
                  (0xFF10...0xFF19).contains(scalar.value),
                  let ascii = Unicode.Scalar(scalar.value - 0xFF10 + 0x30)
            else { return character }
            return Character(ascii)
        })
    }

    private static func singleDigit<S: StringProtocol>(_ token: S) -> Int? {
        guard token.count == 1, let character = token.first else { return nil }
        return digits[character]
    }
}

/// Mutable working copy of the input; each `take` removes what it recognised.
struct ParseScan {
    private(set) var text: String

    private static let edgeCharacters = CharacterSet.whitespacesAndNewlines
        .union(CharacterSet(charactersIn: ",，。.、:：;；!！~～-—"))
    private static let fillerPrefixes = ["提醒我", "提醒一下", "提醒", "叫我", "记得"]
    static let fallbackTitle = "提醒"

    init(text: String) {
        self.text = text
    }

    /// Removes the first match `extract` accepts. Matches right after a character in
    /// `notPrecededBy` are skipped, e.g. the "20分" of "3点20分".
    mutating func take<Output, Value>(
        _ regex: Regex<Output>,
        notPrecededBy excluded: Set<Character> = [],
        _ extract: (Output) -> Value?
    ) -> Value? {
        for match in text.matches(of: regex) {
            if match.range.lowerBound > text.startIndex,
               excluded.contains(text[text.index(before: match.range.lowerBound)]) {
                continue
            }
            guard let value = extract(match.output) else { continue }
            text.replaceSubrange(match.range, with: " ")
            return value
        }
        return nil
    }

    mutating func takeWord<Value>(from table: [(String, Value)]) -> Value? {
        for (word, value) in table {
            guard let range = text.range(of: word) else { continue }
            text.replaceSubrange(range, with: " ")
            return value
        }
        return nil
    }

    var title: String {
        var result = trimmed(text.split(whereSeparator: \.isWhitespace).joined(separator: " "))
        if let filler = Self.fillerPrefixes.first(where: { result.hasPrefix($0) }) {
            result = trimmed(String(result.dropFirst(filler.count)))
        }
        if result.hasPrefix("的") {
            result = trimmed(String(result.dropFirst()))
        }
        return result.isEmpty ? Self.fallbackTitle : result
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: Self.edgeCharacters)
    }
}
