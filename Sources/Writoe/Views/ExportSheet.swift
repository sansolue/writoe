import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ExportSheet: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) var dismiss
    @State private var format: ExportFormatType = .epub
    @State private var options = ExportOptions()
    @State private var isExporting = false
    @State private var errorMessage: String?

    var body: some View {
        HStack(spacing: 0) {
            formatSidebar
            Divider()
            VStack(spacing: 0) {
                optionsPanel
                Divider()
                footer
            }
        }
        .frame(width: 600, height: 480)
    }

    // MARK: - Left: Format selector

    private var formatSidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Export As")
                .font(.caption.uppercaseSmallCaps())
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)

            ForEach(ExportFormatType.allCases) { f in
                FormatRow(f: f, selected: format == f) { format = f }
            }

            Spacer()

            Text("\(store.novel.totalWordCount.formatted()) words total")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(width: 164)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Right: Options

    private var optionsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Format description
                VStack(alignment: .leading, spacing: 4) {
                    Label(format.displayName, systemImage: format.icon)
                        .font(.headline)
                    Text(format.blurb)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 20)

                // Common options (all formats)
                OptionsSection(title: "Content") {
                    Toggle("Include chapter numbers", isOn: $options.includeChapterNumbers)
                    Toggle("Include scene titles", isOn: $options.includeSceneTitles)
                    HStack {
                        Text("Scene separator")
                        Spacer()
                        TextField("e.g. * * *", text: $options.sceneSeparator)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }
                }

                // EPUB options
                if format.hasEPUBOptions {
                    Divider().padding(.vertical, 16)
                    EPUBOptionsPanel(options: options)
                }

                // DOCX options
                if format.hasTypographyOptions {
                    Divider().padding(.vertical, 16)
                    OptionsSection(title: "Typography") {
                        HStack {
                            Text("Font")
                            Spacer()
                            Picker("", selection: $options.fontName) {
                                Text("Georgia").tag("Georgia")
                                Text("Times New Roman").tag("Times New Roman")
                                Text("Palatino").tag("Palatino")
                                Text("Arial").tag("Arial")
                            }
                            .frame(width: 160)
                        }
                        HStack {
                            Text("Size")
                            Spacer()
                            Stepper("\(Int(options.fontSize)) pt", value: $options.fontSize, in: 9...18, step: 1)
                        }
                        HStack {
                            Text("Line spacing")
                            Spacer()
                            Picker("", selection: $options.lineSpacing) {
                                Text("Single").tag(1.0)
                                Text("1.5×").tag(1.5)
                                Text("Double").tag(2.0)
                            }
                            .frame(width: 120)
                        }
                    }
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if let err = errorMessage {
                Label(err, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Spacer()
            Button("Cancel") { dismiss() }
            Button(isExporting ? "Exporting…" : "Export…") {
                runExport()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isExporting)
        }
        .padding(16)
    }

    // MARK: - Export

    private func runExport() {
        let panel = NSSavePanel()
        panel.title = "Export \(store.novel.title)"
        panel.nameFieldStringValue = store.novel.title
        panel.allowedContentTypes = [utType(for: format)]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        isExporting = true
        errorMessage = nil

        Task {
            do {
                switch format {
                case .plainText:
                    let text = PlainTextExporter.export(novel: store.novel, options: options)
                    try text.write(to: url, atomically: true, encoding: .utf8)
                case .markdown:
                    let text = MarkdownExporter.export(novel: store.novel, options: options)
                    try text.write(to: url, atomically: true, encoding: .utf8)
                case .docx:
                    let data = try DocxExporter.export(novel: store.novel, options: options)
                    try data.write(to: url)
                case .epub:
                    let data = try EPUBExporter.export(novel: store.novel, options: options)
                    try data.write(to: url)
                }
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isExporting = false
                }
            }
        }
    }

    private func utType(for format: ExportFormatType) -> UTType {
        switch format {
        case .plainText: return .plainText
        case .markdown:  return UTType(filenameExtension: "md") ?? .plainText
        case .docx:      return UTType(filenameExtension: "docx") ?? .data
        case .epub:      return UTType(filenameExtension: "epub") ?? .data
        }
    }
}

// MARK: - Format row

private struct FormatRow: View {
    let f: ExportFormatType
    let selected: Bool
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: f.icon)
                    .frame(width: 20)
                    .foregroundStyle(selected ? .white : .accentColor)
                Text(f.displayName)
                    .font(.subheadline)
                    .foregroundStyle(selected ? .white : .primary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                selected ? Color.accentColor : (hovered ? Color.accentColor.opacity(0.1) : Color.clear),
                in: RoundedRectangle(cornerRadius: 7)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// MARK: - EPUB options panel

private struct EPUBOptionsPanel: View {
    var options: ExportOptions

    var body: some View {
        OptionsSection(title: "E-Book Details") {
            // Cover image
            VStack(alignment: .leading, spacing: 8) {
                Text("Cover Image")
                    .font(.caption.uppercaseSmallCaps())
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    if let data = options.coverImageData,
                       let nsImg = NSImage(data: data) {
                        Image(nsImage: nsImg)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .frame(width: 60, height: 80)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundStyle(.tertiary)
                            )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Button("Choose Image…") { pickCoverImage() }
                        if options.hasCoverImage {
                            Button("Remove") { options.clearCover() }
                                .foregroundStyle(.red)
                            if let url = options.coverImageURL {
                                Text(url.lastPathComponent)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("JPEG or PNG recommended.\n1600×2400 px or larger.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            HStack {
                Text("Language")
                Spacer()
                TextField("en", text: Binding(
                    get: { options.language },
                    set: { options.language = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
            }
            HStack {
                Text("Publisher")
                Spacer()
                TextField("Optional", text: Binding(
                    get: { options.publisher },
                    set: { options.publisher = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
            }
            HStack {
                Text("Rights")
                Spacer()
                TextField("Optional", text: Binding(
                    get: { options.rights },
                    set: { options.rights = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
            }
            HStack {
                Text("ISBN")
                Spacer()
                TextField("Optional", text: Binding(
                    get: { options.isbn },
                    set: { options.isbn = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 160)
            }
        }
    }

    private func pickCoverImage() {
        let panel = NSOpenPanel()
        panel.title = "Choose Cover Image"
        panel.allowedContentTypes = [.jpeg, .png, .tiff, .bmp]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        options.coverImageData = try? Data(contentsOf: url)
        options.coverImageURL  = url
    }
}

// MARK: - Section wrapper

private struct OptionsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.uppercaseSmallCaps())
                .foregroundStyle(.secondary)
            content()
        }
    }
}
