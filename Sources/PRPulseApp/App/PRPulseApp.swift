import SwiftUI

@main
struct PRPulseApp: App {
    @StateObject private var dependencies = AppDependencies()

    var body: some Scene {
        MenuBarExtra {
            ContentView(viewModel: dependencies.dashboard)
                .frame(width: 420, height: 560)
                .task {
                    await dependencies.dashboard.requestNotificationAuthorization()
                }
        } label: {
            BadgeIcon(badgeCount: dependencies.dashboard.badgeCount)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(viewModel: dependencies.dashboard)
                .frame(width: 520, height: 520)
        }
    }
}

private struct BadgeIcon: View {
    var badgeCount: Int

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "tray.full")
                .symbolRenderingMode(.hierarchical)
            if badgeCount > 0 {
                Text("\(min(99, badgeCount))")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.red))
                    .foregroundColor(.white)
                    .offset(x: 8, y: -8)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .accessibilityLabel("PRPulse \(badgeCount) actionable")
    }
}
