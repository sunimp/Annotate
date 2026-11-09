//
//  OverlayScope.swift
//  Annotate
//
//  Created by Sun on 2026/11/9.
//

import Foundation

/// Which displays the interactive overlay opens on.
enum OverlayScope: String, CaseIterable {
    /// Only the display under the pointer, as Annotate has always done.
    case pointerScreen
    /// Every display at once. The toolbar stays on the display under the pointer when the
    /// overlay opened; the others carry none.
    case allScreens

    var displayName: String {
        switch self {
        case .pointerScreen: return L10n.string("Screen Under Pointer")
        case .allScreens: return L10n.string("All Screens")
        }
    }
}
