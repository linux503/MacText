import AppKit

final class SidebarController: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
    let scrollView = NSScrollView()
    private let outlineView = NSOutlineView()
    private var nodes: [FileNode] = []
    private let header = NSTextField(labelWithString: "NO FOLDER")
    private let openButton = NSButton(
        image: NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: "Open Folder")
            ?? NSImage(named: NSImage.folderName)
            ?? NSImage(),
        target: nil,
        action: nil
    )
    private let hideButton = NSButton(
        image: NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: "Hide Sidebar")
            ?? NSImage(named: NSImage.rightFacingTriangleTemplateName)
            ?? NSImage(),
        target: nil,
        action: nil
    )
    let container = NSView()

    override init() {
        super.init()
        configure()
    }

    private func configure() {
        container.wantsLayer = true

        header.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        header.textColor = .secondaryLabelColor
        header.lineBreakMode = .byTruncatingTail
        header.translatesAutoresizingMaskIntoConstraints = false

        openButton.isBordered = false
        openButton.bezelStyle = .inline
        openButton.target = self
        openButton.action = #selector(openFolder)
        openButton.toolTip = "Open Folder"
        openButton.translatesAutoresizingMaskIntoConstraints = false

        hideButton.isBordered = false
        hideButton.bezelStyle = .inline
        hideButton.target = self
        hideButton.action = #selector(hideSidebar)
        hideButton.toolTip = "Hide Sidebar (⌘B)"
        hideButton.translatesAutoresizingMaskIntoConstraints = false

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.title = "Name"
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.headerView = nil
        outlineView.delegate = self
        outlineView.dataSource = self
        outlineView.rowHeight = 22
        outlineView.selectionHighlightStyle = .regular
        outlineView.target = self
        outlineView.action = #selector(outlineClicked)
        outlineView.style = .sourceList
        outlineView.backgroundColor = .clear

        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(header)
        container.addSubview(openButton)
        container.addSubview(hideButton)
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            header.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            header.trailingAnchor.constraint(equalTo: openButton.leadingAnchor, constant: -8),

            openButton.trailingAnchor.constraint(equalTo: hideButton.leadingAnchor, constant: -4),
            openButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            openButton.widthAnchor.constraint(equalToConstant: 20),

            hideButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            hideButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            hideButton.widthAnchor.constraint(equalToConstant: 20),

            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }

    func reload(tree: [FileNode], folderName: String?, theme: EditorTheme) {
        nodes = tree
        header.stringValue = folderName ?? "NO FOLDER"
        container.layer?.backgroundColor = theme.sidebarBackground.cgColor
        hideButton.contentTintColor = theme.lineNumber
        openButton.contentTintColor = theme.lineNumber
        outlineView.reloadData()
        expandTopLevel()
    }

    private func expandTopLevel() {
        for node in nodes where node.isDirectory {
            outlineView.expandItem(node, expandChildren: false)
        }
    }

    @objc private func openFolder() {
        DocumentStore.shared.perform(.openFolder)
    }

    @objc private func hideSidebar() {
        DocumentStore.shared.perform(.toggleSidebar)
    }

    @objc private func outlineClicked() {
        let row = outlineView.clickedRow
        guard row >= 0, let node = outlineView.item(atRow: row) as? FileNode, !node.isDirectory else { return }
        DocumentStore.shared.openFile(node.url)
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let node = item as? FileNode {
            return node.children.count
        }
        return nodes.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let node = item as? FileNode {
            return node.children[index]
        }
        return nodes[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let node = item as? FileNode else { return false }
        return node.isDirectory
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? FileNode else { return nil }
        let id = NSUserInterfaceItemIdentifier("Cell")
        let cell = (outlineView.makeView(withIdentifier: id, owner: self) as? NSTableCellView) ?? {
            let cell = NSTableCellView()
            cell.identifier = id
            let image = NSImageView()
            image.translatesAutoresizingMaskIntoConstraints = false
            let text = NSTextField(labelWithString: "")
            text.translatesAutoresizingMaskIntoConstraints = false
            text.font = NSFont.systemFont(ofSize: 12)
            text.lineBreakMode = .byTruncatingTail
            cell.addSubview(image)
            cell.addSubview(text)
            cell.imageView = image
            cell.textField = text
            NSLayoutConstraint.activate([
                image.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                image.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                image.widthAnchor.constraint(equalToConstant: 14),
                image.heightAnchor.constraint(equalToConstant: 14),
                text.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 6),
                text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
            return cell
        }()
        cell.textField?.stringValue = node.name
        cell.imageView?.image = NSImage(
            systemSymbolName: node.isDirectory ? "folder.fill" : "doc.text",
            accessibilityDescription: nil
        )
        cell.imageView?.contentTintColor = node.isDirectory ? .systemOrange : .secondaryLabelColor
        return cell
    }
}
