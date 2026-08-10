import AppKit

final class CommandPaletteController: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    private var panel: NSPanel?
    private let searchField = NSTextField(string: "")
    private let tableView = NSTableView()
    private var commands: [EditorAction] = []
    private var query = ""

    func show(relativeTo window: NSWindow?) {
        if panel == nil {
            buildPanel()
        }
        query = ""
        searchField.stringValue = ""
        reloadCommands()
        guard let panel else { return }
        if let window {
            let frame = window.frame
            let x = frame.midX - panel.frame.width / 2
            let y = frame.midY + 40
            panel.setFrameOrigin(NSPoint(x: x, y: y))
            window.addChildWindow(panel, ordered: .above)
        }
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(searchField)
    }

    func hide() {
        guard let panel else { return }
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
    }

    private func buildPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .fullSizeContentView, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Command Palette"
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = EditorTheme.ink.editorChrome

        searchField.placeholderString = "Type a command"
        searchField.font = NSFont.systemFont(ofSize: 14)
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(runSelected)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.backgroundColor = EditorTheme.ink.background
        searchField.textColor = EditorTheme.ink.foreground
        searchField.isBezeled = true
        searchField.bezelStyle = .roundedBezel

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("cmd"))
        column.width = 440
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 30
        tableView.target = self
        tableView.doubleAction = #selector(runSelected)
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular

        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(searchField)
        content.addSubview(scroll)
        panel.contentView = content

        NSLayoutConstraint.activate([
            searchField.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            searchField.topAnchor.constraint(equalTo: content.topAnchor, constant: 36),
            searchField.heightAnchor.constraint(equalToConstant: 28),

            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 8),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -8),
            scroll.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 10),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -8)
        ])

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKey(event) ?? event
        }

        self.panel = panel
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        guard panel?.isVisible == true else { return event }
        if event.keyCode == 53 { // escape
            hide()
            return nil
        }
        if event.keyCode == 125 { // down
            moveSelection(1)
            return nil
        }
        if event.keyCode == 126 { // up
            moveSelection(-1)
            return nil
        }
        return event
    }

    private func moveSelection(_ delta: Int) {
        guard !commands.isEmpty else { return }
        let current = tableView.selectedRow
        let next = max(0, min(commands.count - 1, (current < 0 ? 0 : current) + delta))
        tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        tableView.scrollRowToVisible(next)
    }

    private func reloadCommands() {
        commands = DocumentStore.shared.filteredCommands(query: query)
        tableView.reloadData()
        if !commands.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        query = searchField.stringValue
        reloadCommands()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        commands.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cmdCell")
        let cell = (tableView.makeView(withIdentifier: id, owner: self) as? NSTableCellView) ?? {
            let cell = NSTableCellView()
            cell.identifier = id
            let text = NSTextField(labelWithString: "")
            text.translatesAutoresizingMaskIntoConstraints = false
            text.font = NSFont.systemFont(ofSize: 13)
            cell.addSubview(text)
            cell.textField = text
            NSLayoutConstraint.activate([
                text.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
            return cell
        }()
        cell.textField?.stringValue = commands[row].title
        return cell
    }

    @objc private func runSelected() {
        let row = tableView.selectedRow
        guard row >= 0, row < commands.count else { return }
        let action = commands[row]
        hide()
        DocumentStore.shared.perform(action)
    }
}
