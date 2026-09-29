import Foundation

/// How likely YES is compared to NO.
///
/// `yesShare` is the chance of YES among the yes/no outcomes. In three-way mode
/// MAYBE always keeps a fixed one-third share and the rest is split by `yesShare`,
/// so leaning toward YES never quietly removes MAYBE.
public struct Odds: Codable, Equatable, Hashable, Sendable {
    /// Allowed range for `yesShare`: from 10/90 to 90/10.
    public static let allowedRange: ClosedRange<Double> = 0.1...0.9
    public static let fair = Odds(yesShare: 0.5)
    public static let maybeShare = 1.0 / 3.0

    public let yesShare: Double

    public init(yesShare: Double) {
        let finite = yesShare.isFinite ? yesShare : 0.5
        let clamped = min(max(finite, Self.allowedRange.lowerBound), Self.allowedRange.upperBound)
        // Snap to whole percentages so the UI never shows 69.999%.
        self.yesShare = (clamped * 100).rounded() / 100
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(yesShare: try container.decode(Double.self, forKey: .yesShare))
    }

    public var isFair: Bool { self == .fair }

    /// Probability of each possible answer in `mode`. Always sums to 1.
    public func probabilities(for mode: AnswerMode) -> [Answer: Double] {
        switch mode {
        case .yesNo:
            return [.yes: yesShare, .no: 1 - yesShare]
        case .yesNoMaybe:
            let binary = 1 - Self.maybeShare
            return [
                .yes: binary * yesShare,
                .no: binary * (1 - yesShare),
                .maybe: Self.maybeShare,
            ]
        }
    }

    /// Whole-number percentages for display, adjusted so they add up to exactly 100.
    public func percentages(for mode: AnswerMode) -> [Answer: Int] {
        let probabilities = probabilities(for: mode)
        let answers = mode.possibleAnswers
        var result: [Answer: Int] = [:]
        for answer in answers {
            result[answer] = Int((probabilities[answer, default: 0] * 100).rounded())
        }
        // Rounding can leave 99 or 101. Give the difference to MAYBE when it's in play (its share
        // is fixed, so YES vs NO never looks tilted), otherwise to the largest share.
        let drift = 100 - result.values.reduce(0, +)
        if drift != 0 {
            let target = answers.contains(.maybe)
                ? Answer.maybe
                : answers.max(by: { result[$0, default: 0] < result[$1, default: 0] }) ?? .yes
            result[target, default: 0] += drift
        }
        return result
    }

    /// Short human-readable summary, e.g. "70% Yes · 30% No".
    public func summary(for mode: AnswerMode) -> String {
        let percentages = percentages(for: mode)
        return mode.possibleAnswers
            .map { "\(percentages[$0, default: 0])% \($0.spokenWord)" }
            .joined(separator: " · ")
    }
}
