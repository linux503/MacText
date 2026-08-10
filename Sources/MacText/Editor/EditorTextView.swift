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

    /// Tab: indent whole lines when the selection spans multiple lines; otherwise insert spaces.
    override func insertTab(_ sender: Any?) {
        let range = selectedRange()
        if selectionSpansMultipleLines(range) {
            indentLines(intersecting: range)
        } else {
            insertText(Self.indentUnit, replacementRange: range)
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

    private func selectionSpansMultipleLines(_ range: NSRange) -> Bool {
        guard range.length > 0 else { return false }
        let ns = string as NSString
        let selected = ns.substring(with: range)
        if selected.contains("\n") { return true }
        let startLine = ns.lineRange(for: NSRange(location: range.location, length: 0))
        let endLoc = max(range.location, NSMaxRange(range) - 1)
        let endLine = ns.lineRange(for: NSRange(location: endLoc, length: 0))
        return startLine.location != endLine.location
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
            let line = ns.lineRange(for: NSRange(location: min(idx, ns.length - (ns.length > 0 ? 1 : 0)), length: 0))
            lines.append(line)
            let next = NSMaxRange(line)
            if next <= idx { break }
            idx = next
        }
        if lines.isEmpty {
            lines.append(ns.lineRange(for: NSRange(location: min(block.location, max(0, ns.length - 1)), length: 0)))
        }
        return lines
    }

    func indentLines(intersecting range: NSRange) {
        let ns = string as NSString
        let block = lineBlock(covering: range)
        let lines = enumerateLines(in: block)
        guard !lines.isEmpty else { return }

        var rebuilt = ""
        rebuilt.reserveCapacity(block.length + lines.count * Self.indentWidth)
        for line in lines {
            let text = ns.substring(with: line)
            rebuilt += Self.indentUnit + text
        }

        let oldSel = selectedRange()
        guard shouldChangeText(in: block, replacementString: rebuilt) else { return }
        replaceCharacters(in: block, with: rebuilt)
        didChangeText()

        let deltaPerLine = Self.indentWidth
        let newStart = shiftedLocation(oldSel.location, lines: lines, deltas: lines.map { _ in deltaPerLine })
        let newEnd = shiftedLocation(NSMaxRange(oldSel), lines: lines, deltas: lines.map { _ in deltaPerLine })
        let loc = min(newStart, newEnd)
        let len = abs(newEnd - newStart)
        setSelectedRange(NSRange(location: loc, length: len))
    }

    func unindentLines(intersecting range: NSRange) {
        let ns = string as NSString
        let block = lineBlock(covering: range)
        let lines = enumerateLines(in: block)
        guard !lines.isEmpty else { return }

        var rebuilt = ""
        var deltas: [Int] = []
        rebuilt.reserveCapacity(block.length)
        for line in lines {
            let text = ns.substring(with: line)
            let (stripped, removed) = Self.stripOneIndent(from: text)
            rebuilt += stripped
            deltas.append(-removed)
        }

        if deltas.allSatisfy({ $0 == 0 }) { return }

        let oldSel = selectedRange()
        guard shouldChangeText(in: block, replacementString: rebuilt) else { return }
        replaceCharacters(in: block, with: rebuilt)
        didChangeText()

        let newStart = shiftedLocation(oldSel.location, lines: lines, deltas: deltas)
        let newEnd = shiftedLocation(NSMaxRange(oldSel), lines: lines, deltas: deltas)
        let loc = min(newStart, newEnd)
        let len = abs(newEnd - newStart)
        setSelectedRange(NSRange(location: loc, length: len))
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

    /// Remove one indent level: a leading tab, or up to `indentWidth` spaces.
    private static func stripOneIndent(from line: String) -> (String, Int) {
        if line.hasPrefix("\t") {
            return (String(line.dropFirst()), 1)
        }
        var remove = 0
        for ch in line {
            if ch == " ", remove < indentWidth {
                remove += 1
            } else {
                break
            }
        }
        if remove == 0 { return (line, 0) }
        return (String(line.dropFirst(remove)), remove)
    }
}
