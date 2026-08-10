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

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 740),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "MacText"
        window.minSize = NSSize(width: 900, height: 560)
        if let saved = DocumentStore.shared.windowFrame,
           saved.width >= 900, saved.height >= 560,
           NSScreen.screens.contains(where: { $0.visibleFrame.intersects(saved) }) {
            window.setFrame(saved, display: false)
        } else {
            window.center()
        }
        window.titlebarAppearsTransparent = true
        window.backgroundColor = EditorTheme.ink.sidebarBackground
        self.init(window: window)
        window.delegate = self
        buildUI()
        observe()
        reload(full: true)
        DispatchQueue.main.async { [weak self] in
            self?.editor.focus()
        }
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
            self?.store.select(id)
            DispatchQueue.main.async { self?.editor.focus() }
        }
        tabBar.onClose = { [weak self] id in
            self?.store.close(id)
        }
        tabBar.onToggleSidebar = {
            DocumentStore.shared.perform(.toggleSidebar)
        }
        tabBar.onNewFile = { [weak self] in
            DocumentStore.shared.perform(.newFile)
            DispatchQueue.main.async { self?.editor.focus() }
        }
        tabBar.onCloseOthers = { id in
            DocumentStore.shared.closeOthers(keeping: id)
        }

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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeChanged),
            name: .macTextStoreChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(metaChanged),
            name: .macTextMetaChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showCommandPalette),
            name: Notification.Name("MacTextShowCommandPalette"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showGoToLine),
            name: Notification.Name("MacTextShowGoToLine"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(focusEditor),
            name: Notification.Name("MacTextFocusEditor"),
            object: nil
        )
    }

    @objc private func focusEditor() {
        DispatchQueue.main.async { [weak self] in
            self?.editor.focus()
        }
    }

    @objc private func storeChanged() {
        reload(full: true)
    }

    @objc private func metaChanged() {
        // Cursor/content edits: refresh chrome only — never tear down views (avoids notification recursion).
        if let doc = store.selectedDocument {
            window?.title = doc.displayTitle + " — MacText"
            tabBar.updateTitles(documents: store.documents, selectedID: store.selectedDocumentID)
        }
        statusBar.reload(store: store)
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
            documents: store.documents,
            selectedID: store.selectedDocumentID,
            theme: store.theme,
            showSidebar: store.showSidebar
        )

        let findVisible = store.showFindBar
        let findHeight: CGFloat = findVisible ? (store.showReplace ? 74 : 42) : 0
        findHeightConstraint.constant = findHeight
        findBar.isHidden = !findVisible
        findBar.apply(
            theme: store.theme,
            showReplace: store.showReplace,
            query: store.findQuery,
            replace: store.replaceQuery
        )
        if findVisible && wasFindHidden {
            DispatchQueue.main.async { [weak self] in
                self?.findBar.focusFind()
            }
        }

        if let doc = store.selectedDocument {
            editor.load(document: doc, theme: store.theme, softWrap: store.softWrap)
            window?.title = doc.displayTitle + " — MacText"
        }
        statusBar.reload(store: store)
        window?.contentView?.layer?.backgroundColor = store.theme.sidebarBackground.cgColor
        window?.backgroundColor = store.theme.sidebarBackground
        _ = full
    }

    private func applySidebarVisibility(animated: Bool) {
        _ = animated
        let currentWidth = sidebar.container.frame.width

        if store.showSidebar {
            // Remember width before restoring if we still have a sensible value.
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
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.splitView.setPosition(target, ofDividerAt: 0)
                self.splitView.adjustSubviews()
                self.splitView.needsDisplay = true
            }
        } else {
            if currentWidth > 40 {
                sidebarWidth = currentWidth
            }
            // Fully detach sidebar so the editor owns 100% width — no leftover gutter.
            if sidebar.container.superview === splitView {
                sidebar.container.removeFromSuperview()
            }
            if editorColumn.superview !== splitView {
                splitView.addSubview(editorColumn)
            }
            sidebar.container.isHidden = true
            splitView.adjustSubviews()
            splitView.needsDisplay = true
            // Force editor column to fill split view bounds.
            editorColumn.frame = splitView.bounds
        }
    }

    @objc private func showCommandPalette() {
        commandPalette.show(relativeTo: window)
    }

    @objc private func showGoToLine() {
        guard let window else { return }
        let alert = NSAlert()
        alert.messageText = "Go to Line"
        alert.informativeText = "Enter a line number"
        alert.addButton(withTitle: "Go")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        if let doc = store.selectedDocument {
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
        _ = window
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

    func windowDidResize(_ notification: Notification) {
        if let frame = window?.frame {
            store.updateWindowFrame(frame)
        }
    }

    func windowDidMove(_ notification: Notification) {
        if let frame = window?.frame {
            store.updateWindowFrame(frame)
        }
    }

    func windowWillClose(_ notification: Notification) {
        if let frame = window?.frame {
            store.updateWindowFrame(frame)
        }
        store.persistSessionNow()
    }
}
