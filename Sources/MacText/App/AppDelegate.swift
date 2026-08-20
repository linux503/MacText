import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.appearance = NSAppearance(named: DocumentStore.shared.theme.appearanceName)
        buildMenus()
        _ = WindowManager.shared.openInitialWindow()
        NSApp.activate(ignoringOtherApps: true)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuildMenus),
            name: .macTextLanguageChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshThemeMenuChecks),
            name: .macTextStoreChanged,
            object: nil
        )

        // Silent auto-check a few seconds after launch.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            UpdateChecker.check(manual: false) { result in
                UpdateChecker.presentResult(manual: false, result: result)
            }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Final flush+save before windows tear down.
        DocumentStore.shared.persistSessionNow()
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        DocumentStore.shared.persistSessionNow()
    }

    func applicationDidResignActive(_ notification: Notification) {
        DocumentStore.shared.persistSessionNow()
    }

    func applicationDidHide(_ notification: Notification) {
        DocumentStore.shared.persistSessionNow()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        DocumentStore.shared.openLaunchURLs(urls)
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        DocumentStore.shared.openLaunchURLs([URL(fileURLWithPath: filename)])
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        DocumentStore.shared.openLaunchURLs(filenames.map { URL(fileURLWithPath: $0) })
        sender.reply(toOpenOrPrint: .success)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        DocumentStore.shared.persistSessionNow()
        return true
    }

    @objc private func rebuildMenus() {
        buildMenus()
        refreshThemeMenuChecks()
    }

    private func buildMenus() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: L10n.about, action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        let settingsItem = NSMenuItem(title: L10n.settings, action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        let updateItem = NSMenuItem(title: L10n.checkForUpdates, action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        appMenu.addItem(updateItem)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: L10n.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: L10n.fileMenu)
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(makeItem(L10n.newFile, action: #selector(newFile), key: "n"))
        fileMenu.addItem(makeItem(L10n.openFile, action: #selector(openFile), key: "o"))
        fileMenu.addItem(makeItem(L10n.openFolder, action: #selector(openFolder), key: "o", modifiers: [.command, .shift]))
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(makeItem(L10n.save, action: #selector(save), key: "s"))
        fileMenu.addItem(makeItem(L10n.saveAs, action: #selector(saveAs), key: "s", modifiers: [.command, .shift]))
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(makeItem(L10n.closeTab, action: #selector(closeTab), key: "w"))

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: L10n.editMenu)
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: L10n.undo, action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: L10n.redo, action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: L10n.cut, action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: L10n.copy, action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: L10n.paste, action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: L10n.selectAll, action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(NSMenuItem.separator())
        let indentItem = NSMenuItem(title: L10n.indent, action: #selector(EditorTextView.indentSelectedLines(_:)), keyEquivalent: "]")
        indentItem.keyEquivalentModifierMask = [.command]
        editMenu.addItem(indentItem)
        let unindentItem = NSMenuItem(title: L10n.unindent, action: #selector(EditorTextView.unindentSelectedLines(_:)), keyEquivalent: "[")
        unindentItem.keyEquivalentModifierMask = [.command]
        editMenu.addItem(unindentItem)
        editMenu.addItem(NSMenuItem.separator())
        let dup = NSMenuItem(title: L10n.duplicateLine, action: #selector(EditorTextView.duplicateLineOrSelection(_:)), keyEquivalent: "d")
        dup.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(dup)
        let deleteLine = NSMenuItem(title: L10n.deleteLine, action: #selector(EditorTextView.deleteLinesSublime(_:)), keyEquivalent: "k")
        deleteLine.keyEquivalentModifierMask = [.control, .shift]
        editMenu.addItem(deleteLine)
        let selLine = NSMenuItem(title: L10n.selectLine, action: #selector(EditorTextView.selectLine(_:)), keyEquivalent: "l")
        selLine.keyEquivalentModifierMask = [.command]
        editMenu.addItem(selLine)
        let join = NSMenuItem(title: L10n.joinLines, action: #selector(EditorTextView.joinLines(_:)), keyEquivalent: "j")
        join.keyEquivalentModifierMask = [.command]
        editMenu.addItem(join)
        editMenu.addItem(NSMenuItem(title: L10n.moveLineUp, action: #selector(EditorTextView.moveLineUp(_:)), keyEquivalent: ""))
        editMenu.addItem(NSMenuItem(title: L10n.moveLineDown, action: #selector(EditorTextView.moveLineDown(_:)), keyEquivalent: ""))
        let comment = NSMenuItem(title: L10n.toggleComment, action: #selector(EditorTextView.toggleComment(_:)), keyEquivalent: "/")
        comment.keyEquivalentModifierMask = [.command]
        editMenu.addItem(comment)
        let bracket = NSMenuItem(title: L10n.matchingBracket, action: #selector(EditorTextView.jumpToMatchingBracket(_:)), keyEquivalent: "m")
        bracket.keyEquivalentModifierMask = [.control]
        editMenu.addItem(bracket)

        let findMenuItem = NSMenuItem()
        mainMenu.addItem(findMenuItem)
        let findMenu = NSMenu(title: L10n.findMenu)
        findMenuItem.submenu = findMenu
        findMenu.addItem(makeItem(L10n.find, action: #selector(find), key: "f"))
        findMenu.addItem(makeItem(L10n.replace, action: #selector(replace), key: "f", modifiers: [.command, .option]))
        findMenu.addItem(makeItem(L10n.findNext, action: #selector(findNext), key: "g"))
        findMenu.addItem(makeItem(L10n.findPrevious, action: #selector(findPrevious), key: "g", modifiers: [.command, .shift]))

        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: L10n.viewMenu)
        viewMenuItem.submenu = viewMenu
        viewMenu.addItem(makeItem(L10n.toggleSidebar, action: #selector(toggleSidebar), key: "b"))
        if let item = viewMenu.items.first(where: { $0.action == #selector(toggleSidebar) }) {
            item.title = DocumentStore.shared.showSidebar ? L10n.hideSidebar : L10n.showSidebar
        }
        viewMenu.addItem(makeItem(L10n.t("切换自动换行", "Toggle Soft Wrap"), action: #selector(toggleSoftWrap), key: "z", modifiers: [.command, .option]))
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(makeItem(L10n.biggerFont, action: #selector(biggerFont), key: "=", modifiers: [.command]))
        viewMenu.addItem(makeItem(L10n.smallerFont, action: #selector(smallerFont), key: "-", modifiers: [.command]))
        let resetFont = NSMenuItem(title: L10n.resetFont, action: #selector(resetFontSize), keyEquivalent: "0")
        resetFont.keyEquivalentModifierMask = [.command]
        resetFont.target = self
        viewMenu.addItem(resetFont)
        viewMenu.addItem(NSMenuItem.separator())

        let themeMenuItem = NSMenuItem(title: L10n.theme, action: nil, keyEquivalent: "")
        let themeMenu = NSMenu(title: L10n.theme)

        for theme in EditorTheme.all {
            let item = NSMenuItem(title: theme.name, action: #selector(selectTheme(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = theme.name
            item.state = theme.name == DocumentStore.shared.theme.name ? .on : .off
            themeMenu.addItem(item)
        }

        themeMenu.addItem(NSMenuItem.separator())
        let cycle = NSMenuItem(title: L10n.cycleTheme, action: #selector(cycleTheme), keyEquivalent: "t")
        cycle.keyEquivalentModifierMask = [.command, .option]
        cycle.target = self
        themeMenu.addItem(cycle)
        themeMenuItem.submenu = themeMenu
        viewMenu.addItem(themeMenuItem)

        viewMenu.addItem(makeItem(L10n.commandPalette + "…", action: #selector(commandPalette), key: "p", modifiers: [.command, .shift]))
        viewMenu.addItem(makeItem(L10n.t("跳转到行…", "Go to Line…"), action: #selector(goToLine), key: "g", modifiers: [.command, .option]))

        let helpMenuItem = NSMenuItem()
        mainMenu.addItem(helpMenuItem)
        let helpMenu = NSMenu(title: L10n.t("帮助", "Help"))
        helpMenuItem.submenu = helpMenu
        let webItem = NSMenuItem(title: L10n.website, action: #selector(openWebsite), keyEquivalent: "")
        webItem.target = self
        helpMenu.addItem(webItem)
        let ghItem = NSMenuItem(title: "GitHub", action: #selector(openGitHub), keyEquivalent: "")
        ghItem.target = self
        helpMenu.addItem(ghItem)
        helpMenu.addItem(NSMenuItem.separator())
        let checkItem = NSMenuItem(title: L10n.checkForUpdates, action: #selector(checkForUpdates), keyEquivalent: "")
        checkItem.target = self
        helpMenu.addItem(checkItem)

        NSApp.mainMenu = mainMenu
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
        guard let viewMenu = NSApp.mainMenu?.items.first(where: { $0.submenu?.title == L10n.viewMenu })?.submenu
                ?? NSApp.mainMenu?.item(withTitle: L10n.viewMenu)?.submenu else { return }
        if let sidebarItem = viewMenu.items.first(where: { $0.action == #selector(toggleSidebar) }) {
            sidebarItem.title = DocumentStore.shared.showSidebar ? L10n.hideSidebar : L10n.showSidebar
        }
        guard let themeMenu = viewMenu.items.first(where: { $0.submenu != nil && ($0.title == L10n.theme || $0.title == "Theme") })?.submenu else { return }
        let current = DocumentStore.shared.theme.name
        for item in themeMenu.items where item.action == #selector(selectTheme(_:)) {
            item.state = (item.representedObject as? String) == current ? .on : .off
        }
    }

    @objc private func showAbout() {
        AboutWindowController.shared.show()
    }

    @objc private func checkForUpdates() {
        UpdateChecker.check(manual: true) { result in
            UpdateChecker.presentResult(manual: true, result: result)
        }
    }

    @objc private func openWebsite() {
        NSWorkspace.shared.open(AppLinks.preferredWebsite)
    }

    @objc private func openGitHub() {
        NSWorkspace.shared.open(AppLinks.github)
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
