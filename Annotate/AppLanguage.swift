//
//  AppLanguage.swift
//  Annotate
//
//  Created by Sun on 2026/11/9.
//

import AppKit
import SwiftUI

/// The language Annotate shows, picked in General settings. `.system` follows macOS. The raw
/// value is the stored setting and, except for `.system`, the `.lproj` name, so renaming a case
/// resets the choice for every user.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case spanish = "es"
    case french = "fr"

    var id: String { rawValue }

    /// Each language names itself, so someone who can't read the current UI still finds theirs.
    var displayName: String {
        switch self {
        case .system: return L10n.string("System Default")
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .japanese: return "日本語"
        case .spanish: return "Español"
        case .french: return "Français"
        }
    }
}

/// Where UI text comes from. Swapping `language` switches every string read after it, with no
/// relaunch. AppKit text reads through `L10n.string`; SwiftUI `LocalizedStringKey` text follows
/// the `\.locale` that `localizedEnvironment()` sets.
enum L10n {
    /// Posted after `language` changes, so menus, windows, and the toolbar rebuild their text.
    static let didChange = Notification.Name("AnnotateLanguageDidChange")

    // ponytail: unsynchronized; only the main thread writes it, from settings and launch.
    // Wrap in a lock if a background thread ever switches language.
    nonisolated(unsafe) static var language: AppLanguage = .system {
        didSet {
            guard language != oldValue else { return }
            bundle = resolveBundle(for: language)
            NotificationCenter.default.post(name: didChange, object: nil)
        }
    }

    /// The `.lproj` bundle for `language`, or the app bundle when following macOS.
    nonisolated(unsafe) private(set) static var bundle: Bundle = .main

    /// The locale SwiftUI formats with. `.system` keeps the user's own locale.
    static var locale: Locale {
        language == .system ? .autoupdatingCurrent : Locale(identifier: language.rawValue)
    }

    static func string(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: bundle)
    }

    // ponytail: falls back to the app bundle when an .lproj is missing (SwiftPM builds ship
    // none), which shows the English keys.
    static func resolveBundle(for language: AppLanguage, in main: Bundle = .main) -> Bundle {
        guard language != .system,
            let path = main.path(forResource: language.rawValue, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else { return main }
        return bundle
    }
}

extension View {
    /// Points SwiftUI's own `LocalizedStringKey` lookup at the chosen language. Apply at the
    /// root of every hosting view.
    func localizedEnvironment() -> some View {
        modifier(LocalizedEnvironment())
    }
}

private struct LocalizedEnvironment: ViewModifier {
    @State private var locale = L10n.locale

    func body(content: Content) -> some View {
        content
            .environment(\.locale, locale)
            // A new identity rebuilds every `Text`, which resolves its key once per identity.
            .id(locale.identifier)
            .onReceive(NotificationCenter.default.publisher(for: L10n.didChange)) { _ in
                locale = L10n.locale
            }
    }
}
