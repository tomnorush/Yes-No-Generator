import Foundation

/// Light / dark / follow the system.
public enum Appearance: String, Codable, CaseIterable, Sendable {
    case system
    case light
    case dark
}

/// Every user setting, stored as one JSON blob in UserDefaults.
///
/// Decoding tolerates missing or unknown keys so adding a setting in a later
/// version never resets the rest.
public struct Preferences: Codable, Equatable, Sendable {
    public var mode: AnswerMode = .yesNo
    public var appearance: Appearance = .system
    public var themeID: String = "classic"
    public var hapticsEnabled: Bool = true
    public var historyEnabled: Bool = true
    /// The chosen odds. Only applied while Pro is unlocked.
    public var odds: Odds = .fair

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Preferences()
        mode = (try? container.decode(AnswerMode.self, forKey: .mode)) ?? defaults.mode
        appearance = (try? container.decode(Appearance.self, forKey: .appearance)) ?? defaults.appearance
        themeID = (try? container.decode(String.self, forKey: .themeID)) ?? defaults.themeID
        hapticsEnabled = (try? container.decode(Bool.self, forKey: .hapticsEnabled)) ?? defaults.hapticsEnabled
        historyEnabled = (try? container.decode(Bool.self, forKey: .historyEnabled)) ?? defaults.historyEnabled
        odds = (try? container.decode(Odds.self, forKey: .odds)) ?? defaults.odds
    }

    public static func load(from defaults: UserDefaults, key: String) -> Preferences {
        guard let data = defaults.data(forKey: key),
              let preferences = try? JSONDecoder().decode(Preferences.self, from: data)
        else { return Preferences() }
        return preferences
    }

    public func save(to defaults: UserDefaults, key: String) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: key)
        }
    }
}

/// Local counters used only to decide when it's fair to mention Pro. Never leaves the device.
public struct Usage: Codable, Equatable, Sendable {
    public var answersShown: Int = 0
    /// Whether the user has ever tapped for a new answer; hides the "tap anywhere" hint afterwards.
    public var hasRerolled: Bool = false

    public init(answersShown: Int = 0, hasRerolled: Bool = false) {
        self.answersShown = answersShown
        self.hasRerolled = hasRerolled
    }

    public static func load(from defaults: UserDefaults, key: String) -> Usage {
        guard let data = defaults.data(forKey: key),
              let usage = try? JSONDecoder().decode(Usage.self, from: data)
        else { return Usage() }
        return usage
    }

    public func save(to defaults: UserDefaults, key: String) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: key)
        }
    }
}

/// "No upsell before the user has gotten value once."
///
/// Pro is never shown as a pop-up, banner or badge. It only appears inside Settings,
/// and only after the app has already answered a few questions for free.
public enum ValueGate {
    public static let answersBeforeMentioningPro = 3

    public static func mayMentionPro(usage: Usage) -> Bool {
        usage.answersShown >= answersBeforeMentioningPro
    }
}

/// Decides when returning to the app should show a fresh answer instead of the old one,
/// so an answer from hours ago is never mistaken for a new one.
public enum SessionFreshness {
    public static let staleAfter: TimeInterval = 5 * 60

    public static func needsFreshAnswer(backgroundedAt: Date?, now: Date = Date()) -> Bool {
        guard let backgroundedAt else { return false }
        return now.timeIntervalSince(backgroundedAt) >= staleAfter
    }
}
