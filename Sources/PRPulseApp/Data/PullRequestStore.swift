import Foundation

actor PullRequestStore {
    private let overridesURL: URL
    private let ledgerURL: URL
    private let settingsURL: URL
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private var overrides: [String: PullRequestOverride]
    private var notificationLedger: [String: Date]
    private var settings: AppSettings
    private var activityEvents: [ActivityEvent]
    private let activityURL: URL

    init(
        directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("PRPulseApp", isDirectory: true)
    ) {
        self.overridesURL = directory.appendingPathComponent("overrides.json")
        self.ledgerURL = directory.appendingPathComponent("ledger.json")
        self.settingsURL = directory.appendingPathComponent("settings.json")
        self.activityURL = directory.appendingPathComponent("activity.json")

        let fm = FileManager.default
        if !fm.fileExists(atPath: directory.path) {
            try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        self.overrides = (try? decoder.decode([String: PullRequestOverride].self, from: Data(contentsOf: overridesURL))) ?? [:]
        self.notificationLedger = (try? decoder.decode([String: Date].self, from: Data(contentsOf: ledgerURL))) ?? [:]
        var decoded = (try? decoder.decode(AppSettings.self, from: Data(contentsOf: settingsURL))) ?? .default
        decoded.token = "" // never load token from disk
        self.settings = decoded
        self.activityEvents = (try? decoder.decode([ActivityEvent].self, from: Data(contentsOf: activityURL))) ?? []

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func override(for id: String) -> PullRequestOverride {
        overrides[id] ?? PullRequestOverride()
    }

    func saveOverride(_ value: PullRequestOverride, for id: String) async throws {
        overrides[id] = value
        try await persistOverrides()
    }

    func ledgerTimestamp(for key: String) -> Date? {
        notificationLedger[key]
    }

    func updateLedger(date: Date, for key: String) async throws {
        notificationLedger[key] = date
        try await persistLedger()
    }

    func loadSettings() -> AppSettings {
        settings
    }

    func save(settings newSettings: AppSettings) async throws {
        settings = newSettings
        try await persistSettings()
    }

    func appendActivity(_ event: ActivityEvent) async throws {
        activityEvents.append(event)
        try await persistActivity()
    }

    func recentActivity(since date: Date) -> [ActivityEvent] {
        activityEvents.filter { $0.date >= date }
    }

    private func persistOverrides() async throws {
        let data = try encoder.encode(overrides)
        try data.write(to: overridesURL, options: .atomic)
    }

    private func persistLedger() async throws {
        let data = try encoder.encode(notificationLedger)
        try data.write(to: ledgerURL, options: .atomic)
    }

    private func persistSettings() async throws {
        var sanitized = settings
        sanitized.token = "" // never persist token to disk
        let data = try encoder.encode(sanitized)
        try data.write(to: settingsURL, options: .atomic)
    }

    private func persistActivity() async throws {
        let data = try encoder.encode(activityEvents)
        try data.write(to: activityURL, options: .atomic)
    }
}
