import AppKit

extension NSPasteboard.PasteboardType {
    static let macTextTab = NSPasteboard.PasteboardType("com.mactext.tab")
}

final class TabBarView: NSView, NSDraggingSource {
    var onSelect: ((UUID) -> Void)?
    var onClose: ((UUID) -> Void)?
    var onToggleSidebar: (() -> Void)?
    var onNewFile: (() -> Void)?
    var onCloseOthers: ((UUID) -> Void)?
    var onDetach: ((UUID, NSPoint) -> Void)?
    var onReorder: ((UUID, Int) -> Void)?
    var onAcceptDrop: ((UUID, Int?) -> Bool)?
    weak var windowOwner: MainWindowController?

    private let sidebarButton = NSButton(frame: .zero)
    private let newFileButton = NSButton(frame: .zero)
    private var tabEndX: CGFloat = 44
    private var selectedID: UUID?
    private var documents: [TextDocument] = []
    private var dragDocumentID: UUID?
    private var dragStartPoint: NSPoint = .zero
    private var didDrag = false
    private var dropIndex: Int?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        registerForDraggedTypes([.macTextTab, .string])
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
        sidebarButton.toolTip = L10n.toggleSidebar + " (⌘B)"

        newFileButton.target = self
        newFileButton.action = #selector(newFile)
        newFileButton.toolTip = L10n.newFile + " (⌘N)"
        newFileButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: L10n.newFile)
        newFileButton.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
    }

    override func mouseDown(with event: NSEvent) {
        let local = convert(event.locationInWindow, from: nil)
        if event.clickCount == 2 {
            if local.x >= tabEndX && local.x < newFileButton.frame.minX - 4 {
                onNewFile?()
                return
            }
        }
        if let doc = documentAt(x: local.x),
           !isPointOnCloseButton(local, documentID: doc.id) {
            dragDocumentID = doc.id
            dragStartPoint = local
            didDrag = false
            onSelect?(doc.id)
            return
        }
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let id = dragDocumentID else {
            super.mouseDragged(with: event)
            return
        }
        let local = convert(event.locationInWindow, from: nil)
        let distance = hypot(local.x - dragStartPoint.x, local.y - dragStartPoint.y)
        guard distance > 4 else { return }
        didDrag = true

        let pb = NSPasteboardItem()
        pb.setString(id.uuidString, forType: .macTextTab)
        pb.setString(id.uuidString, forType: .string)
        let item = NSDraggingItem(pasteboardWriter: pb)
        let tabRect = tabFrame(for: id) ?? NSRect(x: local.x - 60, y: 0, width: 148, height: 32)
        item.setDraggingFrame(tabRect, contents: snapshotTab(id: id))

        let session = beginDraggingSession(with: [item], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        dragDocumentID = nil
    }

    override func mouseUp(with event: NSEvent) {
        dragDocumentID = nil
        didDrag = false
        super.mouseUp(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        let local = convert(event.locationInWindow, from: nil)
        let menu = NSMenu()

        let newItem = NSMenuItem(title: L10n.newFile, action: #selector(newFile), keyEquivalent: "n")
        newItem.keyEquivalentModifierMask = .command
        newItem.target = self
        menu.addItem(newItem)
        menu.addItem(NSMenuItem.separator())

        if let doc = documentAt(x: local.x) {
            let close = NSMenuItem(title: L10n.close, action: #selector(contextClose(_:)), keyEquivalent: "w")
            close.keyEquivalentModifierMask = .command
            close.target = self
            close.representedObject = doc.id
            menu.addItem(close)

            let closeOthers = NSMenuItem(title: L10n.closeOthers, action: #selector(contextCloseOthers(_:)), keyEquivalent: "")
            closeOthers.target = self
            closeOthers.representedObject = doc.id
            menu.addItem(closeOthers)
        } else {
            let closeCurrent = NSMenuItem(title: L10n.closeTab, action: #selector(closeCurrentTab), keyEquivalent: "w")
            closeCurrent.keyEquivalentModifierMask = .command
            closeCurrent.target = self
            menu.addItem(closeCurrent)
        }

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    override func otherMouseDown(with event: NSEvent) {
        guard event.buttonNumber == 2 else {
            super.otherMouseDown(with: event)
            return
        }
        let local = convert(event.locationInWindow, from: nil)
        if let doc = documentAt(x: local.x) {
            onClose?(doc.id)
        }
    }

    // MARK: - Dragging source

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .move
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        defer { dropIndex = nil; needsDisplay = true }
        guard let raw = session.draggingPasteboard.string(forType: .string)
                ?? session.draggingPasteboard.string(forType: .macTextTab),
              let id = UUID(uuidString: raw) else { return }

        if operation.isEmpty {
            // Dropped outside any accepting tab bar → tear off new window.
            var outside = true
            for window in WindowManager.shared.windows {
                if let frame = window.window?.frame, frame.contains(screenPoint) {
                    outside = false
                    break
                }
            }
            if outside {
                onDetach?(id, screenPoint)
            }
        }
    }

    // MARK: - Dragging destination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        updateDropIndex(sender)
        return .move
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        updateDropIndex(sender)
        return .move
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        dropIndex = nil
        needsDisplay = true
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let raw = sender.draggingPasteboard.string(forType: .string)
                ?? sender.draggingPasteboard.string(forType: .macTextTab),
              let id = UUID(uuidString: raw) else { return false }
        let index = dropIndex
        dropIndex = nil
        needsDisplay = true
        return onAcceptDrop?(id, index) ?? false
    }

    private func updateDropIndex(_ sender: NSDraggingInfo) {
        let local = convert(sender.draggingLocation, from: nil)
        if local.x < 44 {
            dropIndex = 0
        } else {
            let idx = Int((local.x - 44) / 148)
            dropIndex = min(max(0, idx), documents.count)
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if let dropIndex {
            let x = 44 + CGFloat(dropIndex) * 148
            NSColor.controlAccentColor.setFill()
            NSRect(x: x - 1, y: 2, width: 2, height: bounds.height - 4).fill()
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

        sidebarButton.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: L10n.toggleSidebar)
        sidebarButton.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        sidebarButton.contentTintColor = showSidebar ? theme.accent : theme.lineNumber
        sidebarButton.frame = NSRect(x: 6, y: 4, width: 28, height: 24)
        sidebarButton.toolTip = (showSidebar ? L10n.hideSidebar : L10n.showSidebar) + " (⌘B)"

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

            let tab = TabChromeButton(frame: NSRect(x: x, y: 1, width: width, height: 31))
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
            close.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: L10n.close)
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

    private func tabFrame(for id: UUID) -> NSRect? {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return nil }
        return NSRect(x: 44 + CGFloat(index) * 148, y: 1, width: 148, height: 31)
    }

    private func isPointOnCloseButton(_ point: NSPoint, documentID: UUID) -> Bool {
        guard let frame = tabFrame(for: documentID) else { return false }
        let close = NSRect(x: frame.maxX - 22, y: 9, width: 14, height: 14)
        return close.contains(point)
    }

    private func snapshotTab(id: UUID) -> NSImage {
        let size = NSSize(width: 148, height: 31)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.windowBackgroundColor.setFill()
        NSRect(origin: .zero, size: size).fill()
        let title = documents.first(where: { $0.id == id })?.displayTitle ?? "Tab"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.labelColor
        ]
        (title as NSString).draw(at: NSPoint(x: 10, y: 8), withAttributes: attrs)
        image.unlockFocus()
        return image
    }

    @objc private func toggleSidebar() { onToggleSidebar?() }
    @objc private func newFile() { onNewFile?() }

    @objc private func closeCurrentTab() {
        if let id = selectedID { onClose?(id) }
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

/// Forwards press/drag to the tab bar so tabs can be torn off like Sublime.
private final class TabChromeButton: NSButton {
    override func mouseDown(with event: NSEvent) {
        superview?.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        superview?.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        superview?.mouseUp(with: event)
    }
}
