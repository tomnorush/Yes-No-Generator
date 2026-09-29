import Foundation

/// Picks answers. Uses the system's cryptographically secure generator by default,
/// so answers can't be predicted or nudged; tests inject a seeded generator.
public enum Decider {
    public static func decide(mode: AnswerMode, odds: Odds = .fair) -> Answer {
        var generator = SystemRandomNumberGenerator()
        return decide(mode: mode, odds: odds, using: &generator)
    }

    public static func decide<G: RandomNumberGenerator>(
        mode: AnswerMode,
        odds: Odds = .fair,
        using generator: inout G
    ) -> Answer {
        let probabilities = odds.probabilities(for: mode)
        let roll = Double.random(in: 0..<1, using: &generator)
        var cumulative = 0.0
        for answer in mode.possibleAnswers {
            cumulative += probabilities[answer, default: 0]
            if roll < cumulative {
                return answer
            }
        }
        // Only reachable through floating-point rounding at the very top of the range.
        return mode.possibleAnswers.last ?? .yes
    }
}
