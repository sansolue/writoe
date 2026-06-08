import Foundation

struct EPUBExporter {
    static func export(novel: Novel, options: ExportOptions) throws -> Data {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let metaInf  = tmp.appendingPathComponent("META-INF")
        let oebps    = tmp.appendingPathComponent("OEBPS")
        let chapDir  = oebps.appendingPathComponent("chapters")
        let stylesDir = oebps.appendingPathComponent("styles")
        let imagesDir = oebps.appendingPathComponent("images")

        for dir in [metaInf, chapDir, stylesDir, imagesDir] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        // mimetype — must be written as plain bytes (no BOM, no trailing newline)
        try Data("application/epub+zip".utf8)
            .write(to: tmp.appendingPathComponent("mimetype"))

        try containerXML.write(to: metaInf.appendingPathComponent("container.xml"), atomically: true, encoding: .utf8)
        try cssContent.write(to: stylesDir.appendingPathComponent("style.css"),    atomically: true, encoding: .utf8)

        // Cover image + page
        let coverInfo = options.coverImageInfo()
        let coverFilename = "cover.\(coverInfo.ext)"
        if let coverData = options.coverImageData {
            try coverData.write(to: imagesDir.appendingPathComponent(coverFilename))
            try coverPageXHTML(imageFile: coverFilename)
                .write(to: chapDir.appendingPathComponent("cover.xhtml"), atomically: true, encoding: .utf8)
        }

        // Chapter files
        for (i, chapter) in novel.chapters.enumerated() {
            let filename = String(format: "ch%03d.xhtml", i + 1)
            try chapterXHTML(chapter: chapter, index: i, novel: novel, options: options)
                .write(to: chapDir.appendingPathComponent(filename), atomically: true, encoding: .utf8)
        }

        // Navigation & package
        try navXHTML(novel: novel, options: options)
            .write(to: oebps.appendingPathComponent("nav.xhtml"), atomically: true, encoding: .utf8)
        try tocNCX(novel: novel, options: options)
            .write(to: oebps.appendingPathComponent("toc.ncx"),   atomically: true, encoding: .utf8)
        try contentOPF(novel: novel, options: options, coverInfo: coverInfo)
            .write(to: oebps.appendingPathComponent("content.opf"), atomically: true, encoding: .utf8)

        // Build EPUB zip — mimetype must be first entry and uncompressed
        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).epub")
        defer { try? FileManager.default.removeItem(at: outURL) }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", """
            cd '\(tmp.path)' && \
            zip -X -0 '\(outURL.path)' mimetype && \
            zip -rg '\(outURL.path)' META-INF OEBPS
            """]
        try proc.run(); proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { throw ExportError.zipFailed }

        return try Data(contentsOf: outURL)
    }

    // MARK: - container.xml

    private static let containerXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """

    // MARK: - CSS

    private static let cssContent = """
        body {
          font-family: Georgia, "Times New Roman", serif;
          font-size: 1em;
          line-height: 1.7;
          margin: 1em 2em;
        }
        h1 {
          font-size: 1.5em;
          text-align: center;
          margin: 3em 0 2em;
          page-break-before: always;
        }
        h2 {
          font-size: 1.15em;
          margin: 2em 0 0.5em;
        }
        p {
          text-indent: 1.5em;
          margin: 0 0 0.3em;
        }
        p.no-indent { text-indent: 0; }
        .scene-break { text-align: center; margin: 1.5em 0; }
        .cover-page { text-align: center; margin: 0; padding: 0; }
        .cover-page img { max-width: 100%; max-height: 100vh; }
        """

    // MARK: - Cover page

    private static func coverPageXHTML(imageFile: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
        <head><meta charset="UTF-8"/><title>Cover</title>
          <link rel="stylesheet" type="text/css" href="../styles/style.css"/>
        </head>
        <body>
          <div class="cover-page">
            <img src="../images/\(imageFile)" alt="Cover"/>
          </div>
        </body>
        </html>
        """
    }

    // MARK: - Chapter XHTML

    private static func chapterXHTML(chapter: Chapter, index: Int, novel: Novel, options: ExportOptions) -> String {
        let title = chapterHeading(chapter, index: index, options: options)
        var bodyContent = "<h1>\(title.htmlEscaped)</h1>\n"

        for (si, scene) in chapter.scenes.enumerated() {
            if options.includeSceneTitles && chapter.scenes.count > 1 {
                bodyContent += "<h2>\(scene.title.htmlEscaped)</h2>\n"
            }
            bodyContent += htmlParagraphs(from: scene.content, firstSceneInChapter: si == 0)
            if si < chapter.scenes.count - 1, !options.sceneSeparator.isEmpty {
                bodyContent += "<p class=\"scene-break\">\(options.sceneSeparator.htmlEscaped)</p>\n"
            }
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <head>
          <meta charset="UTF-8"/>
          <title>\(title.htmlEscaped)</title>
          <link rel="stylesheet" type="text/css" href="../styles/style.css"/>
        </head>
        <body>
        \(bodyContent)</body>
        </html>
        """
    }

    private static func htmlParagraphs(from content: String, firstSceneInChapter: Bool) -> String {
        let paragraphs = content
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return paragraphs.enumerated().map { i, para in
            let cls = (i == 0 && firstSceneInChapter) ? " class=\"no-indent\"" : ""
            let text = para
                .replacingOccurrences(of: "&",  with: "&amp;")
                .replacingOccurrences(of: "<",  with: "&lt;")
                .replacingOccurrences(of: ">",  with: "&gt;")
                .replacingOccurrences(of: "\n", with: "<br/>")
            return "<p\(cls)>\(text)</p>\n"
        }.joined()
    }

    // MARK: - nav.xhtml

    private static func navXHTML(novel: Novel, options: ExportOptions) -> String {
        let items = novel.chapters.enumerated().map { i, ch in
            let title = chapterHeading(ch, index: i, options: options)
            let file = String(format: "ch%03d.xhtml", i + 1)
            return "      <li><a href=\"chapters/\(file)\">\(title.htmlEscaped)</a></li>"
        }.joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
        <head><meta charset="UTF-8"/><title>Contents</title></head>
        <body>
          <nav epub:type="toc" id="toc">
            <h1>Contents</h1>
            <ol>
        \(items)
            </ol>
          </nav>
        </body>
        </html>
        """
    }

    // MARK: - toc.ncx (EPUB2 compatibility)

    private static func tocNCX(novel: Novel, options: ExportOptions) -> String {
        let points = novel.chapters.enumerated().map { i, ch in
            let title = chapterHeading(ch, index: i, options: options)
            let file = String(format: "ch%03d.xhtml", i + 1)
            return """
              <navPoint id="ch\(i + 1)" playOrder="\(i + 1)">
                <navLabel><text>\(title.htmlEscaped)</text></navLabel>
                <content src="chapters/\(file)"/>
              </navPoint>
            """
        }.joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
          <head><meta name="dtb:uid" content="urn:uuid:\(novel.id)"/></head>
          <docTitle><text>\(novel.title.htmlEscaped)</text></docTitle>
          <navMap>
        \(points)
          </navMap>
        </ncx>
        """
    }

    // MARK: - content.opf

    private static func contentOPF(novel: Novel, options: ExportOptions, coverInfo: (mime: String, ext: String)) -> String {
        let hasCover = options.hasCoverImage
        let dateStr = ISO8601DateFormatter().string(from: Date())

        // Manifest items
        var manifestItems = """
              <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
              <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
              <item id="style" href="styles/style.css" media-type="text/css"/>
        """
        if hasCover {
            manifestItems += "\n      <item id=\"cover-image\" href=\"images/cover.\(coverInfo.ext)\" media-type=\"\(coverInfo.mime)\" properties=\"cover-image\"/>"
            manifestItems += "\n      <item id=\"cover-page\" href=\"chapters/cover.xhtml\" media-type=\"application/xhtml+xml\"/>"
        }
        for i in novel.chapters.indices {
            let file = String(format: "ch%03d", i + 1)
            manifestItems += "\n      <item id=\"\(file)\" href=\"chapters/\(file).xhtml\" media-type=\"application/xhtml+xml\"/>"
        }

        // Spine items
        var spineItems = ""
        if hasCover { spineItems += "\n      <itemref idref=\"cover-page\" linear=\"no\"/>" }
        for i in novel.chapters.indices {
            spineItems += "\n      <itemref idref=\"ch\(String(format: "%03d", i + 1))\"/>"
        }

        // Cover meta
        let coverMeta = hasCover ? "\n    <meta name=\"cover\" content=\"cover-image\"/>" : ""

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="uid">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:identifier id="uid">urn:uuid:\(novel.id)</dc:identifier>
            <dc:title>\(novel.title.htmlEscaped)</dc:title>
            <dc:creator>\(novel.author.isEmpty ? "Unknown" : novel.author.htmlEscaped)</dc:creator>
            <dc:language>\(options.language)</dc:language>
            <dc:date>\(dateStr)</dc:date>
            <meta property="dcterms:modified">\(dateStr)</meta>\(coverMeta)
            \(options.publisher.isEmpty ? "" : "<dc:publisher>\(options.publisher.htmlEscaped)</dc:publisher>")
            \(options.rights.isEmpty    ? "" : "<dc:rights>\(options.rights.htmlEscaped)</dc:rights>")
            \(options.isbn.isEmpty      ? "" : "<dc:identifier>\(options.isbn.htmlEscaped)</dc:identifier>")
          </metadata>
          <manifest>
        \(manifestItems)
          </manifest>
          <spine toc="ncx">\(spineItems)
          </spine>
        </package>
        """
    }

    // MARK: - Helpers

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
