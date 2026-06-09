# Writoe

A focused novel writing app for macOS. Writoe keeps your manuscript, characters, and structure in one place without getting in the way.

## Features

- **Chapter and scene management** — drag to reorder chapters and scenes in the sidebar
- **Corkboard view** — visual overview of all scenes with editable synopsis cards
- **Character profiles** — track role, traits, backstory, and notes; auto-saves as you type
- **Writing themes** — System, Sepia, Dark, Midnight, and High Contrast
- **Multilingual support** — 30+ languages with font filtering by script, right-to-left text direction, and language-aware word counting (CJK, Arabic, Indic)
- **Distraction-free mode** — full-screen centered writing column, controls appear on hover
- **Global find** — search across all scenes with highlighted excerpts
- **Native find bar** — per-scene find and replace via the standard macOS find bar (⌘F)
- **AI writing assistant** — continue writing, rewrite, brainstorm, or generate dialogue via the Anthropic API
- **Export** — Plain text, Markdown, DOCX (with custom font and line spacing), and EPUB 3 (with cover image, metadata, and proper spine)
- **Daily word goal** — progress bar tracked per day in the inspector

## Requirements

- macOS 14 Sonoma or later
- Xcode Command Line Tools or Xcode
- An [Anthropic API key](https://console.anthropic.com) for the AI assistant (optional)

## Building

```bash
# Clone the repository
git clone git@github.com:sansolue/writoe.git
cd writoe

# Build and launch
./run.sh
```

`run.sh` compiles the Swift package, copies the binary into a minimal `.app` bundle, and opens it. The app bundle is placed at `Writoe.app` in the project root.

To build without launching:

```bash
swift build -c release
```

## Project structure

```
Sources/Writoe/
├── Models/          Novel, Chapter, Scene, Character, WritingLanguage, WritingTheme
├── Store/           AppStore (@Observable state), ProjectManager
├── Services/        AIService (Anthropic API)
├── Export/          PlainTextExporter, MarkdownExporter, DocxExporter, EPUBExporter
└── Views/           All SwiftUI views
```

Projects are saved as JSON files wherever the user chooses. The last opened project is remembered across launches.

## License

MIT — see [LICENSE](LICENSE).
