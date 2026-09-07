import AppKit

/// Sublime-like editor text view: fills blank area, current-line highlight, click-anywhere to type.
final class EditorTextView: NSTextView {
    /// Matches Sublime’s common default (`translate_tabs_to_spaces` + `tab_size: 4`).
    static let indentUnit = "    "
    private static var indentWidth: Int { indentUnit.count }

    var theme: EditorTheme = .ink {
        didSet { needsDisplay = true }
    }

    override var acceptsFirstResponder: Bool { true }

    override func awakeFromNib() {
        super.awakeFromNib()
        commonSetup()
    }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        commonSetup()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonSetup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func commonSetup() {
        // Keep rich-text attributes enabled so syntax colors stick.
        isRichText = true
        importsGraphics = false
        allowsUndo = true
        allowsCharacterPickerTouchBarItem = true
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isContinuousSpellCheckingEnabled = false
        isGrammarCheckingEnabled = false
        usesFindBar = false
        isEditable = true
        isSelectable = true
        // Do not disable smart insert/delete in a way that breaks IMEs;
        // marked-text composition must reach NSTextInputClient unchanged.
        typingAttributes = [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: theme.foreground
        ]
    }

    override func drawBackground(in rect: NSRect) {
        theme.background.setFill()
        bounds.fill()

        // Current line highlight (Sublime-style)
        if selectedRange().length == 0,
           let layoutManager,
           textContainer != nil {
            let loc = min(selectedRange().location, (string as NSString).length)
            let glyphIndex: Int
            if (string as NSString).length == 0 {
                glyphIndex = 0
            } else {
                glyphIndex = layoutManager.glyphIndexForCharacter(at: min(loc, max(0, (string as NSString).length - 1)))
            }
            var lineRange = NSRange()
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineRange)
            var highlight = lineRect
            highlight.origin.x = bounds.minX
            highlight.size.width = bounds.width
            if (string as NSString).length == 0 {
                let lineHeight = layoutManager.defaultLineHeight(for: font ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular))
                highlight = NSRect(
                    x: bounds.minX,
                    y: textContainerInset.height,
                    width: bounds.width,
                    height: lineHeight
                )
            } else {
                highlight.origin.y += textContainerInset.height
            }
            theme.currentLine.setFill()
            highlight.fill()
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    /// Keep the view at least as tall as the visible clip view so empty space is clickable.
    func ensureFillsVisibleArea(in scrollView: NSScrollView) {
        let visibleHeight = scrollView.contentView.bounds.height
        var frame = self.frame
        let needed = max(visibleHeight, frame.size.height)
        if abs(frame.size.height - needed) > 0.5 {
            frame.size.height = needed
            self.frame = frame
        }
        minSize = NSSize(width: 0, height: visibleHeight)
    }

    // MARK: - Input Method (Pinyin etc.)

    /// While composing (marked text), never steal keys — Tab confirms candidates in many IMEs.
    override func keyDown(with event: NSEvent) {
        if hasMarkedText() {
            super.keyDown(with: event)
            return
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // Sublime: ⌘⌃↑ / ⌘⌃↓ move line
        if flags == [.command, .control] {
            if event.keyCode == 126 { moveLineUp(nil); return }
            if event.keyCode == 125 { moveLineDown(nil); return }
        }
        if event.keyCode == 48 { // Tab
            if event.modifierFlags.contains(.shift) {
                insertBacktab(nil)
            } else {
                insertTab(nil)
            }
            return
        }
        super.keyDown(with: event)
    }

    override func doCommand(by selector: Selector) {
        if hasMarkedText() {
            super.doCommand(by: selector)
            return
        }
        if selector == #selector(insertTab(_:)) {
            insertTab(nil)
            return
        }
        if selector == #selector(insertBacktab(_:)) {
            insertBacktab(nil)
            return
        }
        super.doCommand(by: selector)
    }

    override func unmarkText() {
        super.unmarkText()
        NotificationCenter.default.post(name: .macTextInputDidUnmark, object: self)
    }

    // MARK: - Paste

    /// Plain txt only: no RTF/HTML. Tabular clipboard (TSV) is padded into aligned columns.
    override func paste(_ sender: Any?) {
        let pb = NSPasteboard.general
        if let plain = pb.string(forType: .string) ?? pb.string(forType: .tabularText) {
            let text = Self.plainTextForPaste(plain)
            let range = selectedRange()
            if shouldChangeText(in: range, replacementString: text) {
                insertText(text, replacementRange: range)
            }
            return
        }
        super.pasteAsPlainText(sender)
    }

    /// Keep paste as ordinary txt; align multi-column tab tables with spaces.
    private static func plainTextForPaste(_ raw: String) -> String {
        let normalized = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        guard let aligned = alignTabularPlainText(normalized) else { return normalized }
        return aligned
    }

    /// If text looks like a TSV table (≥2 rows, ≥2 columns via tabs), pad columns with spaces.
    private static func alignTabularPlainText(_ text: String) -> String? {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let nonEmpty = lines.filter { !$0.isEmpty }
        guard nonEmpty.count >= 2 else { return nil }

        let parsed: [[String]] = nonEmpty.map { line in
            line.split(separator: "\t", omittingEmptySubsequences: false).map {
                String($0).trimmingCharacters(in: .whitespaces)
            }
        }
        let colCount = parsed.map(\.count).max() ?? 0
        guard colCount >= 2, parsed.allSatisfy({ $0.count >= 2 }) else { return nil }
        let modeCount = Dictionary(grouping: parsed.map(\.count), by: { $0 })
            .max(by: { $0.value.count < $1.value.count })?.key ?? colCount
        guard modeCount >= 2 else { return nil }

        func cells(for line: String) -> [String] {
            var row = line.split(separator: "\t", omittingEmptySubsequences: false).map {
                String($0).trimmingCharacters(in: .whitespaces)
            }
            while row.count < modeCount { row.append("") }
            if row.count > modeCount { row = Array(row.prefix(modeCount)) }
            return row
        }

        var widths = Array(repeating: 0, count: modeCount)
        for line in nonEmpty {
            for (i, cell) in cells(for: line).enumerated() {
                widths[i] = max(widths[i], displayWidth(cell))
            }
        }

        let gap = 2
        let alignedLines: [String] = lines.map { line in
            if line.isEmpty { return "" }
            let row = cells(for: line)
            return row.enumerated().map { i, cell in
                let pad = widths[i] - displayWidth(cell)
                let isLast = i == modeCount - 1
                return isLast ? cell : cell + String(repeating: " ", count: max(0, pad) + gap)
            }.joined()
        }

        let body = alignedLines.joined(separator: "\n")
        if text.hasSuffix("\n") { return body + "\n" }
        return body
    }

    /// Monospace column width: CJK / fullwidth ≈ 2, ASCII ≈ 1.
    private static func displayWidth(_ s: String) -> Int {
        var w = 0
        for ch in s {
            if ch == "\t" {
                w += 4
                continue
            }
            let scalars = ch.unicodeScalars
            if let v = scalars.first, scalars.count == 1 {
                // Fullwidth / wide East Asian
                if (0x1100...0x115F).contains(v.value)
                    || (0x2E80...0xA4CF).contains(v.value)
                    || (0xAC00...0xD7A3).contains(v.value)
                    || (0xF900...0xFAFF).contains(v.value)
                    || (0xFE10...0xFE19).contains(v.value)
                    || (0xFE30...0xFE6F).contains(v.value)
                    || (0xFF00...0xFF60).contains(v.value)
                    || (0xFFE0...0xFFE6).contains(v.value)
                    || (0x1F300...0x1FAFF).contains(v.value) {
                    w += 2
                    continue
                }
            }
            w += 1
        }
        return w
    }

    // MARK: - Sublime-like indent / unindent

    override func insertTab(_ sender: Any?) {
        let range = selectedRange()
        if lineCount(intersecting: range) >= 2 {
            indentLines(intersecting: range)
        } else {
            super.insertText(Self.indentUnit, replacementRange: range)
        }
    }

    /// Shift+Tab: unindent every line touched by the caret/selection (partial line OK).
    override func insertBacktab(_ sender: Any?) {
        unindentLines(intersecting: selectedRange())
    }

    /// ⌘] — indent lines (Sublime)
    @objc func indentSelectedLines(_ sender: Any?) {
        indentLines(intersecting: selectedRange())
    }

    /// ⌘[ — unindent lines (Sublime)
    @objc func unindentSelectedLines(_ sender: Any?) {
        unindentLines(intersecting: selectedRange())
    }

    private func lineCount(intersecting range: NSRange) -> Int {
        enumerateLines(in: lineBlock(covering: range)).count
    }

    /// Full line block covering every line that intersects `range` (partial front/back still counts).
    private func lineBlock(covering range: NSRange) -> NSRange {
        let ns = string as NSString
        guard ns.length > 0 else { return NSRange(location: 0, length: 0) }
        let start = min(max(0, range.location), ns.length)
        let endExclusive = min(max(start, NSMaxRange(range)), ns.length)
        let lastChar = range.length == 0 ? start : max(start, endExclusive - 1)
        let first = ns.lineRange(for: NSRange(location: start, length: 0))
        let last = ns.lineRange(for: NSRange(location: lastChar, length: 0))
        return NSUnionRange(first, last)
    }

    private func enumerateLines(in block: NSRange) -> [NSRange] {
        let ns = string as NSString
        guard ns.length > 0 else { return [NSRange(location: 0, length: 0)] }
        var lines: [NSRange] = []
        var idx = block.location
        let limit = NSMaxRange(block)
        while idx < limit {
            let safe = min(idx, max(0, ns.length - 1))
            let line = ns.lineRange(for: NSRange(location: safe, length: 0))
            if let last = lines.last, last == line { break }
            lines.append(line)
            let next = NSMaxRange(line)
            if next <= idx { break }
            idx = next
        }
        if lines.isEmpty {
            let safe = min(block.location, max(0, ns.length - 1))
            lines.append(ns.lineRange(for: NSRange(location: safe, length: 0)))
        }
        return lines
    }

    func indentLines(intersecting range: NSRange) {
        let block = lineBlock(covering: range)
        let lines = enumerateLines(in: block)
        guard !lines.isEmpty else { return }

        undoManager?.beginUndoGrouping()
        defer { undoManager?.endUndoGrouping() }

        let oldSel = selectedRange()

        // Apply from bottom to top so ranges stay valid.
        for line in lines.reversed() {
            let insertRange = NSRange(location: line.location, length: 0)
            if shouldChangeText(in: insertRange, replacementString: Self.indentUnit) {
                replaceCharacters(in: insertRange, with: Self.indentUnit)
                didChangeText()
            }
        }

        let delta = Self.indentWidth
        let deltas = Array(repeating: delta, count: lines.count)
        let newStart = shiftedLocation(oldSel.location, lines: lines, deltas: deltas)
        let newEnd = shiftedLocation(NSMaxRange(oldSel), lines: lines, deltas: deltas)
        setSelectedRange(NSRange(location: min(newStart, newEnd), length: abs(newEnd - newStart)))
    }

    func unindentLines(intersecting range: NSRange) {
        let ns = string as NSString
        let block = lineBlock(covering: range)
        let lines = enumerateLines(in: block)
        guard !lines.isEmpty else { return }

        var removals: [(NSRange, Int)] = []
        for line in lines {
            let text = ns.substring(with: line)
            let removed = Self.leadingIndentLength(in: text)
            if removed > 0 {
                removals.append((NSRange(location: line.location, length: removed), removed))
            }
        }
        guard !removals.isEmpty else { return }

        undoManager?.beginUndoGrouping()
        defer { undoManager?.endUndoGrouping() }

        let oldSel = selectedRange()
        var deltas = Array(repeating: 0, count: lines.count)
        for (idx, line) in lines.enumerated() {
            if let match = removals.first(where: { $0.0.location == line.location }) {
                deltas[idx] = -match.1
            }
        }

        for (removal, _) in removals.reversed() {
            if shouldChangeText(in: removal, replacementString: "") {
                replaceCharacters(in: removal, with: "")
                didChangeText()
            }
        }

        let newStart = shiftedLocation(oldSel.location, lines: lines, deltas: deltas)
        let newEnd = shiftedLocation(NSMaxRange(oldSel), lines: lines, deltas: deltas)
        setSelectedRange(NSRange(location: min(newStart, newEnd), length: abs(newEnd - newStart)))
    }

    /// Shift a document offset after per-line indent/unindent at each line start.
    private func shiftedLocation(_ location: Int, lines: [NSRange], deltas: [Int]) -> Int {
        var add = 0
        for (line, delta) in zip(lines, deltas) where delta != 0 {
            if delta > 0 {
                if location >= line.location {
                    add += delta
                }
            } else {
                let removed = -delta
                if location <= line.location {
                    continue
                }
                if location <= line.location + removed {
                    return max(0, line.location + add)
                }
                add += delta
            }
        }
        return max(0, location + add)
    }

    /// Length of one indent level at the start of a line (tab, or up to 4 spaces).
    private static func leadingIndentLength(in line: String) -> Int {
        if line.hasPrefix("\t") { return 1 }
        var remove = 0
        for ch in line {
            if ch == " ", remove < indentWidth {
                remove += 1
            } else {
                break
            }
        }
        return remove
    }

    // MARK: - Sublime core editing

    /// Auto-indent new line like Sublime (`auto_indent`).
    override func insertNewline(_ sender: Any?) {
        if hasMarkedText() {
            super.insertNewline(sender)
            return
        }
        let ns = string as NSString
        let loc = selectedRange().location
        let line = ns.lineRange(for: NSRange(location: min(loc, max(0, ns.length - (ns.length > 0 ? 1 : 0))), length: 0))
        let lineText = ns.substring(with: line)
        var indent = ""
        for ch in lineText {
            if ch == " " || ch == "\t" { indent.append(ch) } else { break }
        }
        // Extra indent after an unmatched opening brace/bracket on the line.
        let trimmed = lineText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("{") || trimmed.hasSuffix("(") || trimmed.hasSuffix("[") || trimmed.hasSuffix(":") {
            indent += Self.indentUnit
        }
        let insertion = "\n" + indent
        let range = selectedRange()
        if shouldChangeText(in: range, replacementString: insertion) {
            replaceCharacters(in: range, with: insertion)
            didChangeText()
            setSelectedRange(NSRange(location: range.location + insertion.count, length: 0))
        }
    }

    /// ⌘⇧D — duplicate line or selection
    @objc func duplicateLineOrSelection(_ sender: Any?) {
        let ns = string as NSString
        let sel = selectedRange()
        if sel.length > 0 {
            let text = ns.substring(with: sel)
            let insertAt = NSMaxRange(sel)
            if shouldChangeText(in: NSRange(location: insertAt, length: 0), replacementString: text) {
                replaceCharacters(in: NSRange(location: insertAt, length: 0), with: text)
                didChangeText()
                setSelectedRange(NSRange(location: insertAt, length: text.count))
            }
            return
        }
        let block = lineBlock(covering: sel)
        let text = ns.substring(with: block)
        let insertAt = NSMaxRange(block)
        if shouldChangeText(in: NSRange(location: insertAt, length: 0), replacementString: text) {
            replaceCharacters(in: NSRange(location: insertAt, length: 0), with: text)
            didChangeText()
            setSelectedRange(NSRange(location: insertAt, length: 0))
        }
    }

    /// ⌃⇧K — delete line(s)
    @objc func deleteLinesSublime(_ sender: Any?) {
        let block = lineBlock(covering: selectedRange())
        guard block.length > 0 || (string as NSString).length > 0 else { return }
        if shouldChangeText(in: block, replacementString: "") {
            replaceCharacters(in: block, with: "")
            didChangeText()
            setSelectedRange(NSRange(location: min(block.location, (string as NSString).length), length: 0))
        }
    }

    /// ⌘L — select line (repeat extends)
    override func selectLine(_ sender: Any?) {
        let ns = string as NSString
        let sel = selectedRange()
        if sel.length == 0 {
            let block = lineBlock(covering: sel)
            setSelectedRange(block)
            return
        }
        // Extend by one more line below.
        let end = NSMaxRange(sel)
        if end < ns.length {
            let next = ns.lineRange(for: NSRange(location: end, length: 0))
            setSelectedRange(NSUnionRange(sel, next))
        } else {
            setSelectedRange(lineBlock(covering: sel))
        }
    }

    /// ⌘J — join lines
    @objc func joinLines(_ sender: Any?) {
        let ns = string as NSString
        let block = lineBlock(covering: selectedRange())
        let lines = enumerateLines(in: block)
        guard lines.count >= 2 else {
            // Join current with next
            let sel = selectedRange()
            let line = ns.lineRange(for: NSRange(location: min(sel.location, max(0, ns.length - 1)), length: 0))
            let end = NSMaxRange(line)
            guard end < ns.length else { return }
            let next = ns.lineRange(for: NSRange(location: end, length: 0))
            joinLineRanges([line, next])
            return
        }
        joinLineRanges(lines)
    }

    private func joinLineRanges(_ lines: [NSRange]) {
        let ns = string as NSString
        guard lines.count >= 2 else { return }
        var parts: [String] = []
        for (i, line) in lines.enumerated() {
            var text = ns.substring(with: line)
            if text.hasSuffix("\n") { text = String(text.dropLast()) }
            if i > 0 {
                text = text.trimmingCharacters(in: .whitespaces)
            }
            parts.append(text)
        }
        let joined = parts.joined(separator: " ")
        let block = NSUnionRange(lines.first!, lines.last!)
        if shouldChangeText(in: block, replacementString: joined) {
            replaceCharacters(in: block, with: joined)
            didChangeText()
            setSelectedRange(NSRange(location: block.location + joined.count, length: 0))
        }
    }

    /// ⌘⌃↑ — move line(s) up
    @objc func moveLineUp(_ sender: Any?) {
        moveLines(direction: -1)
    }

    /// ⌘⌃↓ — move line(s) down
    @objc func moveLineDown(_ sender: Any?) {
        moveLines(direction: 1)
    }

    private func moveLines(direction: Int) {
        let ns = string as NSString
        let sel = selectedRange()
        let block = lineBlock(covering: sel)
        guard block.length > 0 || ns.length > 0 else { return }

        if direction < 0 {
            guard block.location > 0 else { return }
            let prev = ns.lineRange(for: NSRange(location: block.location - 1, length: 0))
            let moved = ns.substring(with: block)
            let above = ns.substring(with: prev)
            let combined = moved + above
            let full = NSUnionRange(prev, block)
            if shouldChangeText(in: full, replacementString: combined) {
                replaceCharacters(in: full, with: combined)
                didChangeText()
                setSelectedRange(NSRange(location: prev.location, length: moved.count))
            }
        } else {
            let end = NSMaxRange(block)
            guard end < ns.length else { return }
            let next = ns.lineRange(for: NSRange(location: end, length: 0))
            let moved = ns.substring(with: block)
            let below = ns.substring(with: next)
            let combined = below + moved
            let full = NSUnionRange(block, next)
            if shouldChangeText(in: full, replacementString: combined) {
                replaceCharacters(in: full, with: combined)
                didChangeText()
                setSelectedRange(NSRange(location: block.location + below.count, length: moved.count))
            }
        }
    }

    /// ⌘/ — toggle line comment
    @objc func toggleComment(_ sender: Any?) {
        let marker = commentMarker()
        let ns = string as NSString
        let block = lineBlock(covering: selectedRange())
        let lines = enumerateLines(in: block)
        guard !lines.isEmpty else { return }

        let stripped = lines.map { line -> String in
            var t = ns.substring(with: line)
            if t.hasSuffix("\n") { t = String(t.dropLast()) }
            return t
        }
        let allCommented = stripped.allSatisfy { line in
            let trim = line.trimmingCharacters(in: .whitespaces)
            return trim.isEmpty || trim.hasPrefix(marker)
        }

        var rebuilt = ""
        for line in lines {
            var text = ns.substring(with: line)
            let hadNL = text.hasSuffix("\n")
            if hadNL { text = String(text.dropLast()) }
            let leading = text.prefix { $0 == " " || $0 == "\t" }
            let rest = String(text.dropFirst(leading.count))
            let newBody: String
            if allCommented {
                if rest.hasPrefix(marker + " ") {
                    newBody = String(leading) + String(rest.dropFirst(marker.count + 1))
                } else if rest.hasPrefix(marker) {
                    newBody = String(leading) + String(rest.dropFirst(marker.count))
                } else {
                    newBody = text
                }
            } else if rest.isEmpty {
                newBody = text
            } else {
                newBody = String(leading) + marker + " " + rest
            }
            rebuilt += newBody + (hadNL ? "\n" : "")
        }

        if shouldChangeText(in: block, replacementString: rebuilt) {
            replaceCharacters(in: block, with: rebuilt)
            didChangeText()
            setSelectedRange(NSRange(location: block.location, length: rebuilt.count))
        }
    }

    private func commentMarker() -> String {
        let doc = DocumentStore.shared.selectedDocument
        let language: LanguageKind
        if let doc {
            if doc.language == .plain, !doc.content.isEmpty {
                language = SyntaxHighlighter.inferLanguage(from: string.isEmpty ? doc.content : string)
            } else {
                language = doc.language
            }
        } else {
            language = SyntaxHighlighter.inferLanguage(from: string)
        }
        switch language {
        case .python: return "#"
        case .json: return "//"
        default: return "//"
        }
    }

    /// ⌘D — select word under caret, or jump selection to the next same occurrence.
    @objc func selectNextOccurrence(_ sender: Any?) {
        let ns = string as NSString
        guard ns.length > 0 else { return }
        let sel = selectedRange()
        if sel.length == 0 {
            let word = (ns as String).wordRange(at: sel.location) ?? NSRange(location: sel.location, length: 0)
            guard word.length > 0 else { return }
            setSelectedRange(word)
            scrollRangeToVisible(word)
            return
        }
        let needle = ns.substring(with: sel)
        guard !needle.isEmpty else { return }
        let start = NSMaxRange(sel)
        let after = NSRange(location: start, length: max(0, ns.length - start))
        var found = ns.range(of: needle, options: [], range: after)
        if found.location == NSNotFound {
            found = ns.range(of: needle, options: [], range: NSRange(location: 0, length: ns.length))
        }
        guard found.location != NSNotFound, found != sel else { return }
        setSelectedRange(found)
        scrollRangeToVisible(found)
    }

    /// ⌃M — jump to matching bracket
    @objc func jumpToMatchingBracket(_ sender: Any?) {
        guard let match = matchingBracketLocation(near: selectedRange().location) else { return }
        setSelectedRange(NSRange(location: match, length: 0))
        scrollRangeToVisible(NSRange(location: match, length: 0))
    }

    private func matchingBracketLocation(near location: Int) -> Int? {
        let ns = string as NSString
        guard ns.length > 0 else { return nil }
        let pairs: [Character: Character] = ["(": ")", "[": "]", "{": "}", ")": "(", "]": "[", "}": "{"]
        let opens: Set<Character> = ["(", "[", "{"]
        var idx = min(location, ns.length - 1)
        // Prefer char at caret or just before.
        var ch: Character?
        if location < ns.length {
            ch = Character(ns.substring(with: NSRange(location: location, length: 1)))
        }
        if ch == nil || pairs[ch!] == nil, location > 0 {
            idx = location - 1
            ch = Character(ns.substring(with: NSRange(location: idx, length: 1)))
        }
        guard let startChar = ch, let other = pairs[startChar] else { return nil }
        let forward = opens.contains(startChar)
        var depth = 0
        if forward {
            var i = idx
            while i < ns.length {
                let c = Character(ns.substring(with: NSRange(location: i, length: 1)))
                if c == startChar { depth += 1 }
                else if c == other {
                    depth -= 1
                    if depth == 0 { return i }
                }
                i += 1
            }
        } else {
            var i = idx
            while i >= 0 {
                let c = Character(ns.substring(with: NSRange(location: i, length: 1)))
                if c == startChar { depth += 1 }
                else if c == other {
                    depth -= 1
                    if depth == 0 { return i }
                }
                i -= 1
            }
        }
        return nil
    }
}

extension Notification.Name {
    static let macTextInputDidUnmark = Notification.Name("MacTextInputDidUnmark")
}

private extension String {
    /// Word under/near `utf16` offset (letters, digits, underscore).
    func wordRange(at utf16Location: Int) -> NSRange? {
        let ns = self as NSString
        guard ns.length > 0 else { return nil }
        let loc = min(max(0, utf16Location), ns.length)
        let charset = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        func isWord(_ i: Int) -> Bool {
            guard i >= 0, i < ns.length else { return false }
            let u = ns.character(at: i)
            guard let scalar = UnicodeScalar(u) else { return false }
            return charset.contains(scalar)
        }
        var start = loc
        if start < ns.length, !isWord(start), start > 0, isWord(start - 1) {
            start -= 1
        }
        guard isWord(start) || (start > 0 && isWord(start - 1)) else { return nil }
        if !isWord(start) { start -= 1 }
        var begin = start
        while begin > 0, isWord(begin - 1) { begin -= 1 }
        var end = start
        while end < ns.length, isWord(end) { end += 1 }
        guard end > begin else { return nil }
        return NSRange(location: begin, length: end - begin)
    }
}
