import XCTest
@testable import YesNoKit

final class HistoryTests: XCTestCase {
    private func entry(_ answer: Answer = .yes, at seconds: TimeInterval = 0, question: String? = nil) -> HistoryEntry {
        HistoryEntry(date: Date(timeIntervalSince1970: seconds), answer: answer, mode: .yesNo, question: question, odds: nil)
    }

    func testRecordPutsNewestFirst() {
        var history = History()
        history.record(entry(.yes, at: 1), limit: nil)
        history.record(entry(.no, at: 2), limit: nil)
        XCTAssertEqual(history.entries.map(\.answer), [.no, .yes])
    }

    func testFreeLimitDropsOldest() {
        var history = History()
        for index in 0..<(History.freeLimit + 10) {
            history.record(entry(at: TimeInterval(index)), limit: History.freeLimit)
        }
        XCTAssertEqual(history.entries.count, History.freeLimit)
        XCTAssertEqual(history.entries.first?.date, Date(timeIntervalSince1970: TimeInterval(History.freeLimit + 9)))
        XCTAssertEqual(history.entries.last?.date, Date(timeIntervalSince1970: 10))
    }

    func testUnlimitedKeepsEverything() {
        var history = History()
        for index in 0..<500 {
            history.record(entry(at: TimeInterval(index)), limit: nil)
        }
        XCTAssertEqual(history.entries.count, 500)
    }

    func testDeleteAndDeleteAll() {
        var history = History()
        let first = entry(at: 1)
        let second = entry(at: 2)
        history.record(first, limit: nil)
        history.record(second, limit: nil)
        history.delete(ids: [first.id])
        XCTAssertEqual(history.entries, [second])
        history.deleteAll()
        XCTAssertTrue(history.isEmpty)
    }

    func testEntryDropsFairOddsButKeepsTiltedOdds() {
        XCTAssertNil(HistoryEntry(answer: .yes, mode: .yesNo, question: nil, odds: .fair).odds)
        XCTAssertEqual(HistoryEntry(answer: .yes, mode: .yesNo, question: nil, odds: Odds(yesShare: 0.8)).odds?.yesShare, 0.8)
    }

    func testEntryNormalizesQuestion() {
        XCTAssertNil(HistoryEntry(answer: .yes, mode: .yesNo, question: "   \n ", odds: nil).question)
        XCTAssertEqual(HistoryEntry(answer: .yes, mode: .yesNo, question: "  Pizza?\n", odds: nil).question, "Pizza?")
    }

    func testGroupedByDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var history = History()
        history.record(entry(at: 60), limit: nil)            // 1 Jan 1970 00:01
        history.record(entry(at: 3_600), limit: nil)         // 1 Jan 1970 01:00
        history.record(entry(at: 90_000), limit: nil)        // 2 Jan 1970 01:00
        let groups = history.groupedByDay(calendar: calendar)
        XCTAssertEqual(groups.map(\.entries.count), [1, 2])
        XCTAssertEqual(groups.first?.day, Date(timeIntervalSince1970: 86_400))
    }

    func testFileRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = HistoryFile(url: directory.appendingPathComponent("nested/history.json"))

        var history = History()
        history.record(entry(.no, at: 100, question: "Go out tonight?"), limit: nil)
        history.record(HistoryEntry(date: Date(timeIntervalSince1970: 200), answer: .maybe, mode: .yesNoMaybe,
                                    question: nil, odds: Odds(yesShare: 0.3)), limit: nil)
        try file.save(history)

        XCTAssertEqual(file.load(), history)
        try file.delete()
        XCTAssertTrue(file.load().isEmpty)
    }

    func testCorruptFileLoadsAsEmpty() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not json".utf8).write(to: url)
        XCTAssertTrue(HistoryFile(url: url).load().isEmpty)
    }
}

final class QuestionAndShareTests: XCTestCase {
    func testQuestionIsCapped() {
        let long = String(repeating: "a", count: 500)
        XCTAssertEqual(Question.normalized(long)?.count, Question.maxLength)
    }

    func testMultilineQuestionBecomesOneLine() {
        XCTAssertEqual(Question.normalized("Should I\ngo?"), "Should I go?")
    }

    func testShareTextWithoutQuestion() {
        XCTAssertEqual(ShareText.make(answer: .yes, question: nil), "Yes or No says: YES")
        XCTAssertEqual(ShareText.make(answer: .no, question: "  "), "Yes or No says: NO")
    }

    func testShareTextWithQuestion() {
        XCTAssertEqual(
            ShareText.make(answer: .maybe, question: "Pizza tonight?", mode: .yesNoMaybe),
            "\u{201C}Pizza tonight?\u{201D}\nYes or No says: MAYBE"
        )
    }

    func testShareTextDisclosesTiltedOdds() {
        XCTAssertEqual(
            ShareText.make(answer: .yes, question: nil, mode: .yesNo, odds: Odds(yesShare: 0.7)),
            "Yes or No says: YES (odds: 70% Yes · 30% No)"
        )
    }
}
