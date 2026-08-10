import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.appearance = NSAppearance(named: DocumentStore.shared.theme.appearanceName)
        // Dock icon: CFBundleIconFile only (runtime applicationIconImage scales oddly)
        buildMenus()
        let controller = MainWindowController()
        mainWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        DocumentStore.shared.persistSessionNow()
    }

    func applicationDidResignActive(_ notification: Notification) {
        DocumentStore.shared.persistSessionNow()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let files = urls.filter { !$0.hasDirectoryPath }
        let folders = urls.filter(\.hasDirectoryPath)
        if let folder = folders.first {
            DocumentStore.shared.openFolder(folder)
        }
        if !files.isEmpty {
            DocumentStore.shared.openFiles(urls: files)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        DocumentStore.shared.persistSessionNow()
        return true
    }

    private func buildMenus() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "About MacText", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit MacText", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(makeItem("New File", action: #selector(newFile), key: "n"))
        fileMenu.addItem(makeItem("Open File…", action: #selector(openFile), key: "o"))
        fileMenu.addItem(makeItem("Open Folder…", action: #selector(openFolder), key: "o", modifiers: [.command, .shift]))
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(makeItem("Save", action: #selector(save), key: "s"))
        fileMenu.addItem(makeItem("Save As…", action: #selector(saveAs), key: "s", modifiers: [.command, .shift]))
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(makeItem("Close Tab", action: #selector(closeTab), key: "w"))

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(NSMenuItem.separator())
        let indentItem = NSMenuItem(title: "Indent", action: #selector(EditorTextView.indentSelectedLines(_:)), keyEquivalent: "]")
        indentItem.keyEquivalentModifierMask = [.command]
        editMenu.addItem(indentItem)
        let unindentItem = NSMenuItem(title: "Unindent", action: #selector(EditorTextView.unindentSelectedLines(_:)), keyEquivalent: "[")
        unindentItem.keyEquivalentModifierMask = [.command]
        editMenu.addItem(unindentItem)

        let findMenuItem = NSMenuItem()
        mainMenu.addItem(findMenuItem)
        let findMenu = NSMenu(title: "Find")
        findMenuItem.submenu = findMenu
        findMenu.addItem(makeItem("Find…", action: #selector(find), key: "f"))
        findMenu.addItem(makeItem("Replace…", action: #selector(replace), key: "f", modifiers: [.command, .option]))
        findMenu.addItem(makeItem("Find Next", action: #selector(findNext), key: "g"))
        findMenu.addItem(makeItem("Find Previous", action: #selector(findPrevious), key: "g", modifiers: [.command, .shift]))

        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu
        viewMenu.addItem(makeItem("Toggle Sidebar", action: #selector(toggleSidebar), key: "b"))
        // Title refreshes with checkmark-style show/hide wording via refreshSidebarMenuTitle
        if let item = viewMenu.item(withTitle: "Toggle Sidebar") {
            item.title = DocumentStore.shared.showSidebar ? "Hide Sidebar" : "Show Sidebar"
        }
        viewMenu.addItem(makeItem("Toggle Soft Wrap", action: #selector(toggleSoftWrap), key: "z", modifiers: [.command, .option]))
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(makeItem("Bigger", action: #selector(biggerFont), key: "=", modifiers: [.command]))
        viewMenu.addItem(makeItem("Smaller", action: #selector(smallerFont), key: "-", modifiers: [.command]))
        let resetFont = NSMenuItem(title: "Reset Font Size", action: #selector(resetFontSize), keyEquivalent: "0")
        resetFont.keyEquivalentModifierMask = [.command]
        resetFont.target = self
        viewMenu.addItem(resetFont)
        viewMenu.addItem(NSMenuItem.separator())

        let themeMenuItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        let themeMenu = NSMenu(title: "Theme")

        let darkHeader = NSMenuItem(title: "Dark", action: nil, keyEquivalent: "")
        darkHeader.isEnabled = false
        themeMenu.addItem(darkHeader)
        for theme in EditorTheme.darkThemes {
            let item = NSMenuItem(title: theme.name, action: #selector(selectTheme(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = theme.name
            item.state = theme.name == DocumentStore.shared.theme.name ? .on : .off
            themeMenu.addItem(item)
        }

        themeMenu.addItem(NSMenuItem.separator())
        let lightHeader = NSMenuItem(title: "Light", action: nil, keyEquivalent: "")
        lightHeader.isEnabled = false
        themeMenu.addItem(lightHeader)
        for theme in EditorTheme.lightThemes {
            let item = NSMenuItem(title: theme.name, action: #selector(selectTheme(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = theme.name
            item.state = theme.name == DocumentStore.shared.theme.name ? .on : .off
            themeMenu.addItem(item)
        }

        themeMenu.addItem(NSMenuItem.separator())
        let cycle = NSMenuItem(title: "Cycle Themes", action: #selector(cycleTheme), keyEquivalent: "t")
        cycle.keyEquivalentModifierMask = [.command, .option]
        cycle.target = self
        themeMenu.addItem(cycle)
        themeMenuItem.submenu = themeMenu
        viewMenu.addItem(themeMenuItem)

        viewMenu.addItem(makeItem("Command Palette…", action: #selector(commandPalette), key: "p", modifiers: [.command, .shift]))
        viewMenu.addItem(makeItem("Go to Line…", action: #selector(goToLine), key: "g", modifiers: [.command, .option]))

        NSApp.mainMenu = mainMenu

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshThemeMenuChecks),
            name: .macTextStoreChanged,
            object: nil
        )
    }

    private func makeItem(
        _ title: String,
        action: Selector,
        key: String,
        modifiers: NSEvent.ModifierFlags = [.command]
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = self
        return item
    }

    @objc private func showSettings() {
        DocumentStore.shared.showPreferences()
    }

    @objc private func selectTheme(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        DocumentStore.shared.setTheme(named: name)
    }

    @objc private func refreshThemeMenuChecks() {
        guard let viewMenu = NSApp.mainMenu?.item(withTitle: "View")?.submenu else { return }
        if let sidebarItem = viewMenu.items.first(where: { $0.action == #selector(toggleSidebar) }) {
            sidebarItem.title = DocumentStore.shared.showSidebar ? "Hide Sidebar" : "Show Sidebar"
        }
        guard let themeMenu = viewMenu.item(withTitle: "Theme")?.submenu else { return }
        let current = DocumentStore.shared.theme.name
        for item in themeMenu.items where item.action == #selector(selectTheme(_:)) {
            item.state = (item.representedObject as? String) == current ? .on : .off
        }
    }

    @objc private func showAbout() {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.5"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "7"
        var options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: "MacText",
            .applicationVersion: short,
            .version: build,
            .credits: NSAttributedString(
                string: "A native Mac text editor.\nThemes: Ink · Black · Paper · Snow",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            )
        ]
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
            ?? Bundle.main.url(forResource: "MacTextIcon", withExtension: "png"),
           let image = NSImage(contentsOf: iconURL) {
            options[.applicationIcon] = image
        }
        NSApp.orderFrontStandardAboutPanel(options: options)
    }

    @objc private func newFile() {
        DocumentStore.shared.perform(.newFile)
        NotificationCenter.default.post(name: Notification.Name("MacTextFocusEditor"), object: nil)
    }
    @objc private func openFile() { DocumentStore.shared.perform(.openFile) }
    @objc private func openFolder() { DocumentStore.shared.perform(.openFolder) }
    @objc private func save() { DocumentStore.shared.perform(.save) }
    @objc private func saveAs() { DocumentStore.shared.perform(.saveAs) }
    @objc private func closeTab() { DocumentStore.shared.perform(.closeTab) }
    @objc private func find() { DocumentStore.shared.perform(.find) }
    @objc private func replace() { DocumentStore.shared.perform(.replace) }
    @objc private func findNext() { DocumentStore.shared.requestFindNext(forward: true) }
    @objc private func findPrevious() { DocumentStore.shared.requestFindNext(forward: false) }
    @objc private func toggleSidebar() { DocumentStore.shared.perform(.toggleSidebar) }
    @objc private func toggleSoftWrap() { DocumentStore.shared.perform(.softWrap) }
    @objc private func cycleTheme() { DocumentStore.shared.perform(.nextTheme) }
    @objc private func biggerFont() { DocumentStore.shared.perform(.biggerFont) }
    @objc private func smallerFont() { DocumentStore.shared.perform(.smallerFont) }
    @objc private func resetFontSize() { DocumentStore.shared.setFontSize(DocumentStore.fontSizeDefault) }
    @objc private func commandPalette() { DocumentStore.shared.perform(.commandPalette) }
    @objc private func goToLine() { DocumentStore.shared.perform(.goToLine) }
}
