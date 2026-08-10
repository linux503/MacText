import AppKit

final class TabBarView: NSView {
    var onSelect: ((UUID) -> Void)?
    var onClose: ((UUID) -> Void)?
    var onToggleSidebar: (() -> Void)?
    var onNewFile: (() -> Void)?
    var onCloseOthers: ((UUID) -> Void)?

    private let sidebarButton = NSButton(frame: .zero)
    private let newFileButton = NSButton(frame: .zero)
    private var tabEndX: CGFloat = 44
    private var selectedID: UUID?
    private var documents: [TextDocument] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        configureChromeButtons()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureChromeButtons() {
        for button in [sidebarButton, newFileButton] {
            button.bezelStyle = .inline
            button.isBordered = false
            button.imagePosition = .imageOnly
            addSubview(button)
        }
        sidebarButton.target = self
        sidebarButton.action = #selector(toggleSidebar)
        sidebarButton.toolTip = "Toggle Sidebar (⌘B)"

        newFileButton.target = self
        newFileButton.action = #selector(newFile)
        newFileButton.toolTip = "New File (⌘N) — or double-click empty tab bar"
        newFileButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "New File")
        newFileButton.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            let local = convert(event.locationInWindow, from: nil)
            // Sublime: double-click empty tab strip → new file
            if local.x >= tabEndX && local.x < newFileButton.frame.minX - 4 {
                onNewFile?()
                return
            }
        }
        super.mouseDown(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        let local = convert(event.locationInWindow, from: nil)
        let menu = NSMenu()

        let newItem = NSMenuItem(title: "New File", action: #selector(newFile), keyEquivalent: "n")
        newItem.keyEquivalentModifierMask = .command
        newItem.target = self
        menu.addItem(newItem)
        menu.addItem(NSMenuItem.separator())

        if let doc = documentAt(x: local.x) {
            let close = NSMenuItem(title: "Close", action: #selector(contextClose(_:)), keyEquivalent: "w")
            close.keyEquivalentModifierMask = .command
            close.target = self
            close.representedObject = doc.id
            menu.addItem(close)

            let closeOthers = NSMenuItem(title: "Close Others", action: #selector(contextCloseOthers(_:)), keyEquivalent: "")
            closeOthers.target = self
            closeOthers.representedObject = doc.id
            menu.addItem(closeOthers)
        } else {
            let closeCurrent = NSMenuItem(title: "Close Tab", action: #selector(closeCurrentTab), keyEquivalent: "w")
            closeCurrent.keyEquivalentModifierMask = .command
            closeCurrent.target = self
            menu.addItem(closeCurrent)
        }

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    override func otherMouseDown(with event: NSEvent) {
        // Sublime: middle-click tab → close
        guard event.buttonNumber == 2 else {
            super.otherMouseDown(with: event)
            return
        }
        let local = convert(event.locationInWindow, from: nil)
        if let doc = documentAt(x: local.x) {
            onClose?(doc.id)
        }
    }

    func updateTitles(documents: [TextDocument], selectedID: UUID?) {
        self.documents = documents
        self.selectedID = selectedID
        let tabButtons = subviews.compactMap { $0 as? NSButton }.filter { $0.action == #selector(selectTab(_:)) }
        guard tabButtons.count == documents.count else { return }
        for (idx, doc) in documents.enumerated() {
            tabButtons[idx].title = "  " + doc.displayTitle
        }
    }

    func reload(documents: [TextDocument], selectedID: UUID?, theme: EditorTheme, showSidebar: Bool) {
        self.documents = documents
        self.selectedID = selectedID

        let keep: Set<ObjectIdentifier> = [ObjectIdentifier(sidebarButton), ObjectIdentifier(newFileButton)]
        subviews.forEach { view in
            if !keep.contains(ObjectIdentifier(view)) {
                view.removeFromSuperview()
            }
        }
        if sidebarButton.superview == nil { addSubview(sidebarButton) }
        if newFileButton.superview == nil { addSubview(newFileButton) }

        wantsLayer = true
        layer?.backgroundColor = theme.editorChrome.cgColor

        sidebarButton.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: "Toggle Sidebar")
        sidebarButton.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        sidebarButton.contentTintColor = showSidebar ? theme.accent : theme.lineNumber
        sidebarButton.frame = NSRect(x: 6, y: 4, width: 28, height: 24)
        sidebarButton.toolTip = showSidebar ? "Hide Sidebar (⌘B)" : "Show Sidebar (⌘B)"

        let bottomRule = NSView(frame: NSRect(x: 0, y: 0, width: 10000, height: 1))
        bottomRule.wantsLayer = true
        bottomRule.layer?.backgroundColor = theme.divider.cgColor
        addSubview(bottomRule)

        let leadingDivider = NSView(frame: NSRect(x: 38, y: 8, width: 1, height: 16))
        leadingDivider.wantsLayer = true
        leadingDivider.layer?.backgroundColor = theme.divider.cgColor
        addSubview(leadingDivider)

        var x: CGFloat = 44
        for doc in documents {
            let selected = doc.id == selectedID
            let width: CGFloat = 148

            let tab = NSButton(frame: NSRect(x: x, y: 1, width: width, height: 31))
            tab.title = "  " + doc.displayTitle
            tab.bezelStyle = .shadowlessSquare
            tab.isBordered = false
            tab.font = NSFont.systemFont(ofSize: 12, weight: selected ? .medium : .regular)
            tab.alignment = .left
            tab.contentTintColor = selected ? theme.foreground : theme.lineNumber
            tab.wantsLayer = true
            tab.layer?.backgroundColor = (selected ? theme.tabActive : theme.tabInactive).cgColor
            tab.target = self
            tab.action = #selector(selectTab(_:))
            tab.identifier = NSUserInterfaceItemIdentifier(doc.id.uuidString)
            addSubview(tab)

            let close = NSButton(frame: NSRect(x: x + width - 22, y: 9, width: 14, height: 14))
            close.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")
            close.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 9, weight: .semibold)
            close.imagePosition = .imageOnly
            close.isBordered = false
            close.bezelStyle = .inline
            close.contentTintColor = theme.lineNumber
            close.target = self
            close.action = #selector(closeTab(_:))
            close.identifier = NSUserInterfaceItemIdentifier(doc.id.uuidString)
            addSubview(close)

            if selected {
                let accent = NSView(frame: NSRect(x: x + 10, y: 0, width: width - 20, height: 2))
                accent.wantsLayer = true
                accent.layer?.backgroundColor = theme.accent.cgColor
                accent.layer?.cornerRadius = 1
                addSubview(accent)
            }

            let divider = NSView(frame: NSRect(x: x + width - 1, y: 8, width: 1, height: 16))
            divider.wantsLayer = true
            divider.layer?.backgroundColor = theme.divider.cgColor
            addSubview(divider)

            x += width
        }

        tabEndX = x
        newFileButton.contentTintColor = theme.lineNumber
        newFileButton.frame = NSRect(x: max(x + 6, 50), y: 5, width: 22, height: 22)
    }

    private func documentAt(x: CGFloat) -> TextDocument? {
        guard x >= 44 else { return nil }
        let index = Int((x - 44) / 148)
        guard index >= 0, index < documents.count else { return nil }
        let start = 44 + CGFloat(index) * 148
        if x >= start && x < start + 148 {
            return documents[index]
        }
        return nil
    }

    @objc private func toggleSidebar() {
        onToggleSidebar?()
    }

    @objc private func newFile() {
        onNewFile?()
    }

    @objc private func closeCurrentTab() {
        if let id = selectedID {
            onClose?(id)
        }
    }

    @objc private func contextClose(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        onClose?(id)
    }

    @objc private func contextCloseOthers(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        onCloseOthers?(id)
    }

    @objc private func selectTab(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let id = UUID(uuidString: raw) else { return }
        onSelect?(id)
    }

    @objc private func closeTab(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let id = UUID(uuidString: raw) else { return }
        onClose?(id)
    }
}
