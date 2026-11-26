import KeyboardShortcuts
import OSLog
import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage(.clearDrawingsOnStart)
    private var clearDrawingsOnStart: Bool
    @AppStorage(.hideDockIcon)
    private var hideDockIcon: Bool
    @AppStorage(.showMenuBarIcon)
    private var showMenuBarIcon: Bool
    @AppStorage(.hideToolFeedback)
    private var hideToolFeedback: Bool
    @AppStorage(.toolbarVisible)
    private var toolbarVisible: Bool
    @AppStorage(.toolbarShowsShortcuts)
    private var toolbarShowsShortcuts: Bool
    @AppStorage(.toolbarLayout)
    private var toolbarLayout: ToolbarLayout
    @AppStorage(.overlayScope)
    private var overlayScope: OverlayScope
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
    @AppStorage(.usesFixedLineWidth)
    private var usesFixedLineWidth: Bool
    @AppStorage(.fixedLineWidth)
    private var fixedLineWidth: Double
    @AppStorage(.usesFixedColor)
    private var usesFixedColor: Bool
    @State private var fixedColor = Color(SettingsStore.standard[.fixedColor])
    // ponytail: the system owns login-item state, so read SMAppService instead of a setting key.
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    /// Tools offered in the Default Tool picker, excluding Select and Eraser since neither
    /// is a sensible tool to land on when the overlay opens.
    private static let selectableDefaultTools = ToolType.allCases.filter {
        $0 != .select && $0 != .eraser
    }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $launchAtLogin) {
                    Text("Launch at Login")
                    Text("Open Annotate automatically when you log in")
                }
                .onChange(of: launchAtLogin) { _, enabled in
                    launchAtLogin = Self.setLaunchAtLogin(enabled)
                }

                Toggle(
                    isOn: Binding(
                        get: { !hideDockIcon },
                        set: { hideDockIcon = !$0 }
                    )
                ) {
                    Text("Show Dock Icon")
                    Text("Show Annotate's icon in the Dock after launch and while it runs. When off, Annotate stays out of the Dock and the app switcher")
                }
                .onChange(of: hideDockIcon) { _, _ in
                    AppDelegate.shared?.updateDockIconVisibility()
                }

                Toggle(isOn: $showMenuBarIcon) {
                    Text("Show Menu Bar Icon")
                    Text("Show Annotate's icon in the menu bar after launch and while it runs. With both icons off, open Annotate again to show Settings")
                }
                .onChange(of: showMenuBarIcon) { _, _ in
                    AppDelegate.shared?.updateMenuBarIconVisibility()
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

                Toggle(isOn: $urlCommandsEnabled) {
                    Text("Allow URL commands")
                    Text("Run \(AnnotateCommand.urlScheme):// links from other apps, scripts, and the browser")
                }
            } header: {
                Text("Application")
            }

            Section {
                Picker(selection: $overlayScope) {
                    ForEach(OverlayScope.allCases, id: \.self) { scope in
                        Label(scope.displayName, systemImage: scope == .allScreens ? "display.2" : "display")
                            .tag(scope)
                    }
                } label: {
                    Text("Annotate On")
                    Text("Open the overlay on the screen under the pointer, or on every screen")
                }

                Picker(selection: $defaultToolOption) {
                    Label("Last Used", systemImage: "clock.arrow.circlepath").tag(DefaultToolOption.lastUsed)
                    ForEach(Self.selectableDefaultTools, id: \.self) { tool in
                        Label(tool.displayName, systemImage: tool.symbolName).tag(DefaultToolOption.tool(tool))
                    }
                } label: {
                    Text("Default Tool")
                    Text("Tool selected each time the overlay is activated")
                }

                Toggle(isOn: $usesFixedLineWidth) {
                    Text("Fixed Line Width")
                    Text("Reset to this width each time the overlay is activated, instead of the last one used")
                }

                if usesFixedLineWidth {
                    SettingsSliderRow(
                        title: L10n.string("Line Width"),
                        value: $fixedLineWidth,
                        range: Double(lineWidthRange.lowerBound)...Double(lineWidthRange.upperBound),
                        step: 0.5,
                        valueText: { L10n.string("\($0, format: .number.precision(.fractionLength(1))) px") },
                        boundsText: { L10n.string("\($0, format: .number.precision(.fractionLength(0...1))) px") }
                    )
                }

                Toggle(isOn: $usesFixedColor) {
                    Text("Fixed Color")
                    Text("Reset to this color each time the overlay is activated, instead of the last one used")
                }

                if usesFixedColor {
                    ColorPicker(selection: $fixedColor, supportsOpacity: false) {
                        Text("Color")
                    }
                    .onChange(of: fixedColor) { _, color in
                        SettingsStore.standard[.fixedColor] = NSColor(color)
                    }
                }

                if usesFixedLineWidth || usesFixedColor {
                    SettingsPreviewTile(
                        image: SettingsPreview.stroke(
                            lineWidth: usesFixedLineWidth ? fixedLineWidth : 3,
                            color: usesFixedColor ? NSColor(fixedColor) : SettingsPreview.color,
                            size: NSSize(width: 320, height: 40)))
                }

                Toggle(isOn: $clearDrawingsOnStart) {
                    Text("Clear Drawings on Toggle")
                    Text("Clear all drawings when toggling overlay off")
                }

                Toggle(isOn: $selectAfterPlacingText) {
                    Text("Switch to Select after placing text")
                    Text("After committing a label, select it so you can move it right away")
                }

                Toggle(isOn: $hideToolFeedback) {
                    Text("Hide Tool Feedback")
                    Text("Disable visual feedback when switching tools")
                }
            } header: {
                Text("Overlay")
            }

            Section {
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
                        Label(
                            layout.displayName,
                            systemImage: layout == .vertical
                                ? "rectangle.leftthird.inset.filled" : "rectangle.bottomthird.inset.filled"
                        )
                        .tag(layout)
                    }
                } label: {
                    Text("Toolbar Layout")
                    Text("Run the toolbar along the bottom or down the left edge")
                }
                .disabled(!toolbarVisible)
                .onChange(of: toolbarLayout) { _, _ in
                    AppDelegate.shared?.applyToolbarAppearance()
                }
            } header: {
                Text("Toolbar")
            }

            Section {
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
            } header: {
                Text("Sound")
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
                Text("Fade Mode")
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
        .onAppear { launchAtLogin = SMAppService.mainApp.status == .enabled }
    }

    /// Registers or unregisters the app as a login item and returns the resulting state.
    private static func setLaunchAtLogin(_ enabled: Bool) -> Bool {
        let service = SMAppService.mainApp
        guard enabled != (service.status == .enabled) else { return enabled }
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            Logger(subsystem: "com.sunimp.Annotate", category: "LaunchAtLogin")
                .error("Launch at login change failed: \(error.localizedDescription, privacy: .public)")
        }
        return service.status == .enabled
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

struct GlobalShortcutRecorder: View {
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
