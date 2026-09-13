import AppKit

@MainActor
enum SettingsWindowPresenter {
    static func show(
        activate: @MainActor () -> Void,
        open: @MainActor () -> Void,
        focus: @escaping @MainActor () -> Void
    ) {
        activate()
        open()
        Task { @MainActor in
            focus()
        }
    }

    static func showSettingsWindow(open: @escaping @MainActor () -> Void) {
        show(
            activate: {
                NSApplication.shared.activate(ignoringOtherApps: true)
            },
            open: open,
            focus: {
                NSApplication.shared.windows
                    .first(where: { $0.title == "Settings" })?
                    .makeKeyAndOrderFront(nil)
            }
        )
    }
}
