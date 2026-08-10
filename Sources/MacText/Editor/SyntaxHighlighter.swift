import AppKit
import Foundation

enum SyntaxTokenKind {
    case keyword
    case string
    case comment
    case number
    case typeName
    case function
    case `operator`
    case plain
}

struct SyntaxHighlighter {
    static func highlight(
        text: String,
        language: LanguageKind,
        theme: EditorTheme,
        font: NSFont
    ) -> NSAttributedString {
        let result = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: theme.foreground
            ]
        )

        guard !text.isEmpty else { return result }

        let effective = language == .plain ? inferLanguage(from: text) : language
        let bold = NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .semibold)
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)

        func apply(_ regex: NSRegularExpression, kind: SyntaxTokenKind, boldFont: Bool = false) {
            regex.enumerateMatches(in: text, options: [], range: full) { match, _, _ in
                guard let match else { return }
                let range = match.range(at: match.numberOfRanges > 1 ? 1 : 0)
                guard range.location != NSNotFound, range.length > 0 else { return }
                let attrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: color(for: kind, theme: theme),
                    .font: boldFont ? bold : font
                ]
                result.addAttributes(attrs, range: range)
            }
        }

        // Comments & strings first so they win over keywords.
        for pattern in commentPatterns(for: effective) {
            if let re = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) {
                apply(re, kind: .comment)
            }
        }
        for pattern in stringPatterns(for: effective) {
            if let re = try? NSRegularExpression(pattern: pattern, options: []) {
                apply(re, kind: .string)
            }
        }
        if let re = try? NSRegularExpression(pattern: #"\b0x[0-9A-Fa-f]+\b|\b\d+(\.\d+)?\b"#, options: []) {
            apply(re, kind: .number)
        }
        if let keywords = keywordPattern(for: effective),
           let re = try? NSRegularExpression(pattern: keywords, options: []) {
            apply(re, kind: .keyword, boldFont: true)
        }
        if let types = typePattern(for: effective),
           let re = try? NSRegularExpression(pattern: types, options: []) {
            apply(re, kind: .typeName)
        }
        if let funcs = functionPattern(for: effective),
           let re = try? NSRegularExpression(pattern: funcs, options: []) {
            apply(re, kind: .function)
        }
        // Operators before strings would be wrong; apply only outside already-colored
        // ranges by checking if current color is still default foreground.
        if let re = try? NSRegularExpression(pattern: #"[+\-*%=<>!&|^~?:]+|/(?!/)|->"#, options: []) {
            re.enumerateMatches(in: text, options: [], range: full) { match, _, _ in
                guard let match else { return }
                let range = match.range
                guard range.location != NSNotFound, range.length > 0 else { return }
                let existing = result.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? NSColor
                if existing == nil || existing == theme.foreground {
                    result.addAttributes(
                        [
                            .foregroundColor: theme.operatorColor,
                            .font: font
                        ],
                        range: range
                    )
                }
            }
        }

        if effective == .markdown {
            if let re = try? NSRegularExpression(pattern: #"^#{1,6}\s.*$"#, options: [.anchorsMatchLines]) {
                apply(re, kind: .keyword, boldFont: true)
            }
            if let re = try? NSRegularExpression(pattern: #"`[^`]+`"#, options: []) {
                apply(re, kind: .string)
            }
            if let re = try? NSRegularExpression(pattern: #"\*\*[^*]+\*\*|__[^_]+__"#, options: []) {
                apply(re, kind: .function, boldFont: true)
            }
        }

        return result
    }

    /// Guess language from buffer when file has no extension (untitled).
    static func inferLanguage(from text: String) -> LanguageKind {
        let sample = String(text.prefix(4000))
        if sample.contains("func ") || sample.contains("import Foundation") || sample.contains("var ") && sample.contains(": ") {
            if sample.contains("func ") || sample.contains("guard ") || sample.contains("let ") {
                return .swift
            }
        }
        if sample.contains("def ") || sample.contains("import ") && (sample.contains("self") || sample.contains("print(")) {
            return .python
        }
        if sample.contains("const ") || sample.contains("function ") || sample.contains("=>") || sample.contains("console.") {
            if sample.contains(": string") || sample.contains("interface ") || sample.contains("type ") {
                return .typescript
            }
            return .javascript
        }
        if sample.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{")
            || sample.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[") {
            return .json
        }
        if sample.contains("# ") || sample.contains("```") {
            return .markdown
        }
        // Generic code-like: still highlight strings/numbers/comments via swift-ish fallback
        if sample.contains("//") || sample.contains("/*") || sample.contains("\"") {
            return .javascript
        }
        return .plain
    }

    private static func color(for kind: SyntaxTokenKind, theme: EditorTheme) -> NSColor {
        switch kind {
        case .keyword: return theme.keyword
        case .string: return theme.string
        case .comment: return theme.comment
        case .number: return theme.number
        case .typeName: return theme.typeName
        case .function: return theme.function
        case .operator: return theme.operatorColor
        case .plain: return theme.foreground
        }
    }

    private static func commentPatterns(for language: LanguageKind) -> [String] {
        switch language {
        case .python:
            return [
                #"#.*"#,
                #"\"\"\"[\s\S]{0,4000}?\"\"\""#,
                #"'''[\s\S]{0,4000}?'''"#
            ]
        case .swift, .javascript, .typescript, .json:
            return [#"//.*"#, #"/\*[\s\S]{0,8000}?\*/"#]
        case .markdown, .plain:
            return [#"#.*"#, #"//.*"#]
        }
    }

    private static func stringPatterns(for language: LanguageKind) -> [String] {
        switch language {
        case .python:
            return [#"("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')"#]
        case .swift:
            return [#"("(?:\\.|[^"\\])*")"#]
        case .javascript, .typescript, .json:
            return [#"("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`)"#]
        case .markdown, .plain:
            return [#"("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')"#]
        }
    }

    private static func keywordPattern(for language: LanguageKind) -> String? {
        let words: [String]
        switch language {
        case .swift:
            words = [
                "import", "let", "var", "func", "return", "if", "else", "guard", "switch", "case",
                "default", "for", "while", "in", "where", "struct", "class", "enum", "protocol",
                "extension", "actor", "async", "await", "throws", "try", "catch", "defer", "true",
                "false", "nil", "self", "Self", "static", "private", "public", "internal",
                "fileprivate", "open", "final", "override", "mutating", "some", "any", "typealias",
                "associatedtype", "init", "deinit", "subscript", "get", "set", "willSet", "didSet"
            ]
        case .python:
            words = [
                "def", "class", "return", "if", "elif", "else", "for", "while", "in", "not", "and",
                "or", "import", "from", "as", "with", "try", "except", "finally", "raise", "pass",
                "break", "continue", "lambda", "yield", "async", "await", "True", "False", "None",
                "global", "nonlocal", "assert", "del"
            ]
        case .javascript, .typescript:
            words = [
                "const", "let", "var", "function", "return", "if", "else", "for", "while", "do",
                "switch", "case", "default", "break", "continue", "try", "catch", "finally", "throw",
                "new", "class", "extends", "super", "this", "import", "export", "from", "as",
                "async", "await", "typeof", "instanceof", "of", "in", "true", "false", "null",
                "undefined", "interface", "type", "enum", "implements", "public", "private",
                "protected", "readonly"
            ]
        case .json:
            words = ["true", "false", "null"]
        case .markdown:
            return nil
        case .plain:
            words = [
                "if", "else", "for", "while", "return", "function", "class", "const", "let", "var",
                "import", "from", "def", "func", "true", "false", "null", "nil", "True", "False", "None"
            ]
        }
        let joined = words.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        return #"\b(?:\#(joined))\b"#
    }

    private static func typePattern(for language: LanguageKind) -> String? {
        switch language {
        case .swift, .typescript:
            return #"\b[A-Z][A-Za-z0-9_]*\b"#
        default:
            return nil
        }
    }

    private static func functionPattern(for language: LanguageKind) -> String? {
        switch language {
        case .swift, .javascript, .typescript, .python, .plain:
            return #"\b([A-Za-z_][A-Za-z0-9_]*)\s*(?=\()"#
        default:
            return nil
        }
    }
}
