import Foundation

struct PlainTextExporter {
    static func export(novel: Novel, options: ExportOptions) -> String {
        var out = novel.title + "\n"
        if !novel.author.isEmpty { out += "by \(novel.author)\n" }
        out += "\n\n"

        for (i, chapter) in novel.chapters.enumerated() {
            out += chapterHeading(chapter, index: i, options: options).uppercased() + "\n\n"
            for (si, scene) in chapter.scenes.enumerated() {
                if options.includeSceneTitles && chapter.scenes.count > 1 {
                    out += scene.title + "\n\n"
                }
                out += scene.content.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n"
                if si < chapter.scenes.count - 1, !options.sceneSeparator.isEmpty {
                    out += options.sceneSeparator + "\n\n"
                }
            }
        }
        return out
    }
}

struct MarkdownExporter {
    static func export(novel: Novel, options: ExportOptions) -> String {
        var out = "# \(novel.title)\n"
        if !novel.author.isEmpty { out += "*by \(novel.author)*\n" }
        out += "\n---\n\n"

        for (i, chapter) in novel.chapters.enumerated() {
            out += "## \(chapterHeading(chapter, index: i, options: options))\n\n"
            for (si, scene) in chapter.scenes.enumerated() {
                if options.includeSceneTitles && chapter.scenes.count > 1 {
                    out += "### \(scene.title)\n\n"
                }
                out += scene.content.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n"
                if si < chapter.scenes.count - 1, !options.sceneSeparator.isEmpty {
                    out += "*\(options.sceneSeparator)*\n\n"
                }
            }
        }
        return out
    }
}

private func chapterHeading(_ chapter: Chapter, index: Int, options: ExportOptions) -> String {
    let num = options.includeChapterNumbers ? "Chapter \(index + 1)" : nil
    let title = chapter.title.trimmingCharacters(in: .whitespaces)
    switch (num, title.isEmpty) {
    case (let n?, false): return "\(n): \(title)"
    case (let n?, true):  return n
    case (nil, false):    return title
    case (nil, true):     return "Chapter \(index + 1)"
    }
}
