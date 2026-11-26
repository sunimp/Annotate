import SwiftUI

/// The six settings panes, in sidebar order.
enum SettingsPane: String, CaseIterable, Identifiable {
    case general = "General"
    case tools = "Tools"
    case board = "Board"
    case cursor = "Cursor"
    case capture = "Capture"
    case shortcuts = "Shortcuts"

    var id: String { rawValue }

    /// Sidebar label and window title.
    var title: String {
        switch self {
        case .general: L10n.string("General")
        case .tools: L10n.string("Tools")
        case .board: L10n.string("Board")
        case .cursor: L10n.string("Cursor")
        case .capture: L10n.string("Capture")
        case .shortcuts: L10n.string("Shortcuts")
        }
    }

    /// SF Symbol shown in the sidebar.
    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .tools: "pencil.and.outline"
        case .board: "rectangle.on.rectangle"
        case .cursor: "cursorarrow.rays"
        case .capture: "camera.viewfinder"
        case .shortcuts: "keyboard"
        }
    }

    /// Catalog keys of the section and row titles the sidebar search matches, besides the
    /// pane title. Search matches each one in English and in the current language.
    /// ponytail: a hand-kept list; derive it from the panes if it drifts from what they show.
    var searchTerms: [String] {
        switch self {
        case .general: [
            "Application", "Launch at Login", "Show Dock Icon",
            "Show Menu Bar Icon", "Language", "Allow URL commands",
            "Overlay", "Annotate On", "Default Tool",
            "Fixed Line Width", "Fixed Color", "Clear Drawings on Toggle",
            "Switch to Select after placing text", "Hide Tool Feedback",
            "Toolbar", "Show toolbar", "Show shortcuts in toolbar",
            "Toolbar Layout", "Sound", "Play sounds",
            "Sound Theme", "Fade Mode", "Fade Delay",
        ]
        case .tools: [
            "Arrow Tool", "Text Tool", "Default Text Size",
            "Label background", "Counter Tool", "Default Counter Size",
            "Redact Tool",
        ]
        case .board: ["Board Settings", "Enable Board", "Board Opacity"]
        case .cursor: [
            "Active Cursor", "Cursor Style", "Cursor Size",
            "Cursor Highlight", "Enable Cursor Spotlight", "Spotlight Size",
            "Dim Background", "Dimming Amount", "Enable Click Effect",
            "Click Effect Size", "Effect Color", "Hide Cursor Effects In",
        ]
        case .capture: [
            "Folder", "After capture", "Save annotation data next to screenshots",
            "Notifications", "Screen Recording",
        ]
        case .shortcuts: [
            "Global Shortcuts", "Activation Shortcut", "Always-On Mode",
            "Drawing Tools", "Shapes", "Advanced Tools",
            "Utilities", "Built-in Shortcuts", "Colors",
        ]
        }
    }

    /// Whether the pane's title or one of its `searchTerms`, in English or the current
    /// language, contains `query`. An empty query matches every pane.
    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        let keys = [rawValue] + searchTerms
        return (keys + keys.map { L10n.string(String.LocalizationValue($0)) })
            .contains { $0.localizedStandardContains(query) }
    }
}

/// Which pane the settings window shows. `SettingsWindowManager` owns one, so the app can
/// open the window to a pane. Used on the main thread only; not actor-isolated so views can
/// make one as a default argument.
@Observable
final class SettingsNavigation {
    var selection: SettingsPane? = .general
    /// Set when a capture found Screen Recording off. The Capture pane asks for access as it
    /// shows, then clears it.
    var requestsScreenRecording = false
}

/// The settings window's content: a searchable sidebar of panes beside the selected pane's
/// grouped form.
struct SettingsView: View {
    @Bindable var navigation: SettingsNavigation
    @State private var query = ""

    init(navigation: SettingsNavigation = SettingsNavigation()) {
        self.navigation = navigation
    }

    private var matchingPanes: [SettingsPane] {
        SettingsPane.allCases.filter { $0.matches(query) }
    }

    var body: some View {
        NavigationSplitView {
            List(matchingPanes, selection: $navigation.selection) { pane in
                Label(pane.title, systemImage: pane.symbol)
                    .tag(pane)
            }
            .listItemTint(.monochrome)
            .overlay {
                if matchingPanes.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, placement: .sidebar, prompt: Text("Search Settings"))
            .onChange(of: query) {
                // Keep the detail on a pane the sidebar still lists.
                if let first = matchingPanes.first, !matchingPanes.contains(navigation.selection ?? .general) {
                    navigation.selection = first
                }
            }
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            paneView(navigation.selection ?? .general)
        }
        .frame(minWidth: 720, minHeight: 480)
    }

    @ViewBuilder
    private func paneView(_ pane: SettingsPane) -> some View {
        switch pane {
        case .general: GeneralSettingsView()
        case .tools: ToolsSettingsView { navigation.selection = .capture }
        case .board: BoardSettingsView()
        case .cursor: CursorSettingsView()
        case .capture: CaptureSettingsView(navigation: navigation)
        case .shortcuts: ShortcutsSettingsView()
        }
    }
}
