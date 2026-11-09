//
//  OverlayWindow+EditCommands.swift
//  Annotate
//
//  Created by Sun on 2026/11/9.
//

import Cocoa

extension OverlayWindow {
    // MARK: - Keyboard Commands for Copy/Paste/Cut/Duplicate
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard let chord = KeyChord(event: event) else {
            return super.performKeyEquivalent(with: event)
        }
        if let regionPicker {
            return regionPicker.handleKey(chord)
        }
        if handleQuickPickerKeyDown(chord) || handleOverlayShortcut(chord) { return true }

        // Selection commands accept any extra modifiers. Command-B accepts only Shift.
        let selectionCommand = ["a", "c", "x", "v", "d"].first {
            ShortcutBinding($0, modifiers: .command).matches(chord, ignoring: [.shift, .option, .control])
        }
        let isTextBackgroundCommand = ShortcutBinding("b", modifiers: .command).matches(chord, ignoring: .shift)

        switch selectionCommand ?? (isTextBackgroundCommand ? "b" : nil) {
        case "a":
            // Defer to text field when editing text
            if overlayView.activeTextField != nil {
                return super.performKeyEquivalent(with: event)
            }

            let hasAnnotations = !overlayView.arrows.isEmpty || !overlayView.lines.isEmpty ||
                                !overlayView.paths.isEmpty || !overlayView.highlightPaths.isEmpty ||
                                !overlayView.rectangles.isEmpty || !overlayView.circles.isEmpty ||
                                !overlayView.textAnnotations.isEmpty || !overlayView.counterAnnotations.isEmpty

            if hasAnnotations {
                if overlayView.currentTool != .select {
                    AppDelegate.shared?.enableSelectMode(NSMenuItem())
                }
                overlayView.selectAllObjects()
            }

            return true

        case "c":
            guard overlayView.currentTool == .select else {
                return super.performKeyEquivalent(with: event)
            }
            overlayView.copySelectedObjects()
            return true

        case "x":
            guard overlayView.currentTool == .select else {
                return super.performKeyEquivalent(with: event)
            }
            overlayView.cutSelectedObjects()
            return true

        case "v":
            guard overlayView.currentTool == .select else {
                return super.performKeyEquivalent(with: event)
            }
            overlayView.pasteObjects()
            return true

        case "d":
            guard overlayView.currentTool == .select else {
                return super.performKeyEquivalent(with: event)
            }
            overlayView.duplicateSelectedObjects()
            return true

        case "b":
            // Command-B toggles the label background whenever the text tool is in play,
            // with or without an active field. Bare "b" stays Toggle Board; that path runs
            // in keyDown and only fires when no modifier is held.
            guard overlayView.currentTool == .text || overlayView.activeTextField != nil else {
                return super.performKeyEquivalent(with: event)
            }
            toggleTextBackground()
            return true


        default:
            return super.performKeyEquivalent(with: event)
        }
    }
}
