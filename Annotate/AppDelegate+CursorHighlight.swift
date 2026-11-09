//
//  AppDelegate+CursorHighlight.swift
//  Annotate
//
//  Created by Sun on 2026/11/9.
//

import Cocoa

extension AppDelegate {
    // MARK: - Cursor Highlighting

    private func createCursorHighlightWindow(for screen: NSScreen) -> CursorHighlightWindow {
        let window = CursorHighlightWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.setFrameOrigin(screen.frame.origin)
        return window
    }

    func setupCursorHighlightWindows() {
        for screen in NSScreen.screens {
            let window = createCursorHighlightWindow(for: screen)
            cursorHighlightWindows[screen] = window
            window.updateVisibility()
        }
    }

    func setupGlobalMouseMonitors() {
        // Global monitors - receive events when app is NOT frontmost
        globalMouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        ) { [weak self] event in
            self?.handleGlobalMouseMove(event)
        }

        globalMouseClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            self?.handleGlobalMouseDown(event)
        }

        globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseUp, .rightMouseUp]
        ) { [weak self] event in
            self?.handleGlobalMouseUp(event)
        }

        // Local monitors - receive events when app IS frontmost (e.g., Settings window open)
        localMouseMoveMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        ) { [weak self] event in
            self?.handleGlobalMouseMove(event)
            return event
        }

        localMouseClickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            self?.handleGlobalMouseDown(event)
            return event
        }

        localMouseUpMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseUp, .rightMouseUp]
        ) { [weak self] event in
            self?.handleGlobalMouseUp(event)
            return event
        }

        // Modifier keys from hotkeys can trigger cursor resets
        localFlagsChangedMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.flagsChanged]
        ) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
    }

    func handleFlagsChanged(_ event: NSEvent) {
        CursorHighlightManager.shared.updateCursorVisibility()
    }

    func setupCursorHighlightObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cursorHighlightStateChanged),
            name: .cursorHighlightStateChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cursorHighlightNeedsUpdate),
            name: .cursorHighlightNeedsUpdate,
            object: nil
        )
    }

    @objc func cursorHighlightNeedsUpdate() {
        triggerCursorHighlightUpdate()
    }

    @objc func cursorHighlightStateChanged() {
        updateAllCursorHighlightWindows()
        CursorHighlightManager.shared.updateCursorVisibility()
        // Every overlay sets the one system cursor, whichever display it is on, so the last
        // one wins. An overlay with a cursor override, as Capture Area's picker sets, goes
        // last: otherwise another display's I-beam or hidden cursor would replace the crosshair.
        let windows = Array(overlayWindows.values)
        let overriding = windows.filter { $0.overlayView.cursorOverride != nil }
        for window in windows.filter({ $0.overlayView.cursorOverride == nil }) + overriding {
            window.overlayView.updateCursor()
            window.overlayView.window?.invalidateCursorRects(for: window.overlayView)
        }
    }

    /// Called from OverlayWindow to trigger cursor highlight updates for local mouse events
    func triggerCursorHighlightUpdate() {
        cursorHighlightWindows.values.forEach { $0.highlightView.updateHoldRingPosition() }

        if let currentScreen = getCurrentScreen(),
           let window = cursorHighlightWindows[currentScreen]
        {
            window.startAnimationLoop()
        }
    }

    func handleGlobalMouseMove(_ event: NSEvent) {
        let manager = CursorHighlightManager.shared
        manager.mouseEventReceived()
        manager.cursorPosition = NSEvent.mouseLocation
        manager.updateCursorVisibility()

        let shouldUpdateSpotlight = manager.shouldShowCursorHighlight
        let shouldUpdateHoldRing = manager.isActive && manager.isMouseDown

        guard shouldUpdateSpotlight || shouldUpdateHoldRing else { return }

        cursorHighlightWindows.values.forEach { window in
            if shouldUpdateSpotlight { window.highlightView.updateSpotlightPosition() }
            if shouldUpdateHoldRing { window.highlightView.updateHoldRingPosition() }
        }

        if let currentScreen = getCurrentScreen(),
           let window = cursorHighlightWindows[currentScreen]
        {
            window.startAnimationLoop()
        }
    }

    func handleGlobalMouseDown(_ event: NSEvent) {
        let manager = CursorHighlightManager.shared
        manager.mouseEventReceived()
        guard manager.isActive else { return }

        manager.isMouseDown = true
        manager.mouseDownTime = CACurrentMediaTime()
        manager.cursorPosition = NSEvent.mouseLocation

        if let currentScreen = getCurrentScreen(),
           let window = cursorHighlightWindows[currentScreen]
        {
            window.highlightView.updateHoldRingPosition()
            window.startAnimationLoop()
        }
    }

    func handleGlobalMouseUp(_ event: NSEvent) {
        let manager = CursorHighlightManager.shared
        manager.mouseEventReceived()

        guard manager.isActive else {
            manager.isMouseDown = false
            return
        }

        manager.startReleaseAnimation()
        manager.isMouseDown = false

        cursorHighlightWindows.values.forEach { $0.highlightView.updateHoldRingPosition() }

        if let currentScreen = getCurrentScreen(),
           let window = cursorHighlightWindows[currentScreen]
        {
            window.startAnimationLoop()
        }
    }

    func updateAllCursorHighlightWindows() {
        cursorHighlightWindows.values.forEach { $0.updateVisibility() }
    }

    func updateCursorHighlightWindowsForScreenChange() {
        // Remove windows for disconnected screens
        cursorHighlightWindows = cursorHighlightWindows.filter { screen, window in
            let exists = NSScreen.screens.contains(screen)
            if !exists {
                window.stopAnimationLoop()
                window.orderOut(nil)
            }
            return exists
        }

        // Add windows for newly connected screens
        for screen in NSScreen.screens where cursorHighlightWindows[screen] == nil {
            let window = createCursorHighlightWindow(for: screen)
            cursorHighlightWindows[screen] = window
            window.updateVisibility()
        }
    }
}
