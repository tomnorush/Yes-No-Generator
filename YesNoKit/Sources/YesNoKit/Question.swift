import Foundation

/// Rules for the optional question the user can type before asking.
public enum Question {
    public static let maxLength = 140

    /// Trims whitespace, collapses line breaks, caps the length, and turns blank input into `nil`.
    public static func normalized(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let singleLine = raw
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !singleLine.isEmpty else { return nil }
        return String(singleLine.prefix(maxLength))
    }
}

/// Builds the text used by Copy and Share.
public enum ShareText {
    /// When the odds were tilted, the shared text says so; a group deciding together should know.
    public static func make(
        answer: Answer,
        question: String?,
        mode: AnswerMode = .yesNo,
        odds: Odds = .fair
    ) -> String {
        var verdict = "Yes or No says: \(answer.word)"
        if !odds.isFair {
            verdict += " (odds: \(odds.summary(for: mode)))"
        }
        guard let question = Question.normalized(question) else { return verdict }
        return "\u{201C}\(question)\u{201D}\n\(verdict)"
    }
}
