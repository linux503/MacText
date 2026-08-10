import AppKit

final class PreferencesWindowController: NSWindowController {
    static let shared = PreferencesWindowController()

    private let themePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let fontSizePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let softWrapCheckbox = NSButton(checkboxWithTitle: "Soft Wrap", target: nil, action: nil)
    private let sidebarCheckbox = NSButton(checkboxWithTitle: "Show Sidebar", target: nil, action: nil)
    private let preview = ThemePreviewView(frame: .zero)

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 400),
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

        let fontLabel = NSTextField(labelWithString: "Font Size")
        fontLabel.translatesAutoresizingMaskIntoConstraints = false

        fontSizePopup.removeAllItems()
        let sizes = stride(from: Int(DocumentStore.fontSizeMin), through: Int(DocumentStore.fontSizeMax), by: 1)
        for size in sizes {
            fontSizePopup.addItem(withTitle: "\(size) pt")
            fontSizePopup.lastItem?.tag = size
        }
        fontSizePopup.target = self
        fontSizePopup.action = #selector(fontSizeChanged)
        fontSizePopup.translatesAutoresizingMaskIntoConstraints = false

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

        let hint = NSTextField(labelWithString: "Font size also: View → Bigger/Smaller (⌘+ / ⌘−). Themes: View → Theme or status bar.")
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.maximumNumberOfLines = 3
        hint.lineBreakMode = .byWordWrapping
        hint.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(title)
        content.addSubview(themeLabel)
        content.addSubview(themePopup)
        content.addSubview(fontLabel)
        content.addSubview(fontSizePopup)
        content.addSubview(preview)
        content.addSubview(softWrapCheckbox)
        content.addSubview(sidebarCheckbox)
        content.addSubview(hint)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            title.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),

            themeLabel.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 16),
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
    }

    @objc private func storeChanged() {
        reload()
    }

    private func reload() {
        let store = DocumentStore.shared
        themePopup.selectItem(withTitle: store.theme.name)
        fontSizePopup.selectItem(withTag: Int(store.fontSize.rounded()))
        softWrapCheckbox.state = store.softWrap ? .on : .off
        sidebarCheckbox.state = store.showSidebar ? .on : .off
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
        append("\"hi, \\(name)\"", color: theme.string)
        append("\n}", color: theme.foreground)

        let rect = bounds.insetBy(dx: 14, dy: 14)
        sample.draw(in: rect)

        let accent = NSBezierPath(roundedRect: NSRect(x: 12, y: 10, width: 36, height: 4), xRadius: 2, yRadius: 2)
        theme.accent.setFill()
        accent.fill()
    }
}
