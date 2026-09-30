import Foundation

/// A single answer the app can give.
public enum Answer: String, Codable, CaseIterable, Sendable {
    case yes
    case no
    case maybe

    /// The big word shown on screen and in shared text.
    public var word: String {
        switch self {
        case .yes: "YES"
        case .no: "NO"
        case .maybe: "MAYBE"
        }
    }

    /// Mixed-case form for VoiceOver and Siri, so "NO" is not spelled out letter by letter.
    public var spokenWord: String {
        switch self {
        case .yes: "Yes"
        case .no: "No"
        case .maybe: "Maybe"
        }
    }
}

/// Which answers are in play.
public enum AnswerMode: String, Codable, CaseIterable, Sendable {
    /// Classic two-way answer.
    case yesNo
    /// Three-way answer for questions that aren't really binary.
    case yesNoMaybe

    public var possibleAnswers: [Answer] {
        switch self {
        case .yesNo: [.yes, .no]
        case .yesNoMaybe: [.yes, .no, .maybe]
        }
    }
}
