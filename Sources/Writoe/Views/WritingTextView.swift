import SwiftUI
import AppKit

struct WritingTextView: NSViewRepresentable {
    @Binding var text: String
    var sceneID: UUID?
    var fontName: String = "Georgia"
    var fontSize: CGFloat = 16
    var isRTL: Bool = false
    var spellCheckLanguage: String = "en"
    var theme: WritingTheme = .system
    var horizontalPadding: CGFloat = 60
    var verticalPadding: CGFloat = 24
    var onTextChange: (String) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let tv = scrollView.documentView as? NSTextView else { return scrollView }

        tv.delegate = context.coordinator
        context.coordinator.textView = tv

        tv.usesFindBar = true
        tv.isIncrementalSearchingEnabled = true
        tv.isEditable = true
        tv.isSelectable = true
        tv.isRichText = false
        tv.drawsBackground = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        tv.textContainerInset = NSSize(width: horizontalPadding, height: verticalPadding)
        tv.isAutomaticQuoteSubstitutionEnabled = true
        tv.isAutomaticDashSubstitutionEnabled = true
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isContinuousSpellCheckingEnabled = true

        applyStyle(to: tv, scrollView: scrollView)
        tv.string = text

        context.coordinator.lastSceneID         = sceneID
        context.coordinator.lastFontName        = fontName
        context.coordinator.lastFontSize        = fontSize
        context.coordinator.lastIsRTL           = isRTL
        context.coordinator.lastTheme           = theme

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tv = scrollView.documentView as? NSTextView else { return }
        let c = context.coordinator

        let sceneChanged = c.lastSceneID  != sceneID
        let styleChanged = c.lastFontName != fontName
                        || c.lastFontSize != fontSize
                        || c.lastIsRTL    != isRTL
                        || c.lastTheme    != theme

        if sceneChanged {
            c.lastSceneID = sceneID
            tv.string = text
            applyStyle(to: tv, scrollView: scrollView)
            applyStyleToStorage(tv)
        } else if styleChanged {
            c.lastFontName = fontName
            c.lastFontSize = fontSize
            c.lastIsRTL    = isRTL
            c.lastTheme    = theme
            applyStyle(to: tv, scrollView: scrollView)
            applyStyleToStorage(tv)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onTextChange: onTextChange) }

    // MARK: - Style helpers

    private func resolvedFont() -> NSFont {
        NSFont(name: fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
    }

    private func resolvedParagraphStyle() -> NSParagraphStyle {
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = fontSize * 0.4
        ps.baseWritingDirection = isRTL ? .rightToLeft : .leftToRight
        ps.alignment = isRTL ? .right : .natural
        return ps
    }

    private func applyStyle(to tv: NSTextView, scrollView: NSScrollView) {
        let ps = resolvedParagraphStyle()
        tv.defaultParagraphStyle = ps
        tv.typingAttributes = [
            .font:            resolvedFont(),
            .paragraphStyle:  ps,
            .foregroundColor: theme.textColor
        ]
        tv.baseWritingDirection = isRTL ? .rightToLeft : .leftToRight
        tv.insertionPointColor  = theme.cursorColor
        tv.selectedTextAttributes = [
            .backgroundColor: theme.selectionColor
        ]

        // Background
        if theme.usesCustomBackground {
            tv.drawsBackground     = true
            scrollView.drawsBackground = true
            tv.backgroundColor     = theme.backgroundColor
            scrollView.backgroundColor = theme.backgroundColor
        } else {
            tv.drawsBackground     = false
            scrollView.drawsBackground = false
        }

        // Force the right AppKit appearance so selection/caret render correctly
        tv.appearance         = theme.nsAppearance
        scrollView.appearance = theme.nsAppearance
    }

    private func applyStyleToStorage(_ tv: NSTextView) {
        guard let ts = tv.textStorage, ts.length > 0 else { return }
        let full = NSRange(location: 0, length: ts.length)
        ts.beginEditing()
        ts.addAttributes([
            .font:            resolvedFont(),
            .paragraphStyle:  resolvedParagraphStyle(),
            .foregroundColor: theme.textColor
        ], range: full)
        ts.endEditing()
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        let onTextChange: (String) -> Void
        var lastSceneID:  UUID?
        var lastFontName: String       = ""
        var lastFontSize: CGFloat      = 0
        var lastIsRTL:    Bool         = false
        var lastTheme:    WritingTheme = .system
        weak var textView: NSTextView?

        init(onTextChange: @escaping (String) -> Void) {
            self.onTextChange = onTextChange
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            onTextChange(tv.string)
        }
    }
}
