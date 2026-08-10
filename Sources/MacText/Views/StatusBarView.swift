import AppKit

final class StatusBarView: NSView {
    private let leftLabel = NSTextField(labelWithString: "")
    private let themeButton = NSButton(title: "Ink", target: nil, action: nil)
    private let accentStrip = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        accentStrip.wantsLayer = true
        accentStrip.translatesAutoresizingMaskIntoConstraints = false
        addSubview(accentStrip)

        leftLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        leftLabel.textColor = .secondaryLabelColor
        leftLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(leftLabel)

        themeButton.bezelStyle = .inline
        themeButton.isBordered = false
        themeButton.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        themeButton.target = self
        themeButton.action = #selector(showThemeMenu)
        themeButton.toolTip = "Change color theme"
        themeButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(themeButton)

        NSLayoutConstraint.activate([
            accentStrip.leadingAnchor.constraint(equalTo: leadingAnchor),
            accentStrip.trailingAnchor.constraint(equalTo: trailingAnchor),
            accentStrip.topAnchor.constraint(equalTo: topAnchor),
            accentStrip.heightAnchor.constraint(equalToConstant: 1),

            leftLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            leftLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            leftLabel.trailingAnchor.constraint(lessThanOrEqualTo: themeButton.leadingAnchor, constant: -12),

            themeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            themeButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reload(store: DocumentStore) {
        let theme = store.theme
        layer?.backgroundColor = theme.statusBar.cgColor
        accentStrip.layer?.backgroundColor = theme.accent.withAlphaComponent(0.55).cgColor
        leftLabel.textColor = theme.lineNumber
        themeButton.contentTintColor = theme.accent
        themeButton.title = "Theme: \(theme.name) ▾"

        if let doc = store.selectedDocument {
            let languageName: String
            if doc.language == .plain, !doc.content.isEmpty {
                languageName = SyntaxHighlighter.inferLanguage(from: doc.content).displayName
            } else {
                languageName = doc.language.displayName
            }
            var parts = [
                "Ln \(doc.cursorLine), Col \(doc.cursorColumn)",
                languageName,
                "UTF-8"
            ]
            if store.softWrap { parts.append("Wrap") }
            leftLabel.stringValue = parts.joined(separator: "  ·  ")
        } else {
            leftLabel.stringValue = ""
        }
    }

    @objc private func showThemeMenu(_ sender: NSButton) {
        let menu = NSMenu()

        let darkHeader = NSMenuItem(title: "Dark", action: nil, keyEquivalent: "")
        darkHeader.isEnabled = false
        menu.addItem(darkHeader)
        for theme in EditorTheme.darkThemes {
            let item = NSMenuItem(title: theme.name, action: #selector(pickTheme(_:)), keyEquivalent: "")
            item.target = self
            item.state = theme.name == DocumentStore.shared.theme.name ? .on : .off
            item.representedObject = theme.name
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())
        let lightHeader = NSMenuItem(title: "Light", action: nil, keyEquivalent: "")
        lightHeader.isEnabled = false
        menu.addItem(lightHeader)
        for theme in EditorTheme.lightThemes {
            let item = NSMenuItem(title: theme.name, action: #selector(pickTheme(_:)), keyEquivalent: "")
            item.target = self
            item.state = theme.name == DocumentStore.shared.theme.name ? .on : .off
            item.representedObject = theme.name
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.keyEquivalentModifierMask = .command
        settings.target = self
        menu.addItem(settings)

        let point = NSPoint(x: sender.bounds.minX, y: sender.bounds.maxY + 4)
        menu.popUp(positioning: nil, at: point, in: sender)
    }

    @objc private func pickTheme(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        DocumentStore.shared.setTheme(named: name)
    }

    @objc private func openSettings() {
        DocumentStore.shared.showPreferences()
    }
}
