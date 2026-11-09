import SwiftUI

struct ShortcutSettingActionResult {
    let shortcuts: [ShortcutKey: String]
    let restoreConflict: Bool
}

enum ShortcutSettingAction {
    case clear
    case restoreDefault

    @MainActor
    func perform(
        tool: ShortcutKey,
        manager: ShortcutManager? = nil
    ) -> ShortcutSettingActionResult {
        let manager = manager ?? .shared
        let restoreConflict: Bool
        switch self {
        case .clear:
            manager.clearShortcut(tool: tool)
            restoreConflict = false
        case .restoreDefault:
            restoreConflict = !manager.resetToDefault(tool: tool)
        }

        return ShortcutSettingActionResult(
            shortcuts: manager.allShortcuts,
            restoreConflict: restoreConflict
        )
    }
}

struct BuiltInShortcut: Identifiable {
    let keys: String
    let label: String
    let description: String
    var id: String { keys }
}

struct ShortcutsSettingsView: View {
    static let builtInShortcuts: [BuiltInShortcut] = [
        BuiltInShortcut(
            keys: "Delete",
            label: String(localized: "Delete"),
            description: String(localized: "Remove the selection, or the newest item drawn with the current tool")
        ),
        BuiltInShortcut(
            keys: "⌘Z",
            label: String(localized: "Undo"),
            description: String(localized: "Undo the last action")
        ),
        BuiltInShortcut(
            keys: "⇧⌘Z",
            label: String(localized: "Redo"),
            description: String(localized: "Redo the last undone action")
        ),
        BuiltInShortcut(
            keys: "Esc",
            label: String(localized: "Close Overlay"),
            description: String(localized: "Hide the overlay, or dismiss an open picker or label first")
        )
    ]

    @State private var shortcuts: [ShortcutKey: String] = ShortcutManager.shared.allShortcuts
    @State private var editingShortcut: ShortcutKey?
    @State private var showResetConfirmation = false

    var body: some View {
        Form {
            Section {
                PaneHeader(pane: .shortcuts)
            }

            Section {
                ShortcutSettingRow(
                    tool: .pen,
                    label: String(localized: "Pen"),
                    description: String(localized: "Draw freeform pen strokes"),
                    shortcuts: $shortcuts,
                    editingShortcut: $editingShortcut
                )
                ShortcutSettingRow(
                    tool: .arrow,
                    label: String(localized: "Arrow"),
                    description: String(localized: "Draw directional arrows"),
                    shortcuts: $shortcuts,
                    editingShortcut: $editingShortcut
                )
                ShortcutSettingRow(
                    tool: .line,
                    label: String(localized: "Line"),
                    description: String(localized: "Draw straight lines"),
                    shortcuts: $shortcuts,
                    editingShortcut: $editingShortcut
                )
                ShortcutSettingRow(
                    tool: .highlighter,
                    label: String(localized: "Highlighter"),
                    description: String(localized: "Highlight with transparency"),
                    shortcuts: $shortcuts,
                    editingShortcut: $editingShortcut
                )
            } header: {
                SettingsHeader(
                    icon: "pencil.tip",
                    color: .blue,
                    title: String(localized: "Drawing Tools"),
                    subtitle: String(localized: "Basic drawing and annotation shortcuts")
                )
            }

            Section {
                ShortcutSettingRow(
                    tool: .rectangle,
                    label: String(localized: "Rectangle"),
                    description: String(localized: "Draw rectangular shapes"),
                    shortcuts: $shortcuts,
                    editingShortcut: $editingShortcut
                )
                ShortcutSettingRow(
                    tool: .circle,
                    label: String(localized: "Circle"),
                    description: String(localized: "Draw circular shapes"),
                    shortcuts: $shortcuts,
                    editingShortcut: $editingShortcut
                )
                ShortcutSettingRow(
                    tool: .redact,
                    label: String(localized: "Redact"),
                    description: String(localized: "Hide on-screen content behind a rectangle"),
                    shortcuts: $shortcuts,
                    editingShortcut: $editingShortcut
                )
            } header: {
                SettingsHeader(
                    icon: "square.on.circle",
                    color: .green,
                    title: String(localized: "Shapes"),
                    subtitle: String(localized: "Geometric shape shortcuts")
                )
            }

            Section {
                ShortcutSettingRow(
                    tool: .counter,
                    label: String(localized: "Counter"),
                    description: String(localized: "Add numbered counters"),
                    shortcuts: $shortcuts,
                    editingShortcut: $editingShortcut
                )
                ShortcutSettingRow(
                    tool: .text,
                    label: String(localized: "Text"),
                    description: String(localized: "Add text annotations"),
                    shortcuts: $shortcuts,
                    editingShortcut: $editingShortcut
                )
                ShortcutSettingRow(
                    tool: .select,
                    label: String(localized: "Select"),
                    description: String(localized: "Select and edit annotations"),
                    shortcuts: $shortcuts,
                    editingShortcut: $editingShortcut
                )
                ShortcutSettingRow(
                    tool: .eraser,
                    label: String(localized: "Eraser"),
                    description: String(localized: "Remove annotations by dragging"),
                    shortcuts: $shortcuts,
                    editingShortcut: $editingShortcut
                )
            } header: {
                SettingsHeader(
                    icon: "wand.and.stars",
                    color: .purple,
                    title: String(localized: "Advanced Tools"),
                    subtitle: String(localized: "Additional annotation features")
                )
            }

            Section {
                ShortcutSettingRow(
                    tool: .colorPicker,
                    label: String(localized: "Color Picker"),
                    description: String(localized: "Choose annotation color"),
                    shortcuts: $shortcuts,
                    editingShortcut: $editingShortcut
                )
                ShortcutSettingRow(
                    tool: .lineWidthPicker,
                    label: String(localized: "Line Width"),
                    description: String(localized: "Adjust stroke width"),
                    shortcuts: $shortcuts,
                    editingShortcut: $editingShortcut
                )
                ShortcutSettingRow(
                    tool: .toggleBoard,
                    label: String(localized: "Toggle Board"),
                    description: String(localized: "Show or hide board background"),
                    shortcuts: $shortcuts,
                    editingShortcut: $editingShortcut
                )
                ShortcutSettingRow(
                    tool: .toggleClickEffects,
                    label: String(localized: "Toggle Cursor Highlight"),
                    description: String(localized: "Enable or disable cursor visual feedback"),
                    shortcuts: $shortcuts,
                    editingShortcut: $editingShortcut
                )
                ShortcutSettingRow(
                    tool: .toggleBackgroundDimming,
                    label: String(localized: "Toggle Background Dimming"),
                    description: String(localized: "Toggle dimming while annotating; enables the spotlight if needed"),
                    shortcuts: $shortcuts,
                    editingShortcut: $editingShortcut
                )
                ShortcutSettingRow(
                    tool: .toggleFade,
                    label: ShortcutKey.toggleFade.displayName,
                    description: String(localized: "Switch between fade and persist"),
                    shortcuts: $shortcuts,
                    editingShortcut: $editingShortcut
                )
                ShortcutSettingRow(
                    tool: .toggleToolbar,
                    label: ShortcutKey.toggleToolbar.displayName,
                    description: String(localized: "Show or hide the floating toolbar"),
                    shortcuts: $shortcuts,
                    editingShortcut: $editingShortcut
                )
                ShortcutSettingRow(
                    tool: .decreaseSize,
                    label: ShortcutKey.decreaseSize.displayName,
                    description: String(localized: "Step stroke width, text size, or counter size down"),
                    shortcuts: $shortcuts,
                    editingShortcut: $editingShortcut
                )
                ShortcutSettingRow(
                    tool: .increaseSize,
                    label: ShortcutKey.increaseSize.displayName,
                    description: String(localized: "Step stroke width, text size, or counter size up"),
                    shortcuts: $shortcuts,
                    editingShortcut: $editingShortcut
                )
                ShortcutSettingRow(
                    tool: .clearAll,
                    label: ShortcutKey.clearAll.displayName,
                    description: String(localized: "Remove every annotation"),
                    shortcuts: $shortcuts,
                    editingShortcut: $editingShortcut
                )
                ShortcutSettingRow(
                    tool: .captureScreen,
                    label: ShortcutKey.captureScreen.displayName,
                    description: String(localized: "Save the display with its annotations and copy it"),
                    shortcuts: $shortcuts,
                    editingShortcut: $editingShortcut
                )
                ShortcutSettingRow(
                    tool: .captureArea,
                    label: ShortcutKey.captureArea.displayName,
                    description: String(localized: "Drag out part of the display to save and copy"),
                    shortcuts: $shortcuts,
                    editingShortcut: $editingShortcut
                )
            } header: {
                SettingsHeader(
                    icon: "slider.horizontal.3",
                    color: .orange,
                    title: String(localized: "Utilities"),
                    subtitle: String(localized: "Pickers, sizes, and overlay controls")
                )
            }

            Section {
                ForEach(Self.builtInShortcuts) { shortcut in
                    BuiltInShortcutRow(shortcut: shortcut)
                }
            } header: {
                SettingsHeader(
                    icon: "lock",
                    color: .gray,
                    title: String(localized: "Built-in Shortcuts"),
                    subtitle: String(localized: "Fixed editing and dismissal keys")
                )
            }

            Section {
                HStack {
                    Spacer()
                    Button {
                        showResetConfirmation = true
                    } label: {
                        Label("Reset All to Default", systemImage: "arrow.counterclockwise")
                    }
                    .glassButtonStyle()
                }
            }
        }
        .formStyle(.grouped)
        .settingsScrollEdgeEffect()
        .onAppear {
            shortcuts = ShortcutManager.shared.allShortcuts
        }
        .alert("Reset All Shortcuts?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                ShortcutManager.shared.resetAllToDefault()
                shortcuts = ShortcutManager.shared.allShortcuts
                editingShortcut = nil
            }
        } message: {
            Text("This will reset tool and utility shortcuts to their defaults. Defaults used by Activation or Always-On stay Not Set. This action cannot be undone.")
        }
    }
}

struct ShortcutSettingRow: View {
    let tool: ShortcutKey
    let label: String
    let description: String
    @Binding var shortcuts: [ShortcutKey: String]
    @Binding var editingShortcut: ShortcutKey?

    @State private var isHoveringKey = false
    @State private var isHoveringClear = false
    @State private var isHoveringRestore = false
    @State private var showRestoreConflict = false

    private var shortcut: String { shortcuts[tool] ?? tool.defaultBinding.displayValue }

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                if editingShortcut == tool {
                    ShortcutField(
                        tool: tool,
                        shortcuts: $shortcuts,
                        editingShortcut: $editingShortcut
                    )
                    .frame(minWidth: 60)
                } else {
                    Button(action: { editingShortcut = tool }) {
                        Text(keycap: shortcut.isEmpty ? String(localized: "Not Set") : shortcut)
                            .font(.body.weight(.medium).monospaced())
                            .foregroundStyle(.primary)
                            .frame(minWidth: 32)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(ShortcutKeycapBackground())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Record \(label) shortcut")
                    .accessibilityValue(shortcut.isEmpty ? String(localized: "Not Set") : ShortcutBinding.spokenLabel(for: shortcut))
                    .accessibilityIdentifier("shortcut.\(tool.rawValue).record")
                    .opacity(isHoveringKey ? 0.8 : 1.0)
                    .onHover { isHoveringKey = $0 }
                }

                Button {
                    let result = ShortcutSettingAction.clear.perform(tool: tool)
                    shortcuts = result.shortcuts
                    editingShortcut = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(isHoveringClear ? .secondary : .tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear shortcut")
                .accessibilityLabel("Clear \(label) shortcut")
                .accessibilityIdentifier("shortcut.\(tool.rawValue).clear")
                .disabled(shortcut.isEmpty)
                .onHover { isHoveringClear = $0 }

                Button {
                    let result = ShortcutSettingAction.restoreDefault.perform(tool: tool)
                    shortcuts = result.shortcuts
                    editingShortcut = nil
                    showRestoreConflict = result.restoreConflict
                } label: {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.body)
                        .foregroundStyle(isHoveringRestore ? .secondary : .tertiary)
                }
                .buttonStyle(.plain)
                .help("Restore default")
                .accessibilityLabel("Restore \(label) default")
                .accessibilityIdentifier("shortcut.\(tool.rawValue).restore")
                .disabled(shortcut == tool.defaultBinding.displayValue)
                .onHover { isHoveringRestore = $0 }
                .alert("Default Shortcut Unavailable", isPresented: $showRestoreConflict) {
                    Button("OK") {}
                } message: {
                    Text(
                        "The default shortcut “\(ShortcutBinding.spokenLabel(for: tool.defaultBinding.displayValue))” is already assigned. Clear it from the other action first."
                    )
                }
            }
        } label: {
            Text(label)
            Text(description)
        }
        .accessibilityElement(children: .contain)
    }
}

/// The rounded, quaternary-filled keycap shape shared by shortcut key labels.
private struct ShortcutKeycapBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(.quaternary)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.separator, lineWidth: 1)
            )
    }
}

struct BuiltInShortcutRow: View {
    let shortcut: BuiltInShortcut

    var body: some View {
        LabeledContent {
            Text(shortcut.keys)
                .font(.body.weight(.medium).monospaced())
                .foregroundStyle(.secondary)
                .frame(minWidth: 32)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(ShortcutKeycapBackground())
        } label: {
            Text(shortcut.label)
            Text(shortcut.description)
        }
    }
}
