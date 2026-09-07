import AppKit

final class FindBarView: NSView, NSTextFieldDelegate {
    private let findField = NSTextField(string: "")
    private let replaceField = NSTextField(string: "")
    private let previousButton = NSButton(title: L10n.findPreviousShort, target: nil, action: nil)
    private let nextButton = NSButton(title: L10n.findNextShort, target: nil, action: nil)
    private let replaceButton = NSButton(title: L10n.replaceOneShort, target: nil, action: nil)
    private let replaceAllButton = NSButton(title: L10n.replaceAllShort, target: nil, action: nil)
    private let closeButton = NSButton(image: NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")!, target: nil, action: nil)
    private let replaceRow = NSStackView()
    private var flashToken = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        configure()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFindResult(_:)),
            name: .macTextFindResult,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configure() {
        findField.placeholderString = L10n.findPlaceholder
        findField.font = NSFont.systemFont(ofSize: 13)
        findField.delegate = self
        findField.target = self
        findField.action = #selector(findSubmitted)

        replaceField.placeholderString = L10n.replacePlaceholder
        replaceField.font = NSFont.systemFont(ofSize: 13)
        replaceField.delegate = self
        replaceField.target = self
        replaceField.action = #selector(replaceSubmitted)

        for button in [previousButton, nextButton, replaceButton, replaceAllButton] {
            button.bezelStyle = .rounded
            button.controlSize = .small
            button.target = self
        }
        previousButton.action = #selector(findPrevious)
        nextButton.action = #selector(findNext)
        replaceButton.action = #selector(replaceOne)
        replaceAllButton.action = #selector(replaceAll)

        closeButton.isBordered = false
        closeButton.bezelStyle = .inline
        closeButton.target = self
        closeButton.action = #selector(closeBar)

        let findRow = NSStackView(views: [
            makeIcon("magnifyingglass"),
            findField,
            previousButton,
            nextButton,
            closeButton
        ])
        findRow.orientation = .horizontal
        findRow.spacing = 8
        findRow.alignment = .centerY
        findField.setContentHuggingPriority(.defaultLow, for: .horizontal)

        replaceRow.orientation = .horizontal
        replaceRow.spacing = 8
        replaceRow.alignment = .centerY
        replaceRow.addArrangedSubview(makeIcon("arrow.triangle.2.circlepath"))
        replaceRow.addArrangedSubview(replaceField)
        replaceRow.addArrangedSubview(replaceButton)
        replaceRow.addArrangedSubview(replaceAllButton)
        replaceField.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let stack = NSStackView(views: [findRow, replaceRow])
        stack.orientation = .vertical
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func makeIcon(_ name: String) -> NSImageView {
        let view = NSImageView(image: NSImage(systemSymbolName: name, accessibilityDescription: nil)!)
        view.contentTintColor = .secondaryLabelColor
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: 16).isActive = true
        return view
    }

    func apply(theme: EditorTheme, showReplace: Bool, query: String, replace: String) {
        layer?.backgroundColor = theme.findBarBackground.cgColor
        replaceRow.isHidden = !showReplace
        previousButton.title = L10n.findPreviousShort
        nextButton.title = L10n.findNextShort
        replaceButton.title = L10n.replaceOneShort
        replaceAllButton.title = L10n.replaceAllShort
        findField.placeholderString = L10n.findPlaceholder
        replaceField.placeholderString = L10n.replacePlaceholder
        if findField.stringValue != query {
            findField.stringValue = query
        }
        if replaceField.stringValue != replace {
            replaceField.stringValue = replace
        }
    }

    func focusFind() {
        window?.makeFirstResponder(findField)
        findField.selectText(nil)
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        if field === findField {
            DocumentStore.shared.findQuery = field.stringValue
            // Live find on type/paste — keep caret in the find field.
            DocumentStore.shared.requestFindNext(forward: true, incremental: true)
        } else if field === replaceField {
            DocumentStore.shared.replaceQuery = field.stringValue
        }
    }

    override func cancelOperation(_ sender: Any?) {
        closeBar()
    }

    @objc private func handleFindResult(_ note: Notification) {
        guard note.object as? NSWindow === window || note.object == nil else { return }
        let found = (note.userInfo?["found"] as? Bool) ?? true
        if found {
            findField.layer?.backgroundColor = nil
            return
        }
        flashNoMatch()
    }

    private func flashNoMatch() {
        findField.wantsLayer = true
        findField.layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.28).cgColor
        findField.toolTip = L10n.findNoMatches
        flashToken += 1
        let token = flashToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            guard let self, self.flashToken == token else { return }
            self.findField.layer?.backgroundColor = nil
            self.findField.toolTip = nil
        }
        NSSound.beep()
    }

    @objc private func findSubmitted() {
        DocumentStore.shared.findQuery = findField.stringValue
        DocumentStore.shared.requestFindNext(forward: true)
    }

    @objc private func replaceSubmitted() {
        DocumentStore.shared.replaceQuery = replaceField.stringValue
        DocumentStore.shared.requestReplaceOne()
    }

    @objc private func findPrevious() {
        DocumentStore.shared.findQuery = findField.stringValue
        DocumentStore.shared.requestFindNext(forward: false)
    }

    @objc private func findNext() {
        DocumentStore.shared.findQuery = findField.stringValue
        DocumentStore.shared.requestFindNext(forward: true)
    }

    @objc private func replaceOne() {
        DocumentStore.shared.findQuery = findField.stringValue
        DocumentStore.shared.replaceQuery = replaceField.stringValue
        DocumentStore.shared.requestReplaceOne()
    }

    @objc private func replaceAll() {
        DocumentStore.shared.findQuery = findField.stringValue
        DocumentStore.shared.replaceQuery = replaceField.stringValue
        DocumentStore.shared.requestReplaceAll()
    }

    @objc private func closeBar() {
        DocumentStore.shared.showFindBar = false
        DocumentStore.shared.showReplace = false
        DocumentStore.shared.notify()
    }
}
