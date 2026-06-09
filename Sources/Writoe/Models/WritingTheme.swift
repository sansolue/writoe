import AppKit
import SwiftUI

enum WritingTheme: String, CaseIterable, Codable {
    case system       = "system"
    case sepia        = "sepia"
    case dark         = "dark"
    case midnight     = "midnight"
    case highContrast = "highContrast"

    var displayName: String {
        switch self {
        case .system:       "System"
        case .sepia:        "Sepia"
        case .dark:         "Dark"
        case .midnight:     "Midnight"
        case .highContrast: "Contrast"
        }
    }

    // MARK: - NSColors (used in NSTextView)

    var backgroundColor: NSColor {
        switch self {
        case .system:       .textBackgroundColor
        case .sepia:        NSColor(r: 248, g: 241, b: 226)
        case .dark:         NSColor(r:  28, g:  28, b:  30)
        case .midnight:     NSColor(r:  13, g:  27, b:  42)
        case .highContrast: .black
        }
    }

    var textColor: NSColor {
        switch self {
        case .system:       .labelColor
        case .sepia:        NSColor(r:  58, g:  39, b:  16)
        case .dark:         NSColor(r: 220, g: 220, b: 222)
        case .midnight:     NSColor(r: 200, g: 216, b: 232)
        case .highContrast: .white
        }
    }

    var cursorColor: NSColor {
        switch self {
        case .system:       .controlAccentColor
        case .sepia:        NSColor(r: 139, g:  94, b:  60)
        case .dark:         NSColor(r: 170, g: 170, b: 172)
        case .midnight:     NSColor(r: 100, g: 160, b: 210)
        case .highContrast: .white
        }
    }

    var selectionColor: NSColor {
        switch self {
        case .system:       .selectedTextBackgroundColor
        case .sepia:        NSColor(r: 200, g: 170, b: 110, a: 0.5)
        case .dark:         NSColor(r:  60, g: 100, b: 180, a: 0.5)
        case .midnight:     NSColor(r:  40, g:  90, b: 160, a: 0.5)
        case .highContrast: NSColor(r:  80, g:  80, b: 255, a: 0.8)
        }
    }

    // MARK: - SwiftUI Colors (used for container backgrounds)

    var swiftUIBackground: Color { Color(nsColor: backgroundColor) }

    // MARK: - Appearance

    var usesCustomBackground: Bool { self != .system }

    /// The NSAppearance to force on the text view so AppKit draws
    /// correctly (e.g. correct caret, selection tints).
    var nsAppearance: NSAppearance? {
        switch self {
        case .system:   return nil   // inherit from window
        case .sepia:    return NSAppearance(named: .aqua)
        case .dark, .midnight, .highContrast:
            return NSAppearance(named: .darkAqua)
        }
    }
}

// MARK: - NSColor convenience

private extension NSColor {
    convenience init(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat = 1) {
        self.init(red: r / 255, green: g / 255, blue: b / 255, alpha: a)
    }
}
