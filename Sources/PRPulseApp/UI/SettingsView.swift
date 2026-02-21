import Foundation
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var newRepository = ""
    @State private var tokenInput = ""
    @State private var hasToken = false
    @State private var isTestingToken = false
    @State private var tokenTestMessage: String?
    @State private var tokenTestPassed = false
    private let tokenStore = KeychainTokenStore()

    var body: some View {
        List {
            Section("Account") {
                SecureField("GitHub Token", text: $tokenInput)
                HStack(spacing: 12) {
                    Button(hasToken ? "Update Token" : "Save Token") {
                        do {
                            try tokenStore.setToken(tokenInput)
                            hasToken = true
                            tokenInput = ""
                            tokenTestMessage = nil
                        } catch {
                            // Surface via view model error channel
                            viewModel.errorMessage = "Failed to save token: \(error.localizedDescription)"
                        }
                    }
                    .disabled(tokenInput.isEmpty)

                    Button("Clear Token", role: .destructive) {
                        do {
                            try tokenStore.clearToken()
                            hasToken = false
                            tokenTestMessage = nil
                        } catch {
                            viewModel.errorMessage = "Failed to clear token: \(error.localizedDescription)"
                        }
                    }
                    .disabled(!hasToken)

                    Button(isTestingToken ? "Testing..." : "Test Token") {
                        Task { await testToken() }
                    }
                    .disabled(isTestingToken)
                }
                HStack(spacing: 6) {
                    Circle()
                        .fill(hasToken ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    Text(hasToken ? "Token saved in Keychain" : "No token saved")
                        .foregroundColor(.secondary)
                }
                if let tokenTestMessage {
                    Text(tokenTestMessage)
                        .font(.footnote)
                        .foregroundStyle(tokenTestPassed ? .green : .secondary)
                }
                Text("Viewer: \(viewModel.viewerLogin)")
            }

            Section("Refresh") {
                Toggle("Refresh on launch", isOn: Binding(
                    get: { viewModel.settings.refreshOnLaunch },
                    set: { viewModel.settings.refreshOnLaunch = $0 }
                ))
                Stepper(
                    value: Binding(
                        get: { Int(viewModel.settings.refreshInterval) },
                        set: { viewModel.settings.refreshInterval = TimeInterval($0) }
                    ),
                    in: 60...3600,
                    step: 60
                ) {
                    Text("Refresh every \(Int(viewModel.settings.refreshInterval / 60)) min")
                }
            }

            Section("Notifications") {
                Toggle("Needs re-review", isOn: Binding(
                    get: { viewModel.settings.notifyNeedsReview },
                    set: { viewModel.settings.notifyNeedsReview = $0 }
                ))
                Toggle("Review requested", isOn: Binding(
                    get: { viewModel.settings.notifyNewReviewRequests },
                    set: { viewModel.settings.notifyNewReviewRequests = $0 }
                ))
                Picker("Digest cadence", selection: Binding(
                    get: { viewModel.settings.digestCadence },
                    set: { viewModel.settings.digestCadence = $0 }
                )) {
                    ForEach(DigestCadence.allCases) { cadence in
                        Text(cadence.rawValue.capitalized).tag(cadence)
                    }
                }
            }

            Section("Snooze") {
                Stepper(
                    value: Binding(
                        get: { viewModel.settings.snoozeDefaultHour },
                        set: { viewModel.settings.snoozeDefaultHour = $0 }
                    ),
                    in: 6...14
                ) {
                    Text("Default resume hour: \(viewModel.settings.snoozeDefaultHour):00")
                }
            }

            Section("Watched repositories") {
                ForEach(viewModel.settings.watchedRepositories) { repository in
                    Toggle(repository.nameWithOwner, isOn: bindingForRepository(repository))
                }
                HStack {
                    TextField("owner/repo", text: $newRepository)
                    Button("Add") {
                        guard !newRepository.isEmpty else { return }
                        var list = viewModel.settings.watchedRepositories
                        list.append(RepositorySubscription(nameWithOwner: newRepository, notificationsEnabled: true))
                        viewModel.settings.watchedRepositories = list
                        newRepository = ""
                    }
                }
            }

            Section("Debug") {
                HStack(spacing: 6) {
                    Text("Last refresh:")
                    if let last = viewModel.lastRefreshAt {
                        Text(last.formatted(date: .abbreviated, time: .standard))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Never").foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    Text("Current interval:")
                    Text("\(viewModel.currentRefreshIntervalMinutes) min")
                        .foregroundStyle(.secondary)
                }
                Button("Test Notification") {
                    viewModel.testNotification()
                }
                Button("Force Digest Recompute") {
                    viewModel.forceDigestRecompute()
                }
                Button("Refresh Now") {
                    viewModel.refreshNow()
                }
                Button("Open settings.json") {
                    Task { await viewModel.openSettingsJSON() }
                }
                Button("Copy viewer login") {
                    #if canImport(AppKit)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(viewModel.viewerLogin, forType: .string)
                    #endif
                }
                Button("Export logs") {
                    Task { await viewModel.exportDiagnostics() }
                }
            }
        }
        .listStyle(.inset)
        .onAppear {
            let existing = tokenStore.getToken()
            hasToken = (existing != nil)
            tokenInput = "" // do not display existing token
        }
        .onChange(of: tokenInput) { _ in
            tokenTestMessage = nil
        }
    }

    private func bindingForRepository(_ repository: RepositorySubscription) -> Binding<Bool> {
        Binding {
            repository.notificationsEnabled
        } set: { newValue in
            if let index = viewModel.settings.watchedRepositories.firstIndex(of: repository) {
                viewModel.settings.watchedRepositories[index].notificationsEnabled = newValue
            }
        }
    }

    private func tokenCandidate() -> String? {
        let typed = tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty {
            return typed
        }
        return tokenStore.getToken()
    }

    @MainActor
    private func testToken() async {
        guard let token = tokenCandidate(), !token.isEmpty else {
            tokenTestPassed = false
            tokenTestMessage = "Enter a token or save one first."
            return
        }

        isTestingToken = true
        defer { isTestingToken = false }
        tokenTestPassed = false
        tokenTestMessage = "Testing token..."

        do {
            let restViewer = try await validateTokenWithREST(token)

            let client = GitHubAPIClient(
                tokenProvider: { token },
                watchedRepositoriesProvider: { [] }
            )
            let graphQLViewer = try await client.fetchViewer()

            tokenTestPassed = true
            tokenTestMessage = "Valid token for \(graphQLViewer.isEmpty ? restViewer : graphQLViewer)."
        } catch {
            tokenTestPassed = false
            tokenTestMessage = "Token test failed: \(error.localizedDescription)"
        }
    }

    private func validateTokenWithREST(_ token: String) async throws -> String {
        struct AuthenticatedUser: Decodable {
            let login: String
        }

        var request = URLRequest(url: URL(string: "https://api.github.com/user")!)
        request.httpMethod = "GET"
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GitHubClientError.invalidResponse
        }

        guard http.statusCode == 200 else {
            switch http.statusCode {
            case 401:
                throw GitHubClientError.apiFailure("Invalid token (401 Unauthorized).")
            case 403:
                throw GitHubClientError.apiFailure("Token rejected (403 Forbidden). Check token type and repository access.")
            default:
                throw GitHubClientError.apiFailure("GitHub auth check failed (\(http.statusCode)).")
            }
        }

        let user = try JSONDecoder().decode(AuthenticatedUser.self, from: data)
        return user.login
    }
}
