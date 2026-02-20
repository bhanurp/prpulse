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
}
