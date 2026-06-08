import Foundation
import AppKit
import Observation

// MARK: - Format registry

enum ExportFormatType: String, CaseIterable, Identifiable {
    case plainText = "txt"
    case markdown  = "md"
    case docx      = "docx"
    case epub      = "epub"

    var id: String { rawValue }
    var fileExtension: String { rawValue }

    var displayName: String {
        switch self {
        case .plainText: "Plain Text"
        case .markdown:  "Markdown"
        case .docx:      "Word Document"
        case .epub:      "EPUB E-Book"
        }
    }

    var icon: String {
        switch self {
        case .plainText: "doc.plaintext"
        case .markdown:  "text.badge.star"
        case .docx:      "doc.richtext"
        case .epub:      "books.vertical"
        }
    }

    var blurb: String {
        switch self {
        case .plainText: "Plain text. Works in any editor or word processor."
        case .markdown:  "Lightweight markup. Great for Obsidian, Ghost, Notion."
        case .docx:      "Microsoft Word format. Editable in Word, Pages, LibreOffice."
        case .epub:      "Standard e-book format. Works on Kindle, Apple Books, Kobo."
        }
    }

    var hasTypographyOptions: Bool { self == .docx }
    var hasEPUBOptions: Bool      { self == .epub  }
}

// MARK: - Shared options (all formats draw from this)

@Observable
final class ExportOptions {
    // Common
    var includeChapterNumbers: Bool = true
    var includeSceneTitles: Bool    = false
    var sceneSeparator: String      = "* * *"

    // Typography (DOCX)
    var fontName: String  = "Georgia"
    var fontSize: Double  = 12
    var lineSpacing: Double = 1.5

    // EPUB
    var coverImageData: Data?
    var coverImageURL: URL?
    var language: String  = "en"
    var publisher: String = ""
    var rights: String    = ""
    var isbn: String      = ""

    var hasCoverImage: Bool { coverImageData != nil }

    func clearCover() {
        coverImageData = nil
        coverImageURL  = nil
    }

    /// Detect cover image MIME type and file extension from raw data bytes.
    func coverImageInfo() -> (mime: String, ext: String) {
        guard let data = coverImageData else { return ("image/jpeg", "jpg") }
        if data.prefix(3).elementsEqual([0xFF, 0xD8, 0xFF]) { return ("image/jpeg", "jpg") }
        if data.prefix(8).elementsEqual([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) { return ("image/png", "png") }
        return ("image/jpeg", "jpg")
    }
}

// MARK: - Errors

enum ExportError: LocalizedError {
    case zipFailed
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .zipFailed:      "Failed to create the archive."
        case .encodingFailed: "Failed to encode document content."
        }
    }
}

// MARK: - Shared HTML helpers

extension String {
    var htmlEscaped: String {
        self
            .replacingOccurrences(of: "&",  with: "&amp;")
            .replacingOccurrences(of: "<",  with: "&lt;")
            .replacingOccurrences(of: ">",  with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
