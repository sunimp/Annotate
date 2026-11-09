import KeyboardShortcuts
import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage(.clearDrawingsOnStart)
    private var clearDrawingsOnStart: Bool
    @AppStorage(.hideDockIcon)
    private var hideDockIcon: Bool
    @AppStorage(.hideToolFeedback)
    private var hideToolFeedback: Bool
    @AppStorage(.toolbarVisible)
    private var toolbarVisible: Bool
    @AppStorage(.toolbarShowsShortcuts)
    private var toolbarShowsShortcuts: Bool
    @AppStorage(.toolbarLayout)
    private var toolbarLayout: ToolbarLayout
    @AppStorage(.soundsEnabled)
    private var soundsEnabled: Bool
    @AppStorage(.soundTheme)
    private var soundTheme: SoundTheme
    @AppStorage(.selectAfterPlacingText)
    private var selectAfterPlacingText: Bool
    @AppStorage(.defaultTool)
    private var defaultToolOption: DefaultToolOption
    @AppStorage(.fadeDelay)
    private var fadeDelay: Double
    @AppStorage(.urlCommandsEnabled)
    private var urlCommandsEnabled: Bool
    @AppStorage(.appLanguage)
    private var appLanguage: AppLanguage
    @AppStorage(.defaultLineWidth)
    private var defaultLineWidth: DefaultLineWidthOption
    @AppStorage(.defaultColor)
    private var defaultColor: DefaultColorOption

    /// A filled circle for the Default Color menu. Menus drop SwiftUI shapes, so it is an image.
    static func swatch(_ color: NSColor) -> NSImage {
        NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5)).fill()
            NSColor.separatorColor.setStroke()
            NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5)).stroke()
            return true
        }
    }

    /// Tools offered in the Default Tool picker, excluding Select and Eraser since neither
    /// is a sensible tool to land on when the overlay opens.
    private static let selectableDefaultTools = ToolType.allCases.filter {
        $0 != .select && $0 != .eraser
    }

    var body: some View {
        Form {
            Section {
                PaneHeader(pane: .general)
            }

            Section {
                LabeledContent {
                    GlobalShortcutRecorder(name: .toggleOverlay)
                } label: {
                    Text("Activation Shortcut")
                    Text("Primary keyboard shortcut to activate Annotate")
                    Text("Requires modifier keys (⌘, ⌥, ⌃, or ⇧)")
                }

                LabeledContent {
                    GlobalShortcutRecorder(name: .toggleAlwaysOnMode)
                } label: {
                    Text("Always-On Mode")
                    Text("Keep Annotate active without auto-hide")
                    Text("Requires modifier keys (⌘, ⌥, ⌃, or ⇧)")
                }
            } header: {
                SettingsHeader(
                    icon: "keyboard",
                    color: .gray,
                    title: L10n.string("Keyboard Shortcuts"),
                    subtitle: L10n.string("Set keyboard shortcuts to activate Annotate and jump to specific modes")
                )
            }

            Section {
                Toggle(isOn: $clearDrawingsOnStart) {
                    Text("Clear Drawings on Toggle")
                    Text("Clear all drawings when toggling overlay off")
                }

                Toggle(isOn: $hideToolFeedback) {
                    Text("Hide Tool Feedback")
                    Text("Disable visual feedback when switching tools")
                }

                Toggle(isOn: $toolbarVisible) {
                    Text("Show toolbar")
                    Text("Display the floating shortcut toolbar on annotation overlays")
                }
                .onChange(of: toolbarVisible) { _, visible in
                    AppDelegate.shared?.setToolbarVisible(visible)
                }

                Toggle(isOn: $toolbarShowsShortcuts) {
                    Text("Show shortcuts in toolbar")
                    Text("Label each toolbar button with its keyboard shortcut")
                }
                .disabled(!toolbarVisible)
                .onChange(of: toolbarShowsShortcuts) { _, _ in
                    AppDelegate.shared?.applyToolbarAppearance()
                }

                Picker(selection: $toolbarLayout) {
                    ForEach(ToolbarLayout.allCases, id: \.self) { layout in
                        Text(layout.displayName).tag(layout)
                    }
                } label: {
                    Text("Toolbar Layout")
                    Text("Run the toolbar along the bottom or down the left edge")
                }
                .disabled(!toolbarVisible)
                .onChange(of: toolbarLayout) { _, _ in
                    AppDelegate.shared?.applyToolbarAppearance()
                }

                Toggle(isOn: $soundsEnabled) {
                    Text("Play sounds")
                    Text("Play feedback sounds for overlay and clear actions")
                }

                Picker(selection: $soundTheme) {
                    ForEach(SoundTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                } label: {
                    Text("Sound Theme")
                    Text("Chalk, paper, marker, pencil, or typewriter cues")
                }
                .disabled(!soundsEnabled)
                .onChange(of: soundTheme) { _, _ in
                    SoundPlayer.shared.playOverlayOn()
                }

                Picker(selection: $appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(verbatim: language.displayName).tag(language)
                    }
                } label: {
                    Text("Language")
                    Text("Language for menus, settings, and on-screen feedback")
                }
                .onChange(of: appLanguage) { _, language in
                    AppDelegate.shared?.setLanguage(language)
                }

                Toggle(
                    isOn: Binding(
                        get: { !hideDockIcon },
                        set: { hideDockIcon = !$0 }
                    )
                ) {
                    Text("Show in Dock")
                    Text("Display Annotate icon in the Dock")
                }
                .onChange(of: hideDockIcon) { _, _ in
                    AppDelegate.shared?.updateDockIconVisibility()
                }

                Toggle(isOn: $selectAfterPlacingText) {
                    Text("Switch to Select after placing text")
                    Text("After committing a label, select it so you can move it right away")
                }

                Picker(selection: $defaultToolOption) {
                    Text("Last Used").tag(DefaultToolOption.lastUsed)
                    ForEach(Self.selectableDefaultTools, id: \.self) { tool in
                        Text(tool.displayName).tag(DefaultToolOption.tool(tool))
                    }
                } label: {
                    Text("Default Tool")
                    Text("Tool selected each time the overlay is activated")
                }

                Picker(selection: $defaultLineWidth) {
                    Text("Last Used").tag(DefaultLineWidthOption.lastUsed)
                    ForEach(DefaultLineWidthOption.widths, id: \.self) { width in
                        Text("\(Int(width)) px").tag(DefaultLineWidthOption.width(width))
                    }
                } label: {
                    Text("Default Line Width")
                    Text("Line width set each time the overlay is activated")
                }

                Picker(selection: $defaultColor) {
                    Text("Last Used").tag(DefaultColorOption.lastUsed)
                    ForEach(PaletteColor.allCases, id: \.self) { color in
                        Label {
                            Text(verbatim: color.displayName)
                        } icon: {
                            Image(nsImage: Self.swatch(color.nsColor))
                        }
                        .tag(DefaultColorOption.color(color))
                    }
                } label: {
                    Text("Default Color")
                    Text("Color set each time the overlay is activated")
                }

                Toggle(isOn: $urlCommandsEnabled) {
                    Text("Allow URL commands")
                    Text("Run \(AnnotateCommand.urlScheme):// links from other apps, scripts, and the browser")
                }
            } header: {
                SettingsHeader(
                    icon: "macwindow",
                    color: .blue,
                    title: L10n.string("Application"),
                    subtitle: L10n.string("Configure app launch and display options")
                )
            }

            Section {
                SettingsSliderRow(
                    title: L10n.string("Fade Delay"),
                    value: $fadeDelay,
                    range: fadeDelayRange,
                    step: 0.125,
                    valueText: fadeDelayLabel,
                    boundsText: fadeDelayLabel
                )
                .onChange(of: fadeDelay) { _, _ in
                    AppDelegate.shared?.applyFadeDelay()
                }
            } header: {
                SettingsHeader(
                    icon: "timer",
                    color: .purple,
                    title: L10n.string("Fade Mode"),
                    subtitle: L10n.string("How long annotations stay at full opacity before fading out")
                )
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
        .settingsScrollEdgeEffect()
    }
}

enum GlobalShortcutRecordingHandler {
    @MainActor
    static func handle(_ shortcut: KeyboardShortcuts.Shortcut?, for name: KeyboardShortcuts.Name,
                       previousShortcut: KeyboardShortcuts.Shortcut?, manager: ShortcutManager? = nil) -> String? {
        guard let shortcut,
            let conflict = (manager ?? .shared).conflictForGlobalShortcut(shortcut, excluding: name)
        else { return nil }
        // Recorder saves before invoking its callback. Restore the accepted binding on conflict.
        KeyboardShortcuts.setShortcut(previousShortcut, for: name)
        return L10n.string("This shortcut is already assigned to \(conflict). Change or clear it first.")
    }
}

private struct GlobalShortcutRecorder: View {
    let name: KeyboardShortcuts.Name
    @State private var previousShortcut: KeyboardShortcuts.Shortcut?
    @State private var conflictMessage: String?

    var body: some View {
        KeyboardShortcuts.Recorder("", name: name) { shortcut in
            conflictMessage = GlobalShortcutRecordingHandler.handle(
                shortcut, for: name, previousShortcut: previousShortcut)
            if conflictMessage == nil { previousShortcut = shortcut }
        }
        .onAppear { previousShortcut = KeyboardShortcuts.getShortcut(for: name) }
        .alert("Shortcut Unavailable", isPresented: Binding(
            get: { conflictMessage != nil },
            set: { if !$0 { conflictMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(conflictMessage ?? "")
        }
    }
}
