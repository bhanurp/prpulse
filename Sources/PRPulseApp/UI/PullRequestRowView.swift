import SwiftUI
import AppKit

struct PullRequestRowView: View {
    var presentation: PullRequestPresentation
    var actionHandler: (DashboardViewModel.QuickAction) -> Void
    var showAuthor: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(presentation.pullRequest.title)
                        .font(.headline)
                        .lineLimit(2)
                    Text(metadataText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    readinessBadge
                    if !presentation.pullRequest.detail.linkedReferences.isEmpty {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Linked")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            ForEach(Array(presentation.pullRequest.detail.linkedReferences.prefix(3))) { ref in
                                if let url = linkedReferenceURL(ref) {
                                    Link(linkedReferenceLabel(ref), destination: url)
                                        .font(.caption2)
                                        .lineLimit(1)
                                } else {
                                    Text(linkedReferenceLabel(ref))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            if presentation.pullRequest.detail.linkedReferences.count > 3 {
                                Text("+\(presentation.pullRequest.detail.linkedReferences.count - 3) more")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
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

    private var metadataText: String {
        guard showAuthor else {
            return presentation.subtitle
        }
        return "\(presentation.subtitle) · @\(presentation.pullRequest.author.login)"
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

    private func linkedReferenceLabel(_ ref: PullRequestDetail.LinkedReference) -> String {
        let kind = ref.type == .issue ? "Issue" : "PR"
        return "\(kind) #\(ref.number)"
    }

    private func linkedReferenceURL(_ ref: PullRequestDetail.LinkedReference) -> URL? {
        if let url = ref.url {
            return url
        }

        let pathPart = ref.type == .issue ? "issues" : "pull"
        return URL(string: "https://github.com/\(ref.repositoryNameWithOwner)/\(pathPart)/\(ref.number)")
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()
