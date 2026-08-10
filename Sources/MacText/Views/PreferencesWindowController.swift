import AppKit

final class PreferencesWindowController: NSWindowController {
    static let shared = PreferencesWindowController()

    private let themePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let softWrapCheckbox = NSButton(checkboxWithTitle: "Soft Wrap", target: nil, action: nil)
    private let sidebarCheckbox = NSButton(checkboxWithTitle: "Show Sidebar", target: nil, action: nil)
    private let preview = ThemePreviewView(frame: .zero)

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "MacText Settings"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeChanged),
            name: .macTextStoreChanged,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        reload()
        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let title = NSTextField(labelWithString: "Appearance")
        title.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false

        let themeLabel = NSTextField(labelWithString: "Color Theme")
        themeLabel.translatesAutoresizingMaskIntoConstraints = false

        themePopup.removeAllItems()
        themePopup.addItem(withTitle: "Dark")
        themePopup.lastItem?.isEnabled = false
        for theme in EditorTheme.darkThemes {
            themePopup.addItem(withTitle: theme.name)
        }
        themePopup.menu?.addItem(NSMenuItem.separator())
        themePopup.addItem(withTitle: "Light")
        themePopup.lastItem?.isEnabled = false
        for theme in EditorTheme.lightThemes {
            themePopup.addItem(withTitle: theme.name)
        }
        themePopup.target = self
        themePopup.action = #selector(themeChanged)
        themePopup.translatesAutoresizingMaskIntoConstraints = false

        softWrapCheckbox.target = self
        softWrapCheckbox.action = #selector(softWrapChanged)
        softWrapCheckbox.translatesAutoresizingMaskIntoConstraints = false

        sidebarCheckbox.target = self
        sidebarCheckbox.action = #selector(sidebarChanged)
        sidebarCheckbox.translatesAutoresizingMaskIntoConstraints = false

        preview.translatesAutoresizingMaskIntoConstraints = false
        preview.wantsLayer = true
        preview.layer?.cornerRadius = 8
        preview.layer?.masksToBounds = true

        let hint = NSTextField(labelWithString: "You can also switch themes from View → Theme, or click the theme name in the status bar.")
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.maximumNumberOfLines = 3
        hint.lineBreakMode = .byWordWrapping
        hint.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(title)
        content.addSubview(themeLabel)
        content.addSubview(themePopup)
        content.addSubview(preview)
        content.addSubview(softWrapCheckbox)
        content.addSubview(sidebarCheckbox)
        content.addSubview(hint)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            title.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),

            themeLabel.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 16),
            themeLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),

            themePopup.centerYAnchor.constraint(equalTo: themeLabel.centerYAnchor),
            themePopup.leadingAnchor.constraint(equalTo: themeLabel.trailingAnchor, constant: 12),
            themePopup.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -20),
            themePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),

            preview.topAnchor.constraint(equalTo: themeLabel.bottomAnchor, constant: 14),
            preview.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            preview.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            preview.heightAnchor.constraint(equalToConstant: 120),

            softWrapCheckbox.topAnchor.constraint(equalTo: preview.bottomAnchor, constant: 16),
            softWrapCheckbox.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),

            sidebarCheckbox.topAnchor.constraint(equalTo: softWrapCheckbox.bottomAnchor, constant: 8),
            sidebarCheckbox.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),

            hint.topAnchor.constraint(equalTo: sidebarCheckbox.bottomAnchor, constant: 18),
            hint.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            hint.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            hint.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -16)
        ])
    }

    @objc private func storeChanged() {
        reload()
    }

    private func reload() {
        let store = DocumentStore.shared
        themePopup.selectItem(withTitle: store.theme.name)
        softWrapCheckbox.state = store.softWrap ? .on : .off
        sidebarCheckbox.state = store.showSidebar ? .on : .off
        preview.theme = store.theme
        preview.needsDisplay = true
        window?.backgroundColor = store.theme.editorChrome
    }

    @objc private func themeChanged() {
        guard let name = themePopup.titleOfSelectedItem else { return }
        // Ignore section headers
        guard EditorTheme.named(name) != nil else {
            themePopup.selectItem(withTitle: DocumentStore.shared.theme.name)
            return
        }
        DocumentStore.shared.setTheme(named: name)
    }

    @objc private func softWrapChanged() {
        let store = DocumentStore.shared
        let desired = softWrapCheckbox.state == .on
        if store.softWrap != desired {
            store.perform(.softWrap)
        }
    }

    @objc private func sidebarChanged() {
        let store = DocumentStore.shared
        let desired = sidebarCheckbox.state == .on
        if store.showSidebar != desired {
            store.perform(.toggleSidebar)
        }
    }
}

final class ThemePreviewView: NSView {
    var theme: EditorTheme = .ink

    override func draw(_ dirtyRect: NSRect) {
        theme.background.setFill()
        bounds.fill()

        let sample = NSMutableAttributedString()
        func append(_ text: String, color: NSColor) {
            sample.append(NSAttributedString(string: text, attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                .foregroundColor: color
            ]))
        }
        append("func ", color: theme.keyword)
        append("greet", color: theme.function)
        append("(", color: theme.foreground)
        append("name", color: theme.typeName)
        append(": ", color: theme.foreground)
        append("String", color: theme.typeName)
        append(") {\n", color: theme.foreground)
        append("  // MacText\n", color: theme.comment)
        append("  return ", color: theme.keyword)
        append("\"hi, \\(name)\"", color: theme.string)
        append("\n}", color: theme.foreground)

        let rect = bounds.insetBy(dx: 14, dy: 14)
        sample.draw(in: rect)

        let accent = NSBezierPath(roundedRect: NSRect(x: 12, y: 10, width: 36, height: 4), xRadius: 2, yRadius: 2)
        theme.accent.setFill()
        accent.fill()
    }
}
