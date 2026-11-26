import SwiftUI
import XCTest

@testable import Annotate

@MainActor
final class SettingsViewTests: XCTestCase {
    var testDefaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()
        SettingsStore.standard.removeValue(for: .clearDrawingsOnStart)
        SettingsStore.standard.removeValue(for: .hideDockIcon)
        testDefaults = SettingsStore.standard.defaults
        SettingsStore.standard.removeValue(for: .textBackground)
        SettingsStore.standard.removeValue(for: .textFontSize)
    }

    override func tearDown() async throws {
        SettingsStore.standard.removeValue(for: .clearDrawingsOnStart)
        SettingsStore.standard.removeValue(for: .hideDockIcon)
        SettingsStore.standard.removeValue(for: .textBackground)
        SettingsStore.standard.removeValue(for: .textFontSize)
        try await super.tearDown()
    }

    func testSettingsViewInitialState() {
        XCTAssertFalse(testDefaults.settings[.clearDrawingsOnStart])
        XCTAssertTrue(testDefaults.settings[.hideDockIcon])
    }

    // MARK: - View Structure Tests

    func testSettingsPaneHasSixCases() {
        XCTAssertEqual(SettingsPane.allCases.count, 6)
        XCTAssertEqual(
            SettingsPane.allCases,
            [.general, .tools, .board, .cursor, .capture, .shortcuts]
        )
    }

    func testSettingsPaneCasesCarrySidebarMetadata() {
        for pane in SettingsPane.allCases {
            XCTAssertFalse(pane.title.isEmpty)
            XCTAssertFalse(pane.searchTerms.isEmpty)
            XCTAssertNotNil(NSImage(systemSymbolName: pane.symbol, accessibilityDescription: nil), pane.symbol)
        }
    }

    func testSearchMatchesPaneTitlesAndRowTitles() {
        XCTAssertEqual(SettingsPane.allCases.filter { $0.matches("") }, SettingsPane.allCases)
        XCTAssertEqual(SettingsPane.allCases.filter { $0.matches("  ") }, SettingsPane.allCases)
        XCTAssertEqual(SettingsPane.allCases.filter { $0.matches("board") }, [.board])
        XCTAssertEqual(SettingsPane.allCases.filter { $0.matches("spotlight") }, [.cursor])
        XCTAssertEqual(SettingsPane.allCases.filter { $0.matches("LAUNCH") }, [.general])
        XCTAssertEqual(SettingsPane.allCases.filter { $0.matches("activation") }, [.shortcuts])
        XCTAssertFalse(SettingsPane.allCases.contains { $0.matches("zzz") })
        for pane in SettingsPane.allCases {
            for term in pane.searchTerms {
                XCTAssertTrue(pane.matches(term), "\(pane) must match its own term \(term)")
            }
        }
    }

    func testSettingsViewBodyBuilds() {
        XCTAssertNotNil(SettingsView().body)
    }

    func testSettingsViewCanBeEmbeddedInHostingController() {
        XCTAssertNotNil(NSHostingController(rootView: SettingsView()).view)
    }

    func testCaptureSettingsViewCanBeEmbeddedInHostingController() {
        let hostingController = NSHostingController(rootView: CaptureSettingsView())
        XCTAssertNotNil(hostingController.view)
    }

    func testToolsSettingsViewCanBeEmbeddedInHostingController() {
        let hostingController = NSHostingController(rootView: ToolsSettingsView())
        XCTAssertNotNil(hostingController.view)
    }

    func testBoardSettingsViewCanBeEmbeddedInHostingController() {
        let hostingController = NSHostingController(rootView: BoardSettingsView())
        XCTAssertNotNil(hostingController.view)
    }

    func testCursorSettingsViewCanBeEmbeddedInHostingController() {
        let hostingController = NSHostingController(rootView: CursorSettingsView())
        XCTAssertNotNil(hostingController.view)
    }

    // MARK: - Settings Window Manager Tests

    func testShowCreatesConfiguredSettingsWindow() {
        SettingsWindowManager.shared.show()

        let window = SettingsWindowManager.shared.settingsWindow
        XCTAssertNotNil(window, "show() must create the settings window")
        XCTAssertEqual(window?.toolbarStyle, .unified)
        XCTAssertEqual(window?.styleMask.contains(.fullSizeContentView), true)
        XCTAssertEqual(SettingsWindowManager.shared.navigation.selection, .general)
        XCTAssertEqual(window?.title, "General", "The window is titled with the shown pane")

        SettingsWindowManager.shared.show(pane: .cursor)
        let cursorDeadline = Date().addingTimeInterval(5)
        while window?.title != "Cursor" && Date() < cursorDeadline { wait(for: 0.05) }
        XCTAssertEqual(window?.title, "Cursor")

        window?.close()
        XCTAssertNil(
            SettingsWindowManager.shared.settingsWindow,
            "closing the window must clear the manager's reference"
        )
    }

    func testShowReusesExistingSettingsWindow() {
        SettingsWindowManager.shared.show()
        let firstWindow = SettingsWindowManager.shared.settingsWindow

        SettingsWindowManager.shared.show()
        let secondWindow = SettingsWindowManager.shared.settingsWindow

        XCTAssertNotNil(firstWindow)
        XCTAssertTrue(
            firstWindow === secondWindow,
            "a second show() must re-front the existing window, not build a new one"
        )

        firstWindow?.close()
    }

    func testCloseHandlersRunOnceWhenTheWindowCloses() throws {
        var firstClosed = 0
        var secondClosed = 0
        SettingsWindowManager.shared.show(pane: .capture) { firstClosed += 1 }
        // A handler added while the window is already open waits for that window too.
        SettingsWindowManager.shared.show { secondClosed += 1 }
        let window = try XCTUnwrap(SettingsWindowManager.shared.settingsWindow)
        XCTAssertEqual(SettingsWindowManager.shared.navigation.selection, .capture)
        XCTAssertEqual(firstClosed, 0)
        XCTAssertEqual(secondClosed, 0)

        window.close()
        XCTAssertEqual(firstClosed, 1)
        XCTAssertEqual(secondClosed, 1)

        SettingsWindowManager.shared.show()
        XCTAssertEqual(SettingsWindowManager.shared.navigation.selection, .general, "A new window starts on General")
        SettingsWindowManager.shared.settingsWindow?.close()
        XCTAssertEqual(firstClosed, 1, "Each handler runs once")
        XCTAssertEqual(secondClosed, 1, "Each handler runs once")
    }

    // MARK: - Dock Icon Tests

    func testHideDockIconToggle() {
        SettingsStore.standard[.hideDockIcon] = false

        class ViewModel: ObservableObject {
            @AppStorage(.hideDockIcon) var hideDockIcon: Bool
        }

        let viewModel = ViewModel()

        XCTAssertFalse(viewModel.hideDockIcon)

        viewModel.hideDockIcon = true

        // Verify the toggle updated the UserDefaults
        XCTAssertTrue(SettingsStore.standard[.hideDockIcon])

        // Toggle back
        viewModel.hideDockIcon = false

        // Verify the toggle updated the UserDefaults
        XCTAssertFalse(SettingsStore.standard[.hideDockIcon])
    }

    func testToggleCallsUpdateDockIconVisibility() {
        let appDelegateSpy = AppDelegateSpy(userDefaults: testDefaults)
        AppDelegate.shared = appDelegateSpy

        class ViewModel: ObservableObject {
            @AppStorage(.hideDockIcon) var hideDockIcon: Bool

            @MainActor
            func toggleHideDockIcon() {
                hideDockIcon.toggle()
                AppDelegate.shared?.updateDockIconVisibility()
            }
        }

        let viewModel = ViewModel()

        viewModel.toggleHideDockIcon()

        XCTAssertTrue(appDelegateSpy.updateDockIconVisibilityCalled)

        AppDelegate.shared = nil
    }

    func testTextToolDefaultsKeepSizeAtEighteenAndPersistBackgroundChoice() {
        XCTAssertEqual(testDefaults.settings[.textFontSize], 18)
        XCTAssertFalse(testDefaults.settings[.textBackground])

        testDefaults.settings[.textBackground] = true
        XCTAssertTrue(testDefaults.settings[.textBackground])
    }
}

@MainActor
class AppDelegateSpy: AppDelegate {
    var updateDockIconVisibilityCalled = false

    override func updateDockIconVisibility() {
        updateDockIconVisibilityCalled = true
    }
}
