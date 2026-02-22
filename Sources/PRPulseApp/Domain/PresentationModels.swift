import Foundation

struct PullRequestPresentation: Identifiable, Equatable {
    var pullRequest: PullRequest
    var status: PullRequestStatus

    var id: String { pullRequest.id }

    var subtitle: String {
        "#\(pullRequest.number) · \(pullRequest.repository.nameWithOwner)"
    }

    var actionableBadgeText: String {
        switch status.badge {
        case .none:
            return ""
        case .reviewed:
            return "Reviewed"
        case .needsReReview:
            return "Needs re-review"
        }
    }

    var linkedReferencesSummary: String {
        let refs = pullRequest.detail.linkedReferences
        guard !refs.isEmpty else { return "" }

        let labels = refs.prefix(3).map { ref in
            let kind = ref.type == .issue ? "Issue" : "PR"
            return "\(kind) #\(ref.number)"
        }
        let extra = refs.count > 3 ? " +\(refs.count - 3)" : ""
        return "Linked: " + labels.joined(separator: " • ") + extra
    }
}
