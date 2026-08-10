import AppKit

final class PreferencesWindowController: NSWindowController {
    static let shared = PreferencesWindowController()

    private let themePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let fontSizePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let languagePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let softWrapCheckbox = NSButton(checkboxWithTitle: "Soft Wrap", target: nil, action: nil)
    private let sidebarCheckbox = NSButton(checkboxWithTitle: "Show Sidebar", target: nil, action: nil)
    private let titleLabel = NSTextField(labelWithString: "")
    private let themeLabel = NSTextField(labelWithString: "")
    private let fontLabel = NSTextField(labelWithString: "")
    private let languageLabel = NSTextField(labelWithString: "")
    private let hint = NSTextField(labelWithString: "")
    private let preview = ThemePreviewView(frame: .zero)

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 440),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.settingsTitle
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeChanged),
            name: .macTextStoreChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageChanged),
            name: .macTextLanguageChanged,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        applyLocalizedLabels()
        reload()
        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        themeLabel.translatesAutoresizingMaskIntoConstraints = false
        fontLabel.translatesAutoresizingMaskIntoConstraints = false
        languageLabel.translatesAutoresizingMaskIntoConstraints = false

        themePopup.removeAllItems()
        themePopup.addItem(withTitle: L10n.dark)
        themePopup.lastItem?.isEnabled = false
        for theme in EditorTheme.darkThemes {
            themePopup.addItem(withTitle: theme.name)
        }
        themePopup.menu?.addItem(NSMenuItem.separator())
        themePopup.addItem(withTitle: L10n.light)
        themePopup.lastItem?.isEnabled = false
        for theme in EditorTheme.lightThemes {
            themePopup.addItem(withTitle: theme.name)
        }
        themePopup.target = self
        themePopup.action = #selector(themeChanged)
        themePopup.translatesAutoresizingMaskIntoConstraints = false

        fontSizePopup.removeAllItems()
        let sizes = stride(from: Int(DocumentStore.fontSizeMin), through: Int(DocumentStore.fontSizeMax), by: 1)
        for size in sizes {
            fontSizePopup.addItem(withTitle: "\(size) pt")
            fontSizePopup.lastItem?.tag = size
        }
        fontSizePopup.target = self
        fontSizePopup.action = #selector(fontSizeChanged)
        fontSizePopup.translatesAutoresizingMaskIntoConstraints = false

        languagePopup.removeAllItems()
        for lang in AppLanguage.allCases {
            languagePopup.addItem(withTitle: lang.displayName)
            languagePopup.lastItem?.representedObject = lang.rawValue
        }
        languagePopup.target = self
        languagePopup.action = #selector(languagePopupChanged)
        languagePopup.translatesAutoresizingMaskIntoConstraints = false

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

        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.maximumNumberOfLines = 3
        hint.lineBreakMode = .byWordWrapping
        hint.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(titleLabel)
        content.addSubview(themeLabel)
        content.addSubview(themePopup)
        content.addSubview(fontLabel)
        content.addSubview(fontSizePopup)
        content.addSubview(languageLabel)
        content.addSubview(languagePopup)
        content.addSubview(preview)
        content.addSubview(softWrapCheckbox)
        content.addSubview(sidebarCheckbox)
        content.addSubview(hint)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),

            languageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            languageLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            languageLabel.widthAnchor.constraint(equalToConstant: 90),

            languagePopup.centerYAnchor.constraint(equalTo: languageLabel.centerYAnchor),
            languagePopup.leadingAnchor.constraint(equalTo: languageLabel.trailingAnchor, constant: 12),
            languagePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),

            themeLabel.topAnchor.constraint(equalTo: languageLabel.bottomAnchor, constant: 14),
            themeLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            themeLabel.widthAnchor.constraint(equalToConstant: 90),

            themePopup.centerYAnchor.constraint(equalTo: themeLabel.centerYAnchor),
            themePopup.leadingAnchor.constraint(equalTo: themeLabel.trailingAnchor, constant: 12),
            themePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),

            fontLabel.topAnchor.constraint(equalTo: themeLabel.bottomAnchor, constant: 14),
            fontLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            fontLabel.widthAnchor.constraint(equalToConstant: 90),

            fontSizePopup.centerYAnchor.constraint(equalTo: fontLabel.centerYAnchor),
            fontSizePopup.leadingAnchor.constraint(equalTo: fontLabel.trailingAnchor, constant: 12),
            fontSizePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),

            preview.topAnchor.constraint(equalTo: fontLabel.bottomAnchor, constant: 14),
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

        applyLocalizedLabels()
    }

    private func applyLocalizedLabels() {
        window?.title = L10n.settingsTitle
        titleLabel.stringValue = L10n.appearance
        themeLabel.stringValue = L10n.colorTheme
        fontLabel.stringValue = L10n.fontSize
        languageLabel.stringValue = L10n.languageLabel
        softWrapCheckbox.title = L10n.softWrap
        sidebarCheckbox.title = L10n.showSidebar
        hint.stringValue = L10n.settingsHint

        // Rebuild theme section headers
        let selectedTheme = DocumentStore.shared.theme.name
        themePopup.removeAllItems()
        themePopup.addItem(withTitle: L10n.dark)
        themePopup.lastItem?.isEnabled = false
        for theme in EditorTheme.darkThemes {
            themePopup.addItem(withTitle: theme.name)
        }
        themePopup.menu?.addItem(NSMenuItem.separator())
        themePopup.addItem(withTitle: L10n.light)
        themePopup.lastItem?.isEnabled = false
        for theme in EditorTheme.lightThemes {
            themePopup.addItem(withTitle: theme.name)
        }
        themePopup.selectItem(withTitle: selectedTheme)
    }

    @objc private func storeChanged() { reload() }
    @objc private func languageChanged() {
        applyLocalizedLabels()
        reload()
    }

    private func reload() {
        let store = DocumentStore.shared
        themePopup.selectItem(withTitle: store.theme.name)
        fontSizePopup.selectItem(withTag: Int(store.fontSize.rounded()))
        softWrapCheckbox.state = store.softWrap ? .on : .off
        sidebarCheckbox.state = store.showSidebar ? .on : .off
        if let item = languagePopup.itemArray.first(where: {
            ($0.representedObject as? String) == L10n.language.rawValue
        }) {
            languagePopup.select(item)
        }
        preview.theme = store.theme
        preview.fontSize = store.fontSize
        preview.needsDisplay = true
        window?.backgroundColor = store.theme.editorChrome
    }

    @objc private func themeChanged() {
        guard let name = themePopup.titleOfSelectedItem else { return }
        guard EditorTheme.named(name) != nil else {
            themePopup.selectItem(withTitle: DocumentStore.shared.theme.name)
            return
        }
        DocumentStore.shared.setTheme(named: name)
    }

    @objc private func fontSizeChanged() {
        guard let item = fontSizePopup.selectedItem else { return }
        DocumentStore.shared.setFontSize(CGFloat(item.tag))
    }

    @objc private func languagePopupChanged() {
        guard let raw = languagePopup.selectedItem?.representedObject as? String,
              let lang = AppLanguage(rawValue: raw) else { return }
        guard lang != L10n.language else { return }
        L10n.language = lang
        DocumentStore.shared.persistSessionNow()
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
    var fontSize: CGFloat = 12

    override func draw(_ dirtyRect: NSRect) {
        theme.background.setFill()
        bounds.fill()

        let sample = NSMutableAttributedString()
        let size = min(14, max(11, fontSize - 1))
        func append(_ text: String, color: NSColor) {
            sample.append(NSAttributedString(string: text, attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: size, weight: .regular),
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
        append(#""hi, \(name)""#, color: theme.string)
        append("\n}", color: theme.foreground)

        let rect = bounds.insetBy(dx: 14, dy: 14)
        sample.draw(in: rect)

        let accent = NSBezierPath(roundedRect: NSRect(x: 12, y: 10, width: 36, height: 4), xRadius: 2, yRadius: 2)
        theme.accent.setFill()
        accent.fill()
    }
}
