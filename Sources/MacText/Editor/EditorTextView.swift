import AppKit

/// Sublime-like editor text view: fills blank area, current-line highlight, click-anywhere to type.
final class EditorTextView: NSTextView {
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
}
