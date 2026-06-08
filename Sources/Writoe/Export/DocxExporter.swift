import Foundation

struct DocxExporter {
    static func export(novel: Novel, options: ExportOptions) throws -> Data {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let wordDir     = tmp.appendingPathComponent("word")
        let relsDir     = tmp.appendingPathComponent("_rels")
        let wordRelsDir = wordDir.appendingPathComponent("_rels")
        for dir in [wordDir, relsDir, wordRelsDir] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        try contentTypesXML.write(to: tmp.appendingPathComponent("[Content_Types].xml"),    atomically: true, encoding: .utf8)
        try packageRelsXML .write(to: relsDir.appendingPathComponent(".rels"),               atomically: true, encoding: .utf8)
        try documentRelsXML.write(to: wordRelsDir.appendingPathComponent("document.xml.rels"), atomically: true, encoding: .utf8)
        try stylesXML(options: options).write(to: wordDir.appendingPathComponent("styles.xml"), atomically: true, encoding: .utf8)
        try documentXML(novel: novel, options: options).write(to: wordDir.appendingPathComponent("document.xml"), atomically: true, encoding: .utf8)

        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).docx")
        defer { try? FileManager.default.removeItem(at: outURL) }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", "cd '\(tmp.path)' && zip -r '\(outURL.path)' ."]
        try proc.run(); proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { throw ExportError.zipFailed }

        return try Data(contentsOf: outURL)
    }

    // MARK: - XML

    private static var contentTypesXML: String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
          <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
        </Types>
        """
    }

    private static var packageRelsXML: String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """
    }

    private static var documentRelsXML: String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        </Relationships>
        """
    }

    private static func stylesXML(options: ExportOptions) -> String {
        let font = options.fontName
        let size = Int(options.fontSize * 2) // half-points
        let lineRule = Int(options.lineSpacing * 240) // twips
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:style w:type="paragraph" w:styleId="Normal">
            <w:name w:val="Normal"/>
            <w:rPr><w:rFonts w:ascii="\(font)" w:hAnsi="\(font)"/><w:sz w:val="\(size)"/></w:rPr>
            <w:pPr><w:spacing w:line="\(lineRule)" w:lineRule="auto"/></w:pPr>
          </w:style>
          <w:style w:type="paragraph" w:styleId="Title">
            <w:name w:val="Title"/>
            <w:rPr><w:rFonts w:ascii="\(font)" w:hAnsi="\(font)"/><w:sz w:val="52"/><w:b/></w:rPr>
            <w:pPr><w:jc w:val="center"/><w:spacing w:after="240"/></w:pPr>
          </w:style>
          <w:style w:type="paragraph" w:styleId="Subtitle">
            <w:name w:val="Subtitle"/>
            <w:rPr><w:rFonts w:ascii="\(font)" w:hAnsi="\(font)"/><w:sz w:val="28"/><w:i/></w:rPr>
            <w:pPr><w:jc w:val="center"/><w:spacing w:after="480"/></w:pPr>
          </w:style>
          <w:style w:type="paragraph" w:styleId="Heading1">
            <w:name w:val="heading 1"/>
            <w:rPr><w:rFonts w:ascii="\(font)" w:hAnsi="\(font)"/><w:sz w:val="32"/><w:b/></w:rPr>
            <w:pPr><w:pageBreakBefore/><w:spacing w:before="480" w:after="240"/></w:pPr>
          </w:style>
          <w:style w:type="paragraph" w:styleId="Heading2">
            <w:name w:val="heading 2"/>
            <w:rPr><w:rFonts w:ascii="\(font)" w:hAnsi="\(font)"/><w:sz w:val="26"/><w:b/></w:rPr>
            <w:pPr><w:spacing w:before="240" w:after="120"/></w:pPr>
          </w:style>
        </w:styles>
        """
    }

    private static func documentXML(novel: Novel, options: ExportOptions) -> String {
        var body = wpara(novel.title, style: "Title")
        if !novel.author.isEmpty { body += wpara("by \(novel.author)", style: "Subtitle") }

        for (i, chapter) in novel.chapters.enumerated() {
            let heading = chapterHeading(chapter, index: i, options: options)
            body += wpara(heading, style: "Heading1")

            for (si, scene) in chapter.scenes.enumerated() {
                if options.includeSceneTitles && chapter.scenes.count > 1 {
                    body += wpara(scene.title, style: "Heading2")
                }
                // Split into paragraphs
                let paragraphs = scene.content
                    .components(separatedBy: "\n\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                for line in paragraphs {
                    body += wpara(line)
                }
                if si < chapter.scenes.count - 1, !options.sceneSeparator.isEmpty {
                    body += wpara(options.sceneSeparator, centered: true)
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

    private static func wpara(_ text: String, style: String? = nil, centered: Bool = false) -> String {
        var pPr = ""
        if let style { pPr += "<w:pStyle w:val=\"\(style)\"/>" }
        if centered  { pPr += "<w:jc w:val=\"center\"/>" }
        let pPrXML = pPr.isEmpty ? "" : "<w:pPr>\(pPr)</w:pPr>"

        let escaped = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        // Preserve single newlines within a paragraph as line breaks
        let withBreaks = escaped.components(separatedBy: "\n").enumerated().map { i, part in
            i == 0 ? "<w:r><w:t xml:space=\"preserve\">\(part)</w:t></w:r>"
                   : "<w:r><w:br/><w:t xml:space=\"preserve\">\(part)</w:t></w:r>"
        }.joined()

        return "<w:p>\(pPrXML)\(withBreaks)</w:p>"
    }

    private static func chapterHeading(_ chapter: Chapter, index: Int, options: ExportOptions) -> String {
        let num = options.includeChapterNumbers ? "Chapter \(index + 1)" : nil
        let title = chapter.title.trimmingCharacters(in: .whitespaces)
        switch (num, title.isEmpty) {
        case (let n?, false): return "\(n): \(title)"
        case (let n?, true):  return n
        case (nil, false):    return title
        case (nil, true):     return "Chapter \(index + 1)"
        }
    }
}
