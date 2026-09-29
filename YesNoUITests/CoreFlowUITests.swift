import XCTest

/// Checks the promises that matter most: an answer on screen at launch with zero taps,
/// a new one with one tap, and no mention of Pro before the app has helped.
final class CoreFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
    }

    private var answerButton: XCUIElement { app.buttons["answer"] }

    /// Any element whose accessibility label contains `text`, ignoring case
    /// (section headers may be drawn in capitals, and history rows combine their texts).
    private func element(containing text: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", text))
            .firstMatch
    }

    private func scrollSettingsToBottom() {
        for _ in 0..<3 {
            app.swipeUp()
        }
    }

    func testAnswerIsVisibleAtLaunchWithoutAnyTap() {
        XCTAssertTrue(answerButton.waitForExistence(timeout: 2))
        XCTAssertTrue(["Yes", "No"].contains(answerButton.label), "Unexpected answer: \(answerButton.label)")
    }

    func testOneTapGivesANewAnswerAndItLandsInHistory() {
        XCTAssertTrue(answerButton.waitForExistence(timeout: 2))
        answerButton.tap()

        app.buttons["history"].tap()
        let list = app.collectionViews["history.list"]
        XCTAssertTrue(list.waitForExistence(timeout: 2))
        // The launch answer plus the tapped one.
        XCTAssertEqual(list.cells.count, 2)
    }

    func testQuestionIsKeptWithTheAnswer() {
        let field = app.textFields["question"]
        XCTAssertTrue(field.waitForExistence(timeout: 2))
        field.tap()
        field.typeText("Pizza tonight?\n")

        app.buttons["history"].tap()
        XCTAssertTrue(element(containing: "Pizza tonight?").waitForExistence(timeout: 2))
    }

    func testMaybeModeIsOneTapAway() {
        XCTAssertTrue(app.buttons["mode.yesNoMaybe"].waitForExistence(timeout: 2))
        app.buttons["mode.yesNoMaybe"].tap()
        XCTAssertTrue(["Yes", "No", "Maybe"].contains(answerButton.label))
    }

    func testProIsNotMentionedBeforeTheAppHasHelped() {
        app.buttons["settings"].tap()
        XCTAssertTrue(element(containing: "Appearance").waitForExistence(timeout: 2))
        XCTAssertFalse(element(containing: "Color Theme").exists)
        XCTAssertFalse(element(containing: "Chance of Yes").exists)

        scrollSettingsToBottom()
        XCTAssertTrue(app.buttons["purchases.restore"].exists, "Restore Purchases must always be reachable")
        XCTAssertFalse(element(containing: "Yes or No Pro").exists)
        XCTAssertFalse(element(containing: "Unlock Pro").exists)
    }

    func testProIsMentionedOnlyAfterTheAppHasHelped() {
        XCTAssertTrue(answerButton.waitForExistence(timeout: 2))
        answerButton.tap()
        answerButton.tap()

        app.buttons["settings"].tap()
        XCTAssertTrue(element(containing: "Color Theme").waitForExistence(timeout: 2))
        scrollSettingsToBottom()
        XCTAssertTrue(element(containing: "Yes or No Pro").waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["purchases.restore"].exists)
    }
}
