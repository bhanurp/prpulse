import Foundation

actor RefreshScheduler {
    private var task: Task<Void, Never>?

    func start(interval: TimeInterval, action: @escaping @Sendable () async -> Void) {
        task?.cancel()
        guard interval > 0 else { return }

        task = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                await action()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
