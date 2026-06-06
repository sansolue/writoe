import Foundation
import AppKit

struct ExportService {

    // MARK: - Plain Text

    static func textContent(for novel: Novel) -> String {
        var out = "\(novel.title)\n"
        if !novel.author.isEmpty { out += "by \(novel.author)\n" }
        out += "\n\n"
        for chapter in novel.chapters {
            out += "\(chapter.title.uppercased())\n\n"
            for scene in chapter.scenes {
                if chapter.scenes.count > 1 { out += "\(scene.title)\n\n" }
                out += scene.content.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n"
            }
        }
        return out
    }

    // MARK: - DOCX (minimal OOXML via zip)

    static func docxData(for novel: Novel) throws -> Data {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let wordDir = tmp.appendingPathComponent("word")
        let relsDir = tmp.appendingPathComponent("_rels")
        let wordRelsDir = wordDir.appendingPathComponent("_rels")
        for dir in [wordDir, relsDir, wordRelsDir] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        try contentTypesXML.write(to: tmp.appendingPathComponent("[Content_Types].xml"), atomically: true, encoding: .utf8)
        try packageRelsXML.write(to: relsDir.appendingPathComponent(".rels"), atomically: true, encoding: .utf8)
        try documentRelsXML.write(to: wordRelsDir.appendingPathComponent("document.xml.rels"), atomically: true, encoding: .utf8)
        try documentXML(for: novel).write(to: wordDir.appendingPathComponent("document.xml"), atomically: true, encoding: .utf8)

        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).docx")
        defer { try? FileManager.default.removeItem(at: outURL) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "cd '\(tmp.path)' && zip -r '\(outURL.path)' ."]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw ExportError.zipFailed }

        return try Data(contentsOf: outURL)
    }

    // MARK: - Export Panel

    @MainActor
    static func showExportPanel(for novel: Novel) {
        let panel = NSSavePanel()
        panel.title = "Export Novel"
        panel.nameFieldStringValue = novel.title
        panel.allowedContentTypes = [.writoe, .plainText, .init(filenameExtension: "docx")!]
        panel.accessoryView = NSHostingView(rootView: ExportFormatPicker())

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            if url.pathExtension.lowercased() == "docx" {
                let data = try docxData(for: novel)
                try data.write(to: url)
            } else {
                try textContent(for: novel).write(to: url, atomically: true, encoding: .utf8)
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    // MARK: - XML helpers

    private static var contentTypesXML: String { """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        </Types>
        """ }

    private static var packageRelsXML: String { """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """ }

    private static var documentRelsXML: String { """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>
        """ }

    private static func documentXML(for novel: Novel) -> String {
        var body = ""

        // Title
        body += para(novel.title, style: "Title")
        if !novel.author.isEmpty { body += para("by \(novel.author)", style: "Subtitle") }

        for chapter in novel.chapters {
            body += para(chapter.title, style: "Heading1")
            for scene in chapter.scenes {
                if chapter.scenes.count > 1 { body += para(scene.title, style: "Heading2") }
                for line in scene.content.components(separatedBy: "\n") {
                    body += para(line)
                }
            }
        }

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>\(body)<w:sectPr/></w:body>
        </w:document>
        """
    }

    private static func para(_ text: String, style: String? = nil) -> String {
        let pPr = style.map { "<w:pPr><w:pStyle w:val=\"\($0)\"/></w:pPr>" } ?? ""
        let escaped = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        let run = escaped.isEmpty ? "" : "<w:r><w:t xml:space=\"preserve\">\(escaped)</w:t></w:r>"
        return "<w:p>\(pPr)\(run)</w:p>"
    }

    enum ExportError: LocalizedError {
        case zipFailed
        var errorDescription: String? { "Failed to create the document archive." }
    }
}

import SwiftUI
private struct ExportFormatPicker: View {
    var body: some View {
        Text("Choose .txt for plain text or .docx for Word format")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(8)
    }
}
