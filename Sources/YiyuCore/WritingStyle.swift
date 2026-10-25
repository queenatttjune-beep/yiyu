import Foundation

/// A way of rewriting a diary entry: the three built-in styles or one the user wrote.
public struct WritingStyle: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    /// What the AI is told about the style, in plain Chinese.
    public var instruction: String

    public init(id: String, name: String, instruction: String) {
        self.id = id
        self.name = name
        self.instruction = instruction
    }

    public static func custom(name: String, instruction: String, id: String = UUID().uuidString) -> WritingStyle {
        WritingStyle(id: id, name: name, instruction: instruction)
    }

    public static let builtIns = [
        WritingStyle(
            id: "builtin.plain",
            name: "白描",
            instruction: "白描：用朴素、准确、干净的语言如实写出看到的和做过的，少用形容词和修辞，不直接抒情，让细节自己说话。"
        ),
        WritingStyle(
            id: "builtin.poetic",
            name: "诗意",
            instruction: "诗意：语言舒缓，有画面感和节奏，可以适度用比喻和意象，含蓄地带出心情；写成散文段落，不要写成分行的诗。"
        ),
        WritingStyle(
            id: "builtin.ornate",
            name: "华丽",
            instruction: "华丽：辞藻丰富典雅，句式讲究，可以化用成语和古典意象，适当对仗铺陈，文采斐然，但读起来仍然通顺。"
        ),
    ]

    public var isBuiltIn: Bool {
        Self.builtIns.contains { $0.id == id }
    }

    public static func all(custom: [WritingStyle]) -> [WritingStyle] {
        builtIns + custom
    }
}

/// Pure operations on the user's own styles. Every function returns a new array.
public enum StyleBook {
    public static func adding(
        name: String,
        instruction: String,
        to styles: [WritingStyle],
        id: String = UUID().uuidString
    ) -> [WritingStyle] {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedInstruction = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        let takenNames = Set(WritingStyle.all(custom: styles).map(\.name))
        guard !trimmedName.isEmpty, !trimmedInstruction.isEmpty, !takenNames.contains(trimmedName) else {
            return styles
        }
        return styles + [WritingStyle.custom(name: trimmedName, instruction: trimmedInstruction, id: id)]
    }

    public static func removing(_ id: String, from styles: [WritingStyle]) -> [WritingStyle] {
        styles.filter { $0.id != id }
    }
}
