import SwiftUI
import AppKit

struct PullRequestRowView: View {
    var presentation: PullRequestPresentation
    var actionHandler: (DashboardViewModel.QuickAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(presentation.pullRequest.title)
                        .font(.headline)
                        .lineLimit(2)
                    Text(presentation.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                readinessBadge
            }

            HStack(spacing: 12) {
                if !presentation.actionableBadgeText.isEmpty {
                    Label(presentation.actionableBadgeText, systemImage: presentation.status.badge == .reviewed ? "checkmark.circle" : "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(presentation.status.badge == .reviewed ? .green : .orange)
                }

                Label("\(presentation.status.approvals) approvals", systemImage: "hand.thumbsup")
                    .font(.caption)
                Label("\(presentation.status.changesRequested) changes", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(presentation.status.changesRequested > 0 ? .orange : .secondary)
            }

            HStack {
                Button("Open") {
                    NSWorkspace.shared.open(presentation.pullRequest.url)
                }
                .buttonStyle(.borderedProminent)

                Button("TODO") {
                    actionHandler(.markTodo)
                }

                Button("N/A") {
                    actionHandler(.markNotApplicable)
                }

                Menu("Snooze") {
                    Button("Tomorrow morning") {
                        actionHandler(.snoozeTomorrow)
                    }
                    Button("1 hour") {
                        let date = Date().addingTimeInterval(3600)
                        actionHandler(.snooze(date))
                    }
                    Button("Clear") {
                        actionHandler(.clearOverride)
                    }
                }
                Spacer()
                if presentation.pullRequest.override.isSnoozed {
                    Text("Snoozed until \(presentation.pullRequest.override.snoozedUntil!, formatter: dateFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .font(.caption)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .contextMenu {
            Button("Mark TODO") { actionHandler(.markTodo) }
            Button("Mark N/A") { actionHandler(.markNotApplicable) }
            Button("Clear override") { actionHandler(.clearOverride) }
            Divider()
            Button("Snooze 1 hour") { actionHandler(.snooze(Date().addingTimeInterval(3600))) }
            Button("Snooze tomorrow") { actionHandler(.snoozeTomorrow) }
        }
    }

    private var readinessBadge: some View {
        switch presentation.status.readiness {
        case .ready:
            return Text("Ready to merge")
                .font(.caption)
                .padding(6)
                .background(Capsule().fill(Color.green.opacity(0.2)))
        case .pending:
            return Text("Pending")
                .font(.caption)
                .padding(6)
                .background(Capsule().fill(Color.orange.opacity(0.2)))
        case .blocked(let reason):
            return Text("Blocked: \(reason)")
                .font(.caption)
                .padding(6)
                .background(Capsule().fill(Color.red.opacity(0.2)))
        case .checking:
            return Text("Checking…")
                .font(.caption)
                .padding(6)
                .background(Capsule().fill(Color.gray.opacity(0.2)))
        }
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()
