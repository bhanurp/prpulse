import Foundation

struct DigestComputer {
    func makeSnapshot(from events: [ActivityEvent], cadence: DigestCadence) -> DigestSnapshot {
        let now = Date()
        let calendar = Calendar.current
        let daysBack: Int
        switch cadence {
        case .weekly:
            daysBack = 7
        case .biWeekly:
            daysBack = 14
        case .off:
            daysBack = 0
        }

        let cutoff = calendar.date(byAdding: .day, value: -daysBack, to: now) ?? now
        let filtered = events.filter { $0.date >= cutoff }
        let opened = filtered.filter { $0.type == .openedMyPR }.count
        let reviewed = filtered.filter { $0.type == .reviewedPR }.count

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let timeframe = daysBack == 0 ? "N/A" : formatter.localizedString(for: cutoff, relativeTo: now)

        return DigestSnapshot(openedCount: opened, reviewedCount: reviewed, timeframeDescription: timeframe)
    }
}
