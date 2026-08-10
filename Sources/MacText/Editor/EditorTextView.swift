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
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isContinuousSpellCheckingEnabled = false
        isGrammarCheckingEnabled = false
        usesFindBar = false
        isEditable = true
        isSelectable = true
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

    // MARK: - Sublime-like indent / unindent

    override func keyDown(with event: NSEvent) {
        // Catch Tab / Shift+Tab before AppKit inserts a literal tab glyph.
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

    /// Tab: indent whole lines when selection covers 2+ lines (even partial); else insert spaces.
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
}
