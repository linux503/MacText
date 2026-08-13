import AppKit

final class MainWindowController: NSWindowController, NSWindowDelegate, NSSplitViewDelegate {
    private let store = DocumentStore.shared
    private let splitView = NSSplitView()
    private let sidebar = SidebarController()
    private let editor = EditorController()
    private let tabBar = TabBarView(frame: .zero)
    private let findBar = FindBarView(frame: .zero)
    private let statusBar = StatusBarView(frame: .zero)
    private let editorColumn = NSView()
    private let commandPalette = CommandPaletteController()
    private var findHeightConstraint: NSLayoutConstraint!
    private var sidebarWidth: CGFloat = 220
    private let isPrimary: Bool

    private(set) var tabIDs: [UUID]
    private(set) var selectedTabID: UUID?

    var tabDocuments: [TextDocument] {
        tabIDs.compactMap { store.document(id: $0) }
    }

    var selectedDocument: TextDocument? {
        if let selectedTabID, let doc = store.document(id: selectedTabID) { return doc }
        return tabDocuments.first
    }

    convenience init() {
        self.init(tabIDs: [], selectedID: nil, savedFrame: nil, cascadeOrigin: nil, isPrimary: true)
    }

    init(tabIDs: [UUID], selectedID: UUID?, savedFrame: NSRect?, cascadeOrigin: NSPoint?, isPrimary: Bool) {
        self.tabIDs = tabIDs
        self.selectedTabID = selectedID ?? tabIDs.first
        self.isPrimary = isPrimary

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 740),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "MacText"
        window.minSize = NSSize(width: 720, height: 480)

        if let saved = savedFrame,
           saved.width >= 720, saved.height >= 480,
           NSScreen.screens.contains(where: { $0.visibleFrame.intersects(saved) }) {
            window.setFrame(saved, display: false)
        } else if let origin = cascadeOrigin {
            var frame = window.frame
            frame.origin = origin
            // Keep on-screen
            if let screen = NSScreen.screens.first(where: { $0.frame.contains(origin) }) ?? NSScreen.main {
                let vis = screen.visibleFrame
                frame.origin.x = min(max(frame.origin.x, vis.minX), vis.maxX - 200)
                frame.origin.y = min(max(frame.origin.y - frame.height, vis.minY), vis.maxY - 100)
            }
            window.setFrame(frame, display: false)
        } else {
            window.center()
        }

        window.titlebarAppearsTransparent = true
        window.backgroundColor = DocumentStore.shared.theme.sidebarBackground
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self

        if self.tabIDs.isEmpty {
            let doc = store.makeUntitledDocument()
            self.tabIDs = [doc.id]
            self.selectedTabID = doc.id
        }

        buildUI()
        observe()
        reload(full: true)
        DispatchQueue.main.async { [weak self] in
            self?.editor.focus()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func selectTab(_ id: UUID) {
        guard tabIDs.contains(id) else { return }
        flushEditorToDocument()
        selectedTabID = id
        store.syncActiveSelection(id)
        reload(full: true)
        editor.focus()
    }

    func flushEditorToDocument() {
        editor.flushToDocument()
    }

    func insertTab(_ id: UUID, at index: Int?) {
        guard !tabIDs.contains(id) else {
            selectTab(id)
            return
        }
        if let index, index >= 0, index <= tabIDs.count {
            tabIDs.insert(id, at: index)
        } else {
            tabIDs.append(id)
        }
        selectedTabID = id
        reload(full: true)
    }

    func reorderTab(_ id: UUID, to index: Int) {
        guard let from = tabIDs.firstIndex(of: id) else { return }
        var ids = tabIDs
        ids.remove(at: from)
        let clamped = min(max(0, index), ids.count)
        ids.insert(id, at: clamped)
        tabIDs = ids
        selectedTabID = id
        reload(full: true)
    }

    /// Remove tab from this window. Optionally close the window if empty.
    func removeTab(_ id: UUID, destroyIfEmpty: Bool) {
        guard let idx = tabIDs.firstIndex(of: id) else { return }
        tabIDs.remove(at: idx)
        if selectedTabID == id {
            if tabIDs.isEmpty {
                selectedTabID = nil
            } else {
                selectedTabID = tabIDs[min(idx, tabIDs.count - 1)]
            }
        }
        if tabIDs.isEmpty {
            if destroyIfEmpty {
                window?.close()
            } else {
                let doc = store.makeUntitledDocument()
                tabIDs = [doc.id]
                selectedTabID = doc.id
                reload(full: true)
            }
        } else {
            if let selectedTabID {
                store.syncActiveSelection(selectedTabID)
            }
            reload(full: true)
        }
    }

    func addNewUntitled() {
        let doc = store.makeUntitledDocument()
        tabIDs.append(doc.id)
        selectedTabID = doc.id
        store.syncActiveSelection(doc.id)
        store.notify()
        reload(full: true)
        editor.focus()
    }

    func openURLs(_ urls: [URL]) {
        for url in urls {
            if let existing = store.document(fileURL: url) {
                if let host = WindowManager.shared.window(containing: existing.id), host !== self {
                    WindowManager.shared.moveTab(existing.id, from: host, to: self, at: nil)
                } else if !tabIDs.contains(existing.id) {
                    insertTab(existing.id, at: nil)
                } else {
                    selectTab(existing.id)
                }
            } else if let doc = store.loadFileDocument(url) {
                insertTab(doc.id, at: nil)
            }
        }
        store.notify()
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = self
        splitView.translatesAutoresizingMaskIntoConstraints = false

        sidebar.container.translatesAutoresizingMaskIntoConstraints = false

        tabBar.translatesAutoresizingMaskIntoConstraints = false
        findBar.translatesAutoresizingMaskIntoConstraints = false
        statusBar.translatesAutoresizingMaskIntoConstraints = false
        editor.scrollView.translatesAutoresizingMaskIntoConstraints = false
        editorColumn.translatesAutoresizingMaskIntoConstraints = false

        tabBar.onSelect = { [weak self] id in
            self?.selectTab(id)
        }
        tabBar.onClose = { [weak self] id in
            self?.closeTab(id)
        }
        tabBar.onToggleSidebar = {
            DocumentStore.shared.perform(.toggleSidebar)
        }
        tabBar.onNewFile = { [weak self] in
            self?.addNewUntitled()
        }
        tabBar.onCloseOthers = { [weak self] id in
            self?.closeOthers(keeping: id)
        }
        tabBar.onDetach = { [weak self] id, screenPoint in
            guard let self else { return }
            WindowManager.shared.detachTab(id, from: self, screenPoint: screenPoint)
        }
        tabBar.onReorder = { [weak self] id, index in
            self?.reorderTab(id, to: index)
        }
        tabBar.onAcceptDrop = { [weak self] id, index in
            guard let self else { return false }
            if let source = WindowManager.shared.window(containing: id), source !== self {
                WindowManager.shared.moveTab(id, from: source, to: self, at: index)
                return true
            }
            if self.tabIDs.contains(id) {
                self.reorderTab(id, to: index ?? self.tabIDs.count)
                return true
            }
            return false
        }
        tabBar.windowOwner = self

        editorColumn.addSubview(tabBar)
        editorColumn.addSubview(findBar)
        editorColumn.addSubview(editor.scrollView)
        editorColumn.addSubview(statusBar)

        findHeightConstraint = findBar.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            tabBar.leadingAnchor.constraint(equalTo: editorColumn.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: editorColumn.trailingAnchor),
            tabBar.topAnchor.constraint(equalTo: editorColumn.topAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: 32),

            findBar.leadingAnchor.constraint(equalTo: editorColumn.leadingAnchor),
            findBar.trailingAnchor.constraint(equalTo: editorColumn.trailingAnchor),
            findBar.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            findHeightConstraint,

            editor.scrollView.leadingAnchor.constraint(equalTo: editorColumn.leadingAnchor),
            editor.scrollView.trailingAnchor.constraint(equalTo: editorColumn.trailingAnchor),
            editor.scrollView.topAnchor.constraint(equalTo: findBar.bottomAnchor),
            editor.scrollView.bottomAnchor.constraint(equalTo: statusBar.topAnchor),

            statusBar.leadingAnchor.constraint(equalTo: editorColumn.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: editorColumn.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: editorColumn.bottomAnchor),
            statusBar.heightAnchor.constraint(equalToConstant: 24)
        ])

        splitView.addSubview(sidebar.container)
        splitView.addSubview(editorColumn)
        splitView.setHoldingPriority(.defaultLow, forSubviewAt: 0)
        content.addSubview(splitView)

        NSLayoutConstraint.activate([
            splitView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            splitView.topAnchor.constraint(equalTo: content.topAnchor, constant: 28),
            splitView.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])

        DispatchQueue.main.async { [weak self] in
            self?.applySidebarVisibility(animated: false)
        }
    }

    private func observe() {
        NotificationCenter.default.addObserver(self, selector: #selector(storeChanged), name: .macTextStoreChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(metaChanged), name: .macTextMetaChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(showCommandPalette), name: Notification.Name("MacTextShowCommandPalette"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(showGoToLine), name: Notification.Name("MacTextShowGoToLine"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(focusEditor), name: Notification.Name("MacTextFocusEditor"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .macTextLanguageChanged, object: nil)
    }

    @objc private func languageChanged() {
        reload(full: true)
    }

    @objc private func focusEditor() {
        guard window?.isKeyWindow == true else { return }
        DispatchQueue.main.async { [weak self] in
            self?.editor.focus()
        }
    }

    @objc private func storeChanged() {
        // Drop tabs whose documents were removed globally.
        tabIDs = tabIDs.filter { store.document(id: $0) != nil }
        if let selectedTabID, store.document(id: selectedTabID) == nil {
            self.selectedTabID = tabIDs.first
        }
        if tabIDs.isEmpty, WindowManager.shared.windows.count == 1 {
            let doc = store.makeUntitledDocument()
            tabIDs = [doc.id]
            selectedTabID = doc.id
        }
        // Theme / soft wrap / open file / tab set — always refresh editor chrome + buffer binding.
        reload(full: true)
    }

    @objc private func metaChanged() {
        if let doc = selectedDocument {
            window?.title = doc.displayTitle + " — MacText"
            tabBar.updateTitles(documents: tabDocuments, selectedID: selectedTabID)
        }
        statusBar.reload(store: store, document: selectedDocument)
    }

    private func reload(full: Bool) {
        let wasFindHidden = findHeightConstraint.constant == 0
        applySidebarVisibility(animated: true)
        sidebar.reload(
            tree: store.fileTree,
            folderName: store.folderURL?.lastPathComponent,
            theme: store.theme
        )
        tabBar.reload(
            documents: tabDocuments,
            selectedID: selectedTabID,
            theme: store.theme,
            showSidebar: store.showSidebar
        )

        let findVisible = store.showFindBar && window?.isKeyWindow != false
        let findHeight: CGFloat = store.showFindBar ? (store.showReplace ? 74 : 42) : 0
        findHeightConstraint.constant = findHeight
        findBar.isHidden = !store.showFindBar
        findBar.apply(
            theme: store.theme,
            showReplace: store.showReplace,
            query: store.findQuery,
            replace: store.replaceQuery
        )
        if store.showFindBar && wasFindHidden && window?.isKeyWindow == true {
            DispatchQueue.main.async { [weak self] in
                self?.findBar.focusFind()
            }
        }

        if let doc = selectedDocument {
            if full {
                editor.load(
                    document: doc,
                    theme: store.theme,
                    softWrap: store.softWrap,
                    fontSize: store.fontSize
                )
            }
            window?.title = doc.displayTitle + " — MacText"
        }
        statusBar.reload(store: store, document: selectedDocument)
        window?.contentView?.layer?.backgroundColor = store.theme.sidebarBackground.cgColor
        window?.backgroundColor = store.theme.sidebarBackground
        _ = findVisible
    }

    func requestCloseTab(_ id: UUID) { closeTab(id) }

    func requestCloseOthers(keeping id: UUID) { closeOthers(keeping: id) }

    private func closeTab(_ id: UUID) {
        guard let doc = store.document(id: id) else {
            removeTab(id, destroyIfEmpty: WindowManager.shared.windows.count > 1)
            return
        }
        if doc.isDirty {
            let alert = NSAlert()
            alert.messageText = String(format: L10n.saveChangesTitle, doc.title)
            alert.informativeText = L10n.saveChangesBody
            alert.addButton(withTitle: L10n.save)
            alert.addButton(withTitle: L10n.dontSave)
            alert.addButton(withTitle: L10n.cancel)
            let result = alert.runModal()
            if result == .alertFirstButtonReturn {
                selectTab(id)
                store.save(documentID: id)
                if doc.isDirty { return }
            } else if result == .alertThirdButtonReturn {
                return
            }
        }
        let alone = WindowManager.shared.windows.count == 1
        removeTab(id, destroyIfEmpty: !alone)
        store.removeDocumentIfOrphaned(id)
        store.notify()
    }

    private func closeOthers(keeping id: UUID) {
        let victims = tabIDs.filter { $0 != id }
        for vid in victims {
            closeTab(vid)
        }
        selectTab(id)
    }

    private func applySidebarVisibility(animated: Bool) {
        let currentWidth = sidebar.container.frame.width

        if store.showSidebar {
            if currentWidth > 40 {
                sidebarWidth = currentWidth
            }
            if sidebar.container.superview !== splitView {
                editorColumn.removeFromSuperview()
                splitView.addSubview(sidebar.container)
                splitView.addSubview(editorColumn)
            }
            sidebar.container.isHidden = false
            let target = min(max(sidebarWidth, 180), 360)
            let apply = { [weak self] in
                guard let self else { return }
                self.splitView.setPosition(target, ofDividerAt: 0)
                self.splitView.adjustSubviews()
                self.splitView.needsDisplay = true
            }
            if animated {
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = 0.16
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    ctx.allowsImplicitAnimation = true
                    apply()
                })
            } else {
                DispatchQueue.main.async(execute: apply)
            }
        } else {
            if currentWidth > 40 {
                sidebarWidth = currentWidth
            }
            let collapse = { [weak self] in
                guard let self else { return }
                if self.sidebar.container.superview === self.splitView {
                    self.sidebar.container.removeFromSuperview()
                }
                if self.editorColumn.superview !== self.splitView {
                    self.splitView.addSubview(self.editorColumn)
                }
                self.sidebar.container.isHidden = true
                self.splitView.adjustSubviews()
                self.splitView.needsDisplay = true
                self.editorColumn.frame = self.splitView.bounds
            }
            if animated {
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = 0.14
                    ctx.allowsImplicitAnimation = true
                    collapse()
                })
            } else {
                collapse()
            }
        }
    }

    @objc private func showCommandPalette() {
        guard window?.isKeyWindow == true else { return }
        commandPalette.show(relativeTo: window)
    }

    @objc private func showGoToLine() {
        guard let window, window.isKeyWindow else { return }
        let alert = NSAlert()
        alert.messageText = L10n.goToLine
        alert.informativeText = L10n.goToLineHint
        alert.addButton(withTitle: L10n.go)
        alert.addButton(withTitle: L10n.cancel)
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        if let doc = selectedDocument {
            field.stringValue = "\(doc.cursorLine)"
        }
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if let line = Int(value), line > 0 {
                store.requestGoToLine(line)
            }
        }
    }

    func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {
        subview === sidebar.container
    }

    func splitView(_ splitView: NSSplitView, shouldCollapseSubview subview: NSView, forDoubleClickOnDividerAt dividerIndex: Int) -> Bool {
        true
    }

    func splitView(_ splitView: NSSplitView, shouldHideDividerAt dividerIndex: Int) -> Bool {
        !store.showSidebar || splitView.subviews.count < 2
    }

    func splitView(_ splitView: NSSplitView, effectiveRect proposedEffectiveRect: NSRect, forDrawnRect drawnRect: NSRect, ofDividerAt dividerIndex: Int) -> NSRect {
        (store.showSidebar && splitView.subviews.count >= 2) ? proposedEffectiveRect : .zero
    }

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        store.showSidebar ? 160 : 0
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        store.showSidebar ? 360 : 0
    }

    func splitViewDidResizeSubviews(_ notification: Notification) {
        guard store.showSidebar, sidebar.container.superview === splitView else { return }
        let width = sidebar.container.frame.width
        if width > 40 {
            sidebarWidth = width
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        if let id = selectedTabID {
            store.syncActiveSelection(id)
        }
        // Avoid full reload/re-highlight — keeps focus switches feeling instant.
        if let doc = selectedDocument {
            window?.title = doc.displayTitle + " — MacText"
        }
        statusBar.reload(store: store, document: selectedDocument)
        editor.focus()
    }

    func windowDidResize(_ notification: Notification) {
        if isPrimary, let frame = window?.frame {
            store.updateWindowFrame(frame)
        }
    }

    func windowDidMove(_ notification: Notification) {
        if isPrimary, let frame = window?.frame {
            store.updateWindowFrame(frame)
        }
    }

    func windowWillClose(_ notification: Notification) {
        // Flush live buffer first (includes IME marked text).
        flushEditorToDocument()
        if isPrimary, let frame = window?.frame {
            store.updateWindowFrame(frame)
        }

        let closingIDs = tabIDs
        let isLastWindow = WindowManager.shared.windows.filter { $0 !== self }.isEmpty

        // CRITICAL: persist WHILE this window is still registered and documents
        // are still in the store. Orphan-removal before save wiped session.json on quit.
        store.persistSessionNow()

        tabIDs = []
        WindowManager.shared.unregister(self)

        // Secondary window closed: drop docs not open elsewhere, then re-save.
        // Last window (quit): keep in-memory docs; session already written above.
        if !isLastWindow {
            for id in closingIDs {
                store.removeDocumentIfOrphaned(id)
            }
            store.persistSessionNow()
        }
    }
}
