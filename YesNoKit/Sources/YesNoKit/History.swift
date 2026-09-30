import Foundation

/// One answer the user was shown.
public struct HistoryEntry: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let date: Date
    public let answer: Answer
    public let mode: AnswerMode
    /// The question typed before asking, if any.
    public let question: String?
    /// Set only when the odds were not 50/50, so the history stays honest about it.
    public let odds: Odds?

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        answer: Answer,
        mode: AnswerMode,
        question: String?,
        odds: Odds?
    ) {
        self.id = id
        self.date = date
        self.answer = answer
        self.mode = mode
        self.question = Question.normalized(question)
        self.odds = (odds?.isFair ?? true) ? nil : odds
    }
}

/// The saved list of answers, newest first.
public struct History: Codable, Equatable, Sendable {
    /// How many answers are kept without Pro.
    public static let freeLimit = 50

    public private(set) var entries: [HistoryEntry]

    /// `entries` must already be newest first; the stored order is the source of truth.
    public init(entries: [HistoryEntry] = []) {
        self.entries = entries
    }

    public var isEmpty: Bool { entries.isEmpty }

    /// Adds `entry` at the top. `limit` of `nil` keeps everything.
    public mutating func record(_ entry: HistoryEntry, limit: Int?) {
        entries.insert(entry, at: 0)
        trim(to: limit)
    }

    public mutating func trim(to limit: Int?) {
        guard let limit, entries.count > limit else { return }
        entries.removeLast(entries.count - max(limit, 0))
    }

    public mutating func delete(ids: Set<UUID>) {
        entries.removeAll { ids.contains($0.id) }
    }

    public mutating func deleteAll() {
        entries.removeAll()
    }

    /// Entries grouped by calendar day, newest day first.
    public func groupedByDay(calendar: Calendar = .current) -> [HistoryDay] {
        var groups: [HistoryDay] = []
        for entry in entries {
            let day = calendar.startOfDay(for: entry.date)
            if let last = groups.last, last.day == day {
                groups[groups.count - 1].entries.append(entry)
            } else {
                groups.append(HistoryDay(day: day, entries: [entry]))
            }
        }
        return groups
    }
}

/// All answers from one calendar day.
public struct HistoryDay: Identifiable, Equatable, Sendable {
    public let day: Date
    public fileprivate(set) var entries: [HistoryEntry]

    public var id: Date { day }
}

/// Reads and writes history as a small JSON file on the device. Nothing leaves the device.
public struct HistoryFile: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// The standard location inside the app's Application Support folder.
    public static func standard(fileManager: FileManager = .default) -> HistoryFile? {
        guard let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return HistoryFile(url: base.appendingPathComponent("YesNo", isDirectory: true)
            .appendingPathComponent("history.json"))
    }

    /// Returns an empty history if the file is missing or unreadable, so a damaged file never blocks an answer.
    public func load() -> History {
        guard let data = try? Data(contentsOf: url) else { return History() }
        return (try? Self.decoder.decode(History.self, from: data)) ?? History()
    }

    public func save(_ history: History) throws {
        try save(encoded: Self.encode(history))
    }

    /// Writes data produced by `encode(_:)`. Split out so encoding can happen on the main
    /// thread (cheap) and the disk write elsewhere.
    public func save(encoded data: Data) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

    public func delete() throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    public static func encode(_ history: History) throws -> Data {
        try encoder.encode(history)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
