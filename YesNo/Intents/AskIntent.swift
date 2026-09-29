import AppIntents
import YesNoKit

/// "Hey Siri, ask Yes or No", a Shortcut, or the Action button: an answer with zero taps.
/// Uses the same mode and odds as the app, and lands in history like any other answer.
struct AskYesOrNoIntent: AppIntent {
    static var title: LocalizedStringResource = "Get a Yes or No"
    static var description = IntentDescription(
        "Gives an instant answer using the answer type and odds set in the app."
    )

    @Parameter(title: "Question")
    var question: String?

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let answer = AppModel.shared.askFromShortcut(question: question)
        return .result(value: answer.word, dialog: IntentDialog(stringLiteral: answer.spokenWord))
    }
}

struct YesNoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskYesOrNoIntent(),
            phrases: [
                "Ask \(.applicationName)",
                "Get an answer from \(.applicationName)",
                "\(.applicationName), decide for me",
            ],
            shortTitle: "Yes or No",
            systemImageName: "questionmark.circle"
        )
    }
}
