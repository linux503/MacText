import AppKit

final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    var theme: EditorTheme = .ink {
        didSet { needsDisplay = true }
    }

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 44
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        theme.lineNumberBackground.setFill()
        bounds.fill()

        let border = NSBezierPath()
        border.move(to: NSPoint(x: bounds.maxX - 0.5, y: bounds.minY))
        border.line(to: NSPoint(x: bounds.maxX - 0.5, y: bounds.maxY))
        theme.gutterBorder.setStroke()
        border.lineWidth = 1
        border.stroke()

        let visibleRect = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        var glyphIndex = glyphRange.location

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: theme.lineNumber
        ]

        while glyphIndex < NSMaxRange(glyphRange) {
            var lineRange = NSRange()
            let lineRect = layoutManager.lineFragmentRect(
                forGlyphAt: glyphIndex,
                effectiveRange: &lineRange
            )
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
            let text = textView.string as NSString
            let lineNumber = text.lineNumber(for: charIndex)

            let label = "\(lineNumber)" as NSString
            let size = label.size(withAttributes: attrs)
            let x = bounds.width - size.width - 8
            let y = lineRect.minY + textView.textContainerInset.height - visibleRect.minY
                + (lineRect.height - size.height) / 2
            label.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)

            glyphIndex = NSMaxRange(lineRange)
        }
    }
}

private extension NSString {
    func lineNumber(for location: Int) -> Int {
        var line = 1
        var idx = 0
        while idx < location && idx < length {
            let range = lineRange(for: NSRange(location: idx, length: 0))
            if NSLocationInRange(location, range) || location == range.location {
                return line
            }
            idx = NSMaxRange(range)
            line += 1
        }
        return line
    }
}
