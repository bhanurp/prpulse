import Foundation

protocol GitHubClient {
    nonisolated(nonsending) func fetchViewer() async throws -> String
    nonisolated(nonsending) func fetchPullRequests(tab: PullRequestTab, cursor: String?) async throws -> PullRequestPage
}

enum GitHubClientError: LocalizedError {
    case missingToken
    case invalidResponse
    case invalidDate(String)
    case graphQLErrors([String])
    case apiFailure(String)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "GitHub token missing. Save a token in Settings first."
        case .invalidResponse:
            return "GitHub API returned an invalid response."
        case .invalidDate(let value):
            return "GitHub API returned an invalid date: \(value)"
        case .graphQLErrors(let messages):
            return messages.joined(separator: "\n")
        case .apiFailure(let message):
            return message
        }
    }
}

struct GitHubAPIClient: GitHubClient {
    private let session: URLSession
    private let tokenProvider: @Sendable () -> String?
    private let watchedRepositoriesProvider: @Sendable () async -> [RepositorySubscription]

    init(
        session: URLSession = .shared,
        tokenProvider: @escaping @Sendable () -> String? = { KeychainTokenStore().getToken() },
        watchedRepositoriesProvider: @escaping @Sendable () async -> [RepositorySubscription] = { [] }
    ) {
        self.session = session
        self.tokenProvider = tokenProvider
        self.watchedRepositoriesProvider = watchedRepositoriesProvider
    }

    nonisolated(nonsending) func fetchViewer() async throws -> String {
        let data: ViewerData = try await performGraphQL(query: Self.viewerQuery, variables: EmptyVariables())
        return data.viewer.login
    }

    nonisolated(nonsending) func fetchPullRequests(tab: PullRequestTab, cursor: String?) async throws -> PullRequestPage {
        let page: PullRequestPage
        switch tab {
        case .mine, .reviewRequested:
            let query = Self.searchQuery(for: tab)
            page = try await fetchSearchPage(query: query, cursor: cursor)
        case .watched:
            page = try await fetchWatchedPage(cursor: cursor)
        }

        guard !page.items.isEmpty else {
            return page
        }

        let detailByID = try await fetchDetails(ids: page.items.map(\.id))
        let enriched = page.items.map { item -> PullRequest in
            var copy = item
            if let detail = detailByID[item.id] {
                copy.detail = detail
            }
            return copy
        }
        return PullRequestPage(items: enriched, cursor: page.cursor, hasNextPage: page.hasNextPage)
    }

    private func fetchSearchPage(query: String, cursor: String?) async throws -> PullRequestPage {
        let variables = SearchVariables(query: query, after: cursor)
        let data: SearchData = try await performGraphQL(query: Self.searchPullRequestsQuery, variables: variables)

        let items = data.search.nodes.compactMap { node -> PullRequest? in
            guard let node,
                  let id = node.id,
                  let number = node.number,
                  let title = node.title,
                  let urlString = node.url,
                  let url = URL(string: urlString),
                  let createdAtRaw = node.createdAt,
                  let updatedAtRaw = node.updatedAt,
                  let createdAt = Self.parseISODate(createdAtRaw),
                  let updatedAt = Self.parseISODate(updatedAtRaw),
                  let repository = node.repository?.nameWithOwner else {
                return nil
            }

            let author = node.author?.login ?? "unknown"
            return PullRequest(
                id: id,
                number: number,
                title: title,
                url: url,
                repository: .init(nameWithOwner: repository),
                author: .init(login: author),
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDraft: node.isDraft ?? false
            )
        }

        return PullRequestPage(
            items: items,
            cursor: data.search.pageInfo.endCursor,
            hasNextPage: data.search.pageInfo.hasNextPage
        )
    }

    private func fetchWatchedPage(cursor: String?) async throws -> PullRequestPage {
        // Keep pagination simple for watched repos: merge the latest page from each watched repo.
        guard cursor == nil else {
            return PullRequestPage(items: [], cursor: nil, hasNextPage: false)
        }

        let watchedRepos = await watchedRepositoriesProvider()
            .map(\.nameWithOwner)
            .filter { !$0.isEmpty }

        guard !watchedRepos.isEmpty else {
            return PullRequestPage(items: [], cursor: nil, hasNextPage: false)
        }

        var merged: [PullRequest] = []
        for repo in Set(watchedRepos) {
            let query = "repo:\(repo) is:pr is:open sort:updated-desc"
            let page = try await fetchSearchPage(query: query, cursor: nil)
            merged.append(contentsOf: page.items)
        }

        var deduped: [String: PullRequest] = [:]
        for item in merged {
            if let existing = deduped[item.id] {
                deduped[item.id] = (item.updatedAt > existing.updatedAt) ? item : existing
            } else {
                deduped[item.id] = item
            }
        }

        let top = deduped.values
            .sorted(by: { $0.updatedAt > $1.updatedAt })
            .prefix(20)

        return PullRequestPage(items: Array(top), cursor: nil, hasNextPage: false)
    }

    private func fetchDetails(ids: [String]) async throws -> [String: PullRequestDetail] {
        guard !ids.isEmpty else { return [:] }

        let variables = DetailVariables(ids: ids)
        let data: DetailData = try await performGraphQL(query: Self.pullRequestDetailsQuery, variables: variables)

        var detailByID: [String: PullRequestDetail] = [:]
        for node in data.nodes {
            guard let node, let id = node.id else { continue }

            let mergeable = PullRequestDetail.MergeableState(rawValue: node.mergeable ?? "UNKNOWN") ?? .unknown
            let reviewDecision: PullRequestDetail.ReviewDecision? = {
                guard let raw = node.reviewDecision else { return nil }
                return PullRequestDetail.ReviewDecision(rawValue: raw)
            }()
            let latestCommitAt = node.commits?.nodes.last?.commit?.committedDate.flatMap(Self.parseISODate)

            let reviews: [PullRequestDetail.Review] = (node.reviews?.nodes ?? []).compactMap { rawReview in
                guard let rawReview,
                      let reviewer = rawReview.author?.login,
                      let submittedRaw = rawReview.submittedAt,
                      let submittedAt = Self.parseISODate(submittedRaw),
                      let state = Self.mapReviewState(rawReview.state) else {
                    return nil
                }
                return PullRequestDetail.Review(reviewer: reviewer, state: state, submittedAt: submittedAt)
            }

            detailByID[id] = PullRequestDetail(
                mergeable: mergeable,
                reviewDecision: reviewDecision,
                latestCommitAt: latestCommitAt,
                reviews: reviews
            )
        }

        return detailByID
    }

    private func performGraphQL<Variables: Encodable, DataType: Decodable>(
        query: String,
        variables: Variables
    ) async throws -> DataType {
        guard let token = tokenProvider(), !token.isEmpty else {
            throw GitHubClientError.missingToken
        }

        var request = URLRequest(url: Self.graphQLEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try Self.encoder.encode(GraphQLRequest(query: query, variables: variables))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GitHubClientError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let failure = try? Self.decoder.decode(APIFailure.self, from: data)
            throw GitHubClientError.apiFailure(failure?.message ?? "GitHub API error \(http.statusCode)")
        }

        let decoded = try Self.decoder.decode(GraphQLResponse<DataType>.self, from: data)
        if let errors = decoded.errors, !errors.isEmpty {
            throw GitHubClientError.graphQLErrors(errors.map(\.message))
        }

        guard let payload = decoded.data else {
            throw GitHubClientError.invalidResponse
        }
        return payload
    }

    private static func searchQuery(for tab: PullRequestTab) -> String {
        switch tab {
        case .mine:
            return "is:pr is:open author:@me sort:updated-desc"
        case .reviewRequested:
            return "is:pr is:open review-requested:@me sort:updated-desc"
        case .watched:
            return "is:pr is:open sort:updated-desc"
        }
    }

    private static func parseISODate(_ raw: String) -> Date? {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let value = withFractional.date(from: raw) {
            return value
        }

        let withoutFractional = ISO8601DateFormatter()
        withoutFractional.formatOptions = [.withInternetDateTime]
        return withoutFractional.date(from: raw)
    }

    private static func mapReviewState(_ raw: String?) -> PullRequestDetail.Review.State? {
        guard let raw else { return nil }
        switch raw {
        case PullRequestDetail.Review.State.approved.rawValue:
            return .approved
        case PullRequestDetail.Review.State.changesRequested.rawValue:
            return .changesRequested
        case PullRequestDetail.Review.State.dismissed.rawValue:
            return .dismissed
        case PullRequestDetail.Review.State.commented.rawValue:
            return .commented
        default:
            return nil
        }
    }

    private static let graphQLEndpoint = URL(string: "https://api.github.com/graphql")!

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        return encoder
    }()

    private static let decoder = JSONDecoder()

    private static let viewerQuery = """
    query Viewer {
      viewer { login }
    }
    """

    private static let searchPullRequestsQuery = """
    query SearchPRs($query: String!, $after: String) {
      search(query: $query, type: ISSUE, first: 20, after: $after) {
        pageInfo { hasNextPage endCursor }
        nodes {
          ... on PullRequest {
            id
            number
            title
            url
            createdAt
            updatedAt
            isDraft
            author { login }
            repository { nameWithOwner }
          }
        }
      }
    }
    """

    private static let pullRequestDetailsQuery = """
    query PRDetails($ids: [ID!]!) {
      nodes(ids: $ids) {
        ... on PullRequest {
          id
          mergeable
          reviewDecision
          commits(last: 1) {
            nodes { commit { committedDate } }
          }
          reviews(last: 50) {
            nodes {
              author { login }
              state
              submittedAt
            }
          }
        }
      }
    }
    """
}

private struct EmptyVariables: Encodable {}

private struct GraphQLRequest<Variables: Encodable>: Encodable {
    let query: String
    let variables: Variables
}

private struct GraphQLResponse<DataType: Decodable>: Decodable {
    let data: DataType?
    let errors: [GraphQLError]?
}

private struct GraphQLError: Decodable {
    let message: String
}

private struct APIFailure: Decodable {
    let message: String
}

private struct ViewerData: Decodable {
    struct Viewer: Decodable {
        let login: String
    }
    let viewer: Viewer
}

private struct SearchVariables: Encodable {
    let query: String
    let after: String?
}

private struct SearchData: Decodable {
    struct SearchConnection: Decodable {
        struct PageInfo: Decodable {
            let hasNextPage: Bool
            let endCursor: String?
        }

        struct SearchNode: Decodable {
            struct Author: Decodable {
                let login: String?
            }

            struct Repository: Decodable {
                let nameWithOwner: String?
            }

            let id: String?
            let number: Int?
            let title: String?
            let url: String?
            let createdAt: String?
            let updatedAt: String?
            let isDraft: Bool?
            let author: Author?
            let repository: Repository?
        }

        let pageInfo: PageInfo
        let nodes: [SearchNode?]
    }

    let search: SearchConnection
}

private struct DetailVariables: Encodable {
    let ids: [String]
}

private struct DetailData: Decodable {
    struct PullRequestNode: Decodable {
        struct Commits: Decodable {
            struct CommitNode: Decodable {
                struct Commit: Decodable {
                    let committedDate: String?
                }
                let commit: Commit?
            }
            let nodes: [CommitNode]
        }

        struct Reviews: Decodable {
            struct ReviewNode: Decodable {
                struct Author: Decodable {
                    let login: String?
                }
                let author: Author?
                let state: String?
                let submittedAt: String?
            }
            let nodes: [ReviewNode?]
        }

        let id: String?
        let mergeable: String?
        let reviewDecision: String?
        let commits: Commits?
        let reviews: Reviews?
    }

    let nodes: [PullRequestNode?]
}

struct MockGitHubClient: GitHubClient {
    private var currentUser: String
    private var dataset: [PullRequestTab: [PullRequest]]
    private let pageSize = 20

    init(currentUser: String = "octocat") {
        self.currentUser = currentUser
        self.dataset = MockGitHubClient.makeDataset(currentUser: currentUser)
    }

    nonisolated(nonsending) func fetchViewer() async throws -> String {
        currentUser
    }

    nonisolated(nonsending) func fetchPullRequests(tab: PullRequestTab, cursor: String?) async throws -> PullRequestPage {
        let allItems = dataset[tab] ?? []
        let startIndex: Int
        if let cursor, let index = Int(cursor) {
            startIndex = index
        } else {
            startIndex = 0
        }

        let endIndex = min(startIndex + pageSize, allItems.count)
        let items = Array(allItems[startIndex..<endIndex])
        let hasNext = endIndex < allItems.count
        let nextCursor = hasNext ? String(endIndex) : nil

        // simulate latency
        try await Task.sleep(nanoseconds: 150_000_000)

        return PullRequestPage(items: items, cursor: nextCursor, hasNextPage: hasNext)
    }

    private static func makeDataset(currentUser: String) -> [PullRequestTab: [PullRequest]] {
        var mine: [PullRequest] = []
        var reviewRequested: [PullRequest] = []
        var watched: [PullRequest] = []

        for index in 1...35 {
            let isDraft = index % 5 == 0
            let repo = PullRequest.Repository(nameWithOwner: "apple/swift-\(index % 4)")
            let detail = PullRequestDetail(
                mergeable: isDraft ? .unknown : (index % 2 == 0 ? .mergeable : .conflicting),
                reviewDecision: index % 3 == 0 ? .approved : .reviewRequired,
                latestCommitAt: Date().addingTimeInterval(Double(-index * 18_000)),
                reviews: makeReviews(index: index, currentUser: currentUser)
            )
            let pr = PullRequest(
                id: UUID().uuidString,
                number: 1000 + index,
                title: "Improve reliability of build pipeline \(index)",
                url: URL(string: "https://github.com/\(repo.nameWithOwner)/pull/\(1000 + index)")!,
                repository: repo,
                author: .init(login: index % 2 == 0 ? currentUser : "collaborator\(index)"),
                createdAt: Date().addingTimeInterval(Double(-index * 48_000)),
                updatedAt: Date().addingTimeInterval(Double(-index * 22_000)),
                isDraft: isDraft,
                detail: detail,
                override: PullRequestOverride()
            )

            mine.append(pr)
            if index % 2 == 0 {
                reviewRequested.append(pr)
            }
            if index % 3 == 0 {
                watched.append(pr)
            }
        }

        return [.mine: mine, .reviewRequested: reviewRequested, .watched: watched]
    }

    private static func makeReviews(index: Int, currentUser: String) -> [PullRequestDetail.Review] {
        var reviews: [PullRequestDetail.Review] = []
        let baseDate = Date().addingTimeInterval(TimeInterval(-index * 11_000))
        let reviewers = ["alice", "bob", currentUser, "eve"].shuffled()
        for (offset, reviewer) in reviewers.enumerated() {
            let state: PullRequestDetail.Review.State
            switch (offset + index) % 3 {
            case 0:
                state = .approved
            case 1:
                state = .changesRequested
            default:
                state = .commented
            }
            let review = PullRequestDetail.Review(
                reviewer: reviewer,
                state: state,
                submittedAt: baseDate.addingTimeInterval(TimeInterval(offset * 4_000))
            )
            reviews.append(review)
        }
        return reviews
    }
}
