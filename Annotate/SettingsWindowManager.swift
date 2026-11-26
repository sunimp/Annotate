import AppKit
import SwiftUI

/// Owns the AppKit window that hosts `SettingsView`.
///
/// Built by hand rather than through the SwiftUI `Settings` scene, which AppKit can't open
/// to a pane or report closing. The window is titled with the shown pane.
@MainActor
final class SettingsWindowManager {
    static let shared = SettingsWindowManager()

    /// The settings window, if it has been created. Cleared when it closes.
    fileprivate(set) var settingsWindow: NSWindow?

    /// Strong reference to the delegate; `NSWindow.delegate` is weak.
    fileprivate var windowDelegate: SettingsWindowDelegate?

    /// The pane the open window shows. Each new window starts fresh, on General.
    private(set) var navigation = SettingsNavigation()

    /// Bumped by each `updateTitle()` so only the newest observation keeps the title current.
    private var titleGeneration = 0

    /// Run once when the window closes.
    private var closeHandlers: [@MainActor () -> Void] = []

    private init() {}

    /// Shows the settings window, creating it on first use and re-fronting the existing one
    /// after. With a `pane`, switches to it. `requestingScreenRecording` has the Capture pane
    /// ask for Screen Recording access. `onClose` runs when the window closes, including a
    /// window that was already open.
    func show(
        pane: SettingsPane? = nil,
        requestingScreenRecording: Bool = false,
        onClose: (@MainActor () -> Void)? = nil
    ) {
        if let onClose {
            closeHandlers.append(onClose)
        }
        if settingsWindow == nil {
            navigation = SettingsNavigation()
            makeWindow()
        }
        if let pane {
            navigation.selection = pane
        }
        if requestingScreenRecording {
            navigation.requestsScreenRecording = true
        }
        guard let window = settingsWindow else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.deminiaturize(nil)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() {
        let controller = NSHostingController(rootView: SettingsView(navigation: navigation).localizedEnvironment())
        controller.sceneBridgingOptions = [.toolbars]

        let window = NSWindow(contentViewController: controller)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.toolbarStyle = .unified
        window.setContentSize(NSSize(width: 860, height: 640))
        window.center()
        window.isReleasedWhenClosed = false

        let delegate = SettingsWindowDelegate()
        window.delegate = delegate
        windowDelegate = delegate
        settingsWindow = window
        updateTitle()
    }

    /// Titles the window with the shown pane, now and whenever the selection changes.
    /// Call again after a language change.
    func updateTitle() {
        guard let window = settingsWindow else { return }
        // Each call starts a new observation chain; older chains stop at the next change.
        titleGeneration += 1
        let generation = titleGeneration
        let navigation = navigation
        window.title = withObservationTracking {
            (navigation.selection ?? .general).title
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, self.titleGeneration == generation else { return }
                self.updateTitle()
            }
        }
    }

    fileprivate func windowWillClose() {
        settingsWindow = nil
        windowDelegate = nil
        let handlers = closeHandlers
        closeHandlers = []
        handlers.forEach { $0() }
    }
}

/// Clears the manager's references when the window closes so the next `show()` builds a
/// fresh window.
private final class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    func windowWillClose(_: Notification) {
        SettingsWindowManager.shared.windowWillClose()
    }
}
