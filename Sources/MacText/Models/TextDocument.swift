import Foundation

enum LanguageKind: String, CaseIterable {
    case plain
    case swift
    case python
    case javascript
    case typescript
    case json
    case markdown

    var displayName: String {
        switch self {
        case .plain: return "Plain Text"
        case .swift: return "Swift"
        case .python: return "Python"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .json: return "JSON"
        case .markdown: return "Markdown"
        }
    }

    static func detect(from url: URL?) -> LanguageKind {
        guard let ext = url?.pathExtension.lowercased(), !ext.isEmpty else {
            return .plain
        }
        switch ext {
        case "swift": return .swift
        case "py": return .python
        case "js", "jsx", "mjs", "cjs": return .javascript
        case "ts", "tsx": return .typescript
        case "json": return .json
        case "md", "markdown": return .markdown
        default: return .plain
        }
    }
}

final class TextDocument: Identifiable {
    let id: UUID
    var title: String
    var fileURL: URL?
    var content: String
    var isDirty: Bool
    var language: LanguageKind
    var cursorLine: Int
    var cursorColumn: Int
    /// When false, skip syntax highlight (large files).
    var enableHighlight: Bool

    init(
        id: UUID = UUID(),
        title: String = "Untitled",
        fileURL: URL? = nil,
        content: String = "",
        isDirty: Bool = false,
        language: LanguageKind = .plain,
        enableHighlight: Bool = true
    ) {
        self.id = id
        self.title = title
        self.fileURL = fileURL
        self.content = content
        self.isDirty = isDirty
        self.language = language
        self.cursorLine = 1
        self.cursorColumn = 1
        self.enableHighlight = enableHighlight
    }

    var displayTitle: String {
        isDirty ? "• \(title)" : title
    }

    func updateContent(_ text: String) {
        if content != text {
            content = text
            isDirty = true
        }
    }

    func markSaved(at url: URL) {
        fileURL = url
        title = url.lastPathComponent
        language = LanguageKind.detect(from: url)
        isDirty = false
    }
}
