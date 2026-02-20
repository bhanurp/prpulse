import Foundation

@MainActor
final class AppDependencies: ObservableObject {
    let dashboard: DashboardViewModel

    init() {
        let store = PullRequestStore()
        let notifier = NotificationDispatcher(store: store)
        let scheduler = RefreshScheduler()
        let digestComputer = DigestComputer()
        let client: GitHubClient
        if Self.shouldUseMockClient {
            client = MockGitHubClient()
        } else {
            client = GitHubAPIClient(
                watchedRepositoriesProvider: {
                    await store.loadSettings().watchedRepositories
                }
            )
        }

        self.dashboard = DashboardViewModel(
            client: client,
            store: store,
            notifier: notifier,
            scheduler: scheduler,
            digestComputer: digestComputer
        )
    }

    private static var shouldUseMockClient: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestConfigurationFilePath"] != nil || env["PRPULSE_USE_MOCK_CLIENT"] == "1"
    }
}
