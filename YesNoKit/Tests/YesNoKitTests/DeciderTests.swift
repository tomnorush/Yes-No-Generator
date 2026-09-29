import XCTest
@testable import YesNoKit

final class DeciderTests: XCTestCase {
    private func tally(mode: AnswerMode, odds: Odds, samples: Int = 60_000, seed: UInt64 = 42) -> [Answer: Double] {
        var generator = SplitMix64(seed: seed)
        var counts: [Answer: Int] = [:]
        for _ in 0..<samples {
            counts[Decider.decide(mode: mode, odds: odds, using: &generator), default: 0] += 1
        }
        return counts.mapValues { Double($0) / Double(samples) }
    }

    func testYesNoOnlyGivesYesOrNo() {
        var generator = SplitMix64(seed: 1)
        for _ in 0..<1_000 {
            let answer = Decider.decide(mode: .yesNo, using: &generator)
            XCTAssertNotEqual(answer, .maybe)
        }
    }

    func testFairYesNoIsRoughlyHalfAndHalf() {
        let shares = tally(mode: .yesNo, odds: .fair)
        XCTAssertEqual(shares[.yes] ?? 0, 0.5, accuracy: 0.01)
        XCTAssertEqual(shares[.no] ?? 0, 0.5, accuracy: 0.01)
    }

    func testThreeWayGivesEachAnswerAThird() {
        let shares = tally(mode: .yesNoMaybe, odds: .fair)
        for answer in Answer.allCases {
            XCTAssertEqual(shares[answer] ?? 0, 1.0 / 3.0, accuracy: 0.01, "\(answer)")
        }
    }

    func testLeaningOddsAreRespected() {
        let shares = tally(mode: .yesNo, odds: Odds(yesShare: 0.7))
        XCTAssertEqual(shares[.yes] ?? 0, 0.7, accuracy: 0.01)
        XCTAssertEqual(shares[.no] ?? 0, 0.3, accuracy: 0.01)
    }

    func testLeaningOddsKeepMaybeAtOneThird() {
        let shares = tally(mode: .yesNoMaybe, odds: Odds(yesShare: 0.9))
        XCTAssertEqual(shares[.maybe] ?? 0, 1.0 / 3.0, accuracy: 0.01)
        XCTAssertEqual(shares[.yes] ?? 0, 0.6, accuracy: 0.01)
        XCTAssertEqual(shares[.no] ?? 0, 2.0 / 30.0, accuracy: 0.01)
    }

    func testLeaningTowardNo() {
        let shares = tally(mode: .yesNo, odds: Odds(yesShare: 0.1))
        XCTAssertEqual(shares[.no] ?? 0, 0.9, accuracy: 0.01)
    }

    func testSystemGeneratorProducesBothAnswers() {
        let answers = Set((0..<200).map { _ in Decider.decide(mode: .yesNo) })
        XCTAssertEqual(answers, [.yes, .no])
    }
}

final class OddsTests: XCTestCase {
    func testClampsToAllowedRange() {
        XCTAssertEqual(Odds(yesShare: 0).yesShare, 0.1)
        XCTAssertEqual(Odds(yesShare: 1).yesShare, 0.9)
        XCTAssertEqual(Odds(yesShare: -5).yesShare, 0.1)
        XCTAssertEqual(Odds(yesShare: .nan).yesShare, 0.5)
        XCTAssertEqual(Odds(yesShare: .infinity).yesShare, 0.5)
    }

    func testSnapsToWholePercent() {
        XCTAssertEqual(Odds(yesShare: 0.69999).yesShare, 0.7)
        XCTAssertTrue(Odds(yesShare: 0.5000001).isFair)
    }

    func testProbabilitiesSumToOne() {
        for share in stride(from: 0.1, through: 0.9, by: 0.05) {
            for mode in AnswerMode.allCases {
                let total = Odds(yesShare: share).probabilities(for: mode).values.reduce(0, +)
                XCTAssertEqual(total, 1, accuracy: 1e-9)
            }
        }
    }

    func testPercentagesAlwaysAddUpTo100() {
        for share in stride(from: 0.1, through: 0.9, by: 0.01) {
            for mode in AnswerMode.allCases {
                let total = Odds(yesShare: share).percentages(for: mode).values.reduce(0, +)
                XCTAssertEqual(total, 100, "share \(share) mode \(mode)")
            }
        }
    }

    func testSummary() {
        XCTAssertEqual(Odds(yesShare: 0.7).summary(for: .yesNo), "70% Yes · 30% No")
        XCTAssertEqual(Odds.fair.summary(for: .yesNoMaybe), "33% Yes · 33% No · 34% Maybe")
    }

    func testDecodingClampsBadValues() throws {
        let data = Data(#"{"yesShare": 3}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(Odds.self, from: data).yesShare, 0.9)
    }
}
