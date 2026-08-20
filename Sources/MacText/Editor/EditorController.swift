import AppKit

final class EditorController: NSObject, NSTextViewDelegate {
    let scrollView = NSScrollView()
    let textView = EditorTextView()
    private var ruler: LineNumberRulerView!
    private weak var document: TextDocument?
    private var theme = EditorTheme.ink
    private var softWrap = false
    private var isUpdating = false
    private var highlightWorkItem: DispatchWorkItem?
    private var fontSize: CGFloat = 13

    private var font: NSFont {
        NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }

    override init() {
        super.init()
        configure()
    }

    private func configure() {
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.autoresizingMask = [.width, .height]
        scrollView.drawsBackground = true

        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = false
        textView.font = font
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.delegate = self
        textView.theme = theme

        scrollView.documentView = textView
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        ruler = LineNumberRulerView(textView: textView)
        ruler.fontSize = fontSize
        scrollView.verticalRulerView = ruler

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(selectionDidChange),
            name: NSTextView.didChangeSelectionNotification,
            object: textView
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clipViewBoundsChanged(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        scrollView.contentView.postsBoundsChangedNotifications = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFindNext(_:)),
            name: .macTextFindNext,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReplaceOne(_:)),
            name: .macTextReplaceOne,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReplaceAll(_:)),
            name: .macTextReplaceAll,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGoToLine(_:)),
            name: .macTextGoToLine,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(inputDidUnmark(_:)),
            name: .macTextInputDidUnmark,
            object: textView
        )
    }

    @objc private func inputDidUnmark(_ note: Notification) {
        guard !isUpdating, let document else { return }
        document.updateContent(textView.string)
        updateCursorLocation()
        DocumentStore.shared.documentContentDidChange()
        scheduleHighlight(delay: 0.05)
    }

    @objc private func clipViewBoundsChanged(_ note: Notification) {
        textView.ensureFillsVisibleArea(in: scrollView)
        textView.needsDisplay = true
        ruler.needsDisplay = true
    }

    func load(document: TextDocument, theme: EditorTheme, softWrap: Bool, fontSize: CGFloat) {
        let switched = self.document?.id != document.id
        let fontChanged = abs(self.fontSize - fontSize) > 0.01
        self.document = document
        self.theme = theme
        self.fontSize = fontSize
        applyThemeColors()
        setSoftWrap(softWrap)
        if fontChanged {
            applyFontToStorage()
        }

        if switched || textView.string != document.content {
            isUpdating = true
            textView.string = document.content
            isUpdating = false
            applyHighlight()
            if switched {
                if document.content.isEmpty {
                    textView.setSelectedRange(NSRange(location: 0, length: 0))
                    updateCursorLocation()
                } else {
                    restoreCursor(line: document.cursorLine, column: document.cursorColumn)
                }
            } else {
                updateCursorLocation()
            }
        } else {
            applyHighlight()
        }
        textView.ensureFillsVisibleArea(in: scrollView)
    }

    private func applyFontToStorage() {
        textView.font = font
        ruler.fontSize = fontSize
        let thickness = max(36, ceil(fontSize * 2.8))
        ruler.ruleThickness = thickness
    }

    private func restoreCursor(line: Int, column: Int) {
        let ns = textView.string as NSString
        guard ns.length > 0 else {
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            updateCursorLocation()
            return
        }
        var current = 1
        var idx = 0
        while idx < ns.length {
            let range = ns.lineRange(for: NSRange(location: idx, length: 0))
            if current == line {
                let col = max(1, column)
                let offset = min(col - 1, max(0, range.length - (range.length > 0 && ns.substring(with: range).hasSuffix("\n") ? 1 : 0)))
                let location = min(range.location + offset, ns.length)
                textView.setSelectedRange(NSRange(location: location, length: 0))
                textView.scrollRangeToVisible(NSRange(location: location, length: 0))
                updateCursorLocation()
                return
            }
            let next = NSMaxRange(range)
            if next <= idx { break }
            idx = next
            current += 1
        }
        textView.setSelectedRange(NSRange(location: ns.length, length: 0))
        updateCursorLocation()
    }

    func applyTheme() {
        applyThemeColors()
        applyHighlight()
    }

    private func applyThemeColors() {
        textView.theme = theme
        textView.backgroundColor = theme.background
        textView.insertionPointColor = theme.caret
        textView.textColor = theme.foreground
        textView.font = font
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: theme.foreground
        ]
        textView.selectedTextAttributes = [
            .backgroundColor: theme.selection,
            .foregroundColor: theme.foreground
        ]
        scrollView.backgroundColor = theme.background
        ruler.theme = theme
        ruler.fontSize = fontSize
        textView.needsDisplay = true
    }

    func setSoftWrap(_ enabled: Bool) {
        softWrap = enabled
        textView.isHorizontallyResizable = !enabled
        textView.textContainer?.widthTracksTextView = enabled
        if enabled {
            let width = max(scrollView.contentSize.width, 100)
            textView.textContainer?.containerSize = NSSize(
                width: width,
                height: CGFloat.greatestFiniteMagnitude
            )
            var frame = textView.frame
            frame.size.width = width
            textView.frame = frame
        } else {
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        }
        ruler.needsDisplay = true
    }

    func textDidChange(_ notification: Notification) {
        guard !isUpdating, let document else { return }
        // While the IME is composing (pinyin marked text), do not rewrite
        // attributes — that aborts composition and leaves raw Latin letters.
        // Still sync the model + schedule session backup so quit mid-IME keeps text.
        if textView.hasMarkedText() {
            document.updateContent(textView.string)
            updateCursorLocation()
            ruler.needsDisplay = true
            DocumentStore.shared.documentContentDidChange()
            return
        }
        document.updateContent(textView.string)
        updateCursorLocation()
        scheduleHighlight()
        ruler.needsDisplay = true
        DocumentStore.shared.documentContentDidChange()
    }

    @objc private func selectionDidChange() {
        guard !isUpdating else { return }
        // Avoid fighting the IME while candidates / marked text are active.
        if textView.hasMarkedText() {
            textView.needsDisplay = true
            return
        }
        updateCursorLocation()
        textView.needsDisplay = true
        ruler.needsDisplay = true
        DocumentStore.shared.cursorDidChange()
    }

    private func updateCursorLocation() {
        guard let document else { return }
        let loc = min(textView.selectedRange().location, (textView.string as NSString).length)
        let prefix = (textView.string as NSString).substring(to: loc)
        let lines = prefix.components(separatedBy: "\n")
        document.cursorLine = lines.count
        document.cursorColumn = (lines.last?.count ?? 0) + 1
    }

    private func scheduleHighlight(delay: TimeInterval = 0.12) {
        highlightWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.applyHighlight()
        }
        highlightWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func applyHighlight() {
        guard let document else { return }
        // Critical for Chinese/Japanese/Korean IMEs: replacing the text storage
        // while marked text exists commits raw pinyin into the buffer.
        if textView.hasMarkedText() {
            scheduleHighlight(delay: 0.2)
            return
        }

        let selected = textView.selectedRange()

        let attributed: NSAttributedString
        if document.enableHighlight,
           (document.content.utf8.count) <= TextFileLoader.highlightLimitBytes {
            attributed = SyntaxHighlighter.highlight(
                text: textView.string,
                language: document.language,
                theme: theme,
                font: font
            )
        } else {
            attributed = NSAttributedString(string: textView.string, attributes: [
                .font: font,
                .foregroundColor: theme.foreground
            ])
        }

        guard let storage = textView.textStorage else { return }
        isUpdating = true
        storage.beginEditing()
        if storage.string == attributed.string {
            // In-place attribute update — gentler on the input context than a full replace.
            let full = NSRange(location: 0, length: storage.length)
            attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length)) { attrs, range, _ in
                storage.setAttributes(attrs, range: range)
            }
            _ = full
        } else {
            storage.setAttributedString(attributed)
        }
        storage.endEditing()
        let length = storage.length
        let loc = min(selected.location, length)
        let len = min(selected.length, max(0, length - loc))
        textView.setSelectedRange(NSRange(location: loc, length: len))
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: theme.foreground
        ]
        isUpdating = false
        ruler.needsDisplay = true
    }

    @objc private func handleFindNext(_ note: Notification) {
        let query = (note.userInfo?["query"] as? String) ?? DocumentStore.shared.findQuery
        let forward = (note.userInfo?["forward"] as? Bool) ?? true
        let incremental = (note.userInfo?["incremental"] as? Bool) ?? false
        find(query: query, forward: forward, incremental: incremental)
    }

    @objc private func handleReplaceOne(_ note: Notification) {
        let find = (note.userInfo?["find"] as? String) ?? DocumentStore.shared.findQuery
        let replace = (note.userInfo?["replace"] as? String) ?? DocumentStore.shared.replaceQuery
        replaceOne(find: find, replace: replace)
    }

    @objc private func handleReplaceAll(_ note: Notification) {
        let find = (note.userInfo?["find"] as? String) ?? DocumentStore.shared.findQuery
        let replace = (note.userInfo?["replace"] as? String) ?? DocumentStore.shared.replaceQuery
        replaceAll(find: find, replace: replace)
    }

    @objc private func handleGoToLine(_ note: Notification) {
        guard let line = note.userInfo?["line"] as? Int else { return }
        goToLine(line)
    }

    func find(query: String, forward: Bool, incremental: Bool = false) {
        guard !query.isEmpty else { return }
        let ns = textView.string as NSString
        let full = NSRange(location: 0, length: ns.length)
        let selected = textView.selectedRange()
        var options: NSString.CompareOptions = [.caseInsensitive]
        let searchRange: NSRange
        if forward {
            // Incremental (type/paste in find bar): include current selection start so
            // replacing the query still lands on the first match under/near the caret.
            let start = incremental ? selected.location : selected.location + selected.length
            searchRange = NSRange(location: start, length: max(0, ns.length - start))
        } else {
            options.insert(.backwards)
            searchRange = NSRange(location: 0, length: selected.location)
        }
        var found = ns.range(of: query, options: options, range: searchRange)
        if found.location == NSNotFound {
            found = ns.range(of: query, options: options, range: full)
        }
        if found.location != NSNotFound {
            // Keep focus in the find field while typing/pasting; only jump focus for ⌘G / Enter Next.
            let keepFindFocus = incremental || findBarOwnsFocus()
            if !keepFindFocus {
                textView.window?.makeFirstResponder(textView)
            }
            textView.setSelectedRange(found)
            textView.scrollRangeToVisible(found)
        }
    }

    private func findBarOwnsFocus() -> Bool {
        guard let responder = textView.window?.firstResponder else { return false }
        if responder is NSTextView, let fieldEditor = responder as? NSTextView,
           fieldEditor.delegate is NSTextField {
            // Field editor of an NSTextField (find/replace).
            return true
        }
        return responder is NSTextField
    }

    func replaceOne(find: String, replace: String) {
        guard !find.isEmpty else { return }
        let selected = textView.selectedRange()
        let ns = textView.string as NSString
        if selected.length > 0,
           ns.substring(with: selected).caseInsensitiveCompare(find) == .orderedSame {
            if textView.shouldChangeText(in: selected, replacementString: replace) {
                textView.replaceCharacters(in: selected, with: replace)
                textView.didChangeText()
            }
        }
        self.find(query: find, forward: true)
    }

    func replaceAll(find: String, replace: String) {
        guard !find.isEmpty else { return }
        let ns = textView.string as NSString
        var searchRange = NSRange(location: 0, length: ns.length)
        var ranges: [NSRange] = []
        while true {
            let found = ns.range(of: find, options: [.caseInsensitive], range: searchRange)
            if found.location == NSNotFound { break }
            ranges.append(found)
            let next = found.location + max(found.length, 1)
            if next >= ns.length { break }
            searchRange = NSRange(location: next, length: ns.length - next)
        }
        guard !ranges.isEmpty else { return }
        textView.undoManager?.beginUndoGrouping()
        for range in ranges.reversed() {
            if textView.shouldChangeText(in: range, replacementString: replace) {
                textView.replaceCharacters(in: range, with: replace)
                textView.didChangeText()
            }
        }
        textView.undoManager?.endUndoGrouping()
        document?.updateContent(textView.string)
        applyHighlight()
        DocumentStore.shared.documentContentDidChange()
    }

    func goToLine(_ line: Int) {
        guard line > 0 else { return }
        let ns = textView.string as NSString
        var current = 1
        var idx = 0
        while idx <= ns.length {
            let safeIdx = min(idx, max(0, ns.length - (ns.length > 0 ? 1 : 0)))
            let range = ns.lineRange(for: NSRange(location: safeIdx, length: 0))
            if current == line {
                textView.window?.makeFirstResponder(textView)
                textView.setSelectedRange(NSRange(location: range.location, length: 0))
                textView.scrollRangeToVisible(range)
                updateCursorLocation()
                DocumentStore.shared.documentContentDidChange()
                return
            }
            let next = NSMaxRange(range)
            if next <= idx { break }
            idx = next
            current += 1
            if idx >= ns.length {
                if current == line {
                    textView.setSelectedRange(NSRange(location: ns.length, length: 0))
                    textView.scrollRangeToVisible(NSRange(location: ns.length, length: 0))
                    updateCursorLocation()
                    DocumentStore.shared.documentContentDidChange()
                }
                return
            }
        }
    }

    func focus() {
        textView.window?.makeFirstResponder(textView)
    }

    /// Push the live text view buffer into the document model (including IME marked text).
    func flushToDocument() {
        guard let document else { return }
        document.updateContent(textView.string)
        updateCursorLocation()
    }
}
