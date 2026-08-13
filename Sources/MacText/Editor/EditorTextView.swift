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
        // Infer from filename via typing context — use store language if available.
        if let lang = DocumentStore.shared.selectedDocument?.language {
            switch lang {
            case .python: return "#"
            case .json: return "//"
            default: return "//"
            }
        }
        return "//"
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
