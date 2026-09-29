import Foundation
import Observation
import YesNoKit

/// Everything the phone app knows: the current answer, settings, history and Pro status.
@MainActor
@Observable
final class AppModel {
    /// One shared instance so the Siri / Shortcuts intent and the UI see the same state.
    static let shared = AppModel(storage: .live)

    // MARK: - Storage

    struct Storage {
        var defaults: UserDefaults
        var historyFile: HistoryFile?

        static var live: Storage {
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-ui-testing") {
                // UI tests start from a clean slate and never touch real data.
                let suite = "YesNo.UITests"
                let defaults = UserDefaults(suiteName: suite) ?? .standard
                defaults.removePersistentDomain(forName: suite)
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("ui-testing-history-\(UUID().uuidString).json")
                return Storage(defaults: defaults, historyFile: HistoryFile(url: url))
            }
            return Storage(defaults: .standard, historyFile: .standard())
        }
    }

    private enum Keys {
        static let preferences = "preferences.v1"
        static let usage = "usage.v1"
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let historyFile: HistoryFile?
    @ObservationIgnored private let diskQueue = DispatchQueue(label: "YesNo.history", qos: .utility)
    @ObservationIgnored private var backgroundedAt: Date?
    /// The first answer is picked before the screen exists so it is on the very first frame;
    /// it is counted and saved once the screen actually shows it.
    @ObservationIgnored private var launchAnswerPending = true

    let store: ProStore

    // MARK: - State

    private var preferences: Preferences
    private(set) var usage: Usage
    private(set) var history: History

    private(set) var answer: Answer
    /// Changes on every new answer, even when the answer word repeats, to drive feedback.
    private(set) var answerCount = 0
    private var questionText = ""

    /// The optional question typed above the answer, capped at `Question.maxLength` characters.
    var question: String {
        get { questionText }
        set { questionText = String(newValue.prefix(Question.maxLength)) }
    }

    init(storage: Storage) {
        let store = ProStore(defaults: storage.defaults)
        let preferences = Preferences.load(from: storage.defaults, key: Keys.preferences)
        defaults = storage.defaults
        historyFile = storage.historyFile
        self.store = store
        self.preferences = preferences
        usage = Usage.load(from: storage.defaults, key: Keys.usage)
        history = storage.historyFile?.load() ?? History()
        answer = Decider.decide(mode: preferences.mode, odds: store.isPro ? preferences.odds : .fair)
    }

    // MARK: - Settings

    var mode: AnswerMode {
        get { preferences.mode }
        set {
            guard newValue != preferences.mode else { return }
            preferences.mode = newValue
            savePreferences()
            // Switching between two-way and three-way deserves a fresh answer in the new mode.
            ask()
        }
    }

    var appearance: Appearance {
        get { preferences.appearance }
        set { preferences.appearance = newValue; savePreferences() }
    }

    var hapticsEnabled: Bool {
        get { preferences.hapticsEnabled }
        set { preferences.hapticsEnabled = newValue; savePreferences() }
    }

    var historyEnabled: Bool {
        get { preferences.historyEnabled }
        set { preferences.historyEnabled = newValue; savePreferences() }
    }

    /// The odds the user picked. They only apply while Pro is unlocked; see `effectiveOdds`.
    var chosenOdds: Odds {
        get { preferences.odds }
        set { preferences.odds = newValue; savePreferences() }
    }

    var chosenThemeID: String {
        get { preferences.themeID }
        set { preferences.themeID = newValue; savePreferences() }
    }

    // MARK: - Derived

    var isPro: Bool { store.isPro }

    var effectiveOdds: Odds { isPro ? preferences.odds : .fair }

    var theme: Theme {
        let chosen = Theme.with(id: preferences.themeID)
        return chosen.isPro && !isPro ? .classic : chosen
    }

    /// Pro is only ever mentioned in Settings, and only after the app has already helped.
    var mayMentionPro: Bool { !isPro && ValueGate.mayMentionPro(usage: usage) }

    /// Pro-only settings (themes, odds) stay hidden until Pro may be mentioned or is owned.
    var showsProSettings: Bool { isPro || mayMentionPro }

    var historyLimit: Int? { isPro ? nil : History.freeLimit }

    var shareText: String {
        ShareText.make(answer: answer, question: question, mode: mode, odds: effectiveOdds)
    }

    var showsTapHint: Bool { !usage.hasRerolled }

    // MARK: - Asking

    /// Picks a new answer for the current question.
    func ask() {
        answer = Decider.decide(mode: mode, odds: effectiveOdds)
        answerCount += 1
        launchAnswerPending = false
        recordShownAnswer()
    }

    /// A tap on the answer area.
    func reroll() {
        if !usage.hasRerolled {
            usage.hasRerolled = true
        }
        ask()
    }

    /// Called when the answer screen first appears.
    func answerScreenAppeared() {
        guard launchAnswerPending else { return }
        launchAnswerPending = false
        recordShownAnswer()
    }

    /// Siri / Shortcuts / Action button. Updates the screen too, so the app agrees with Siri.
    func askFromShortcut(question: String?) -> Answer {
        self.question = Question.normalized(question) ?? ""
        ask()
        return answer
    }

    func didEnterBackground() {
        backgroundedAt = Date()
    }

    func didBecomeActive() {
        defer { backgroundedAt = nil }
        if SessionFreshness.needsFreshAnswer(backgroundedAt: backgroundedAt) {
            question = ""
            ask()
        }
    }

    private func recordShownAnswer() {
        usage.answersShown += 1
        usage.save(to: defaults, key: Keys.usage)
        guard historyEnabled else { return }
        history.record(
            HistoryEntry(answer: answer, mode: mode, question: question, odds: effectiveOdds),
            limit: historyLimit
        )
        saveHistory()
    }

    // MARK: - History

    func deleteHistory(ids: Set<UUID>) {
        history.delete(ids: ids)
        saveHistory()
    }

    func clearHistory() {
        history.deleteAll()
        saveHistory()
    }

    private func saveHistory() {
        guard let historyFile, let data = try? HistoryFile.encode(history) else { return }
        // A serial queue keeps writes in order; the atomic write means a crash never leaves half a file.
        diskQueue.async {
            try? historyFile.save(encoded: data)
        }
    }

    private func savePreferences() {
        preferences.save(to: defaults, key: Keys.preferences)
    }
}
