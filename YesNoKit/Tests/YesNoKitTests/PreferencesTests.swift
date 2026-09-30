import XCTest
@testable import YesNoKit

final class PreferencesTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "YesNoKitTests.\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testDefaultsAreFreeAndFair() {
        let preferences = Preferences.load(from: defaults, key: "prefs")
        XCTAssertEqual(preferences.mode, .yesNo)
        XCTAssertEqual(preferences.appearance, .system)
        XCTAssertEqual(preferences.themeID, "classic")
        XCTAssertTrue(preferences.hapticsEnabled)
        XCTAssertTrue(preferences.historyEnabled)
        XCTAssertTrue(preferences.odds.isFair)
    }

    func testRoundTrip() {
        var preferences = Preferences()
        preferences.mode = .yesNoMaybe
        preferences.appearance = .dark
        preferences.themeID = "ocean"
        preferences.hapticsEnabled = false
        preferences.historyEnabled = false
        preferences.odds = Odds(yesShare: 0.8)
        preferences.save(to: defaults, key: "prefs")
        XCTAssertEqual(Preferences.load(from: defaults, key: "prefs"), preferences)
    }

    func testMissingAndUnknownKeysDoNotResetOtherSettings() throws {
        let json = #"{"mode":"yesNoMaybe","appearance":"sepia","futureSetting":42}"#
        let preferences = try JSONDecoder().decode(Preferences.self, from: Data(json.utf8))
        XCTAssertEqual(preferences.mode, .yesNoMaybe)
        XCTAssertEqual(preferences.appearance, .system) // unknown value falls back
        XCTAssertTrue(preferences.hapticsEnabled)       // missing key falls back
    }

    func testUsageRoundTrip() {
        let usage = Usage(answersShown: 12, hasRerolled: true)
        usage.save(to: defaults, key: "usage")
        XCTAssertEqual(Usage.load(from: defaults, key: "usage"), usage)
    }
}

final class ValueGateTests: XCTestCase {
    func testNoMentionOfProBeforeTheAppHasHelped() {
        XCTAssertFalse(ValueGate.mayMentionPro(usage: Usage(answersShown: 0)))
        XCTAssertFalse(ValueGate.mayMentionPro(usage: Usage(answersShown: 1)))
        XCTAssertFalse(ValueGate.mayMentionPro(usage: Usage(answersShown: ValueGate.answersBeforeMentioningPro - 1)))
        XCTAssertTrue(ValueGate.mayMentionPro(usage: Usage(answersShown: ValueGate.answersBeforeMentioningPro)))
    }
}

final class SessionFreshnessTests: XCTestCase {
    func testQuickSwitchKeepsTheAnswer() {
        let now = Date()
        XCTAssertFalse(SessionFreshness.needsFreshAnswer(backgroundedAt: nil, now: now))
        XCTAssertFalse(SessionFreshness.needsFreshAnswer(backgroundedAt: now.addingTimeInterval(-30), now: now))
    }

    func testLongAbsenceGetsAFreshAnswer() {
        let now = Date()
        let away = now.addingTimeInterval(-SessionFreshness.staleAfter)
        XCTAssertTrue(SessionFreshness.needsFreshAnswer(backgroundedAt: away, now: now))
    }
}

final class MarkdownDocumentTests: XCTestCase {
    func testParsesHeadingsParagraphsAndBullets() {
        let source = """
        # Title

        First line
        continues here.

        ## Section
        - One **bold**
        - Two
        #NotAHeading
        """
        XCTAssertEqual(MarkdownDocument(source).blocks, [
            .heading(level: 1, text: "Title"),
            .paragraph("First line continues here."),
            .heading(level: 2, text: "Section"),
            .bullet("One **bold**"),
            .bullet("Two"),
            .paragraph("#NotAHeading"),
        ])
    }

    func testBundledPrivacyPolicyParses() throws {
        // The same file ships inside the app; make sure it stays readable by the parser.
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // YesNoKitTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // YesNoKit
            .deletingLastPathComponent() // repository root
            .appendingPathComponent("docs/privacy.md")
        let document = MarkdownDocument(try String(contentsOf: url, encoding: .utf8))
        XCTAssertEqual(document.blocks.first, .heading(level: 1, text: "Privacy Policy"))
        XCTAssertTrue(document.blocks.contains(.heading(level: 2, text: "Summary")))
    }
}
