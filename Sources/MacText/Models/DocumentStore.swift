import AppKit
import Foundation
import UniformTypeIdentifiers

extension Notification.Name {
    static let macTextStoreChanged = Notification.Name("MacTextStoreChanged")
    static let macTextMetaChanged = Notification.Name("MacTextMetaChanged")
    static let macTextFindNext = Notification.Name("MacTextFindNext")
    static let macTextReplaceOne = Notification.Name("MacTextReplaceOne")
    static let macTextReplaceAll = Notification.Name("MacTextReplaceAll")
    static let macTextGoToLine = Notification.Name("MacTextGoToLine")
}

enum EditorAction: String, CaseIterable {
    case newFile
    case openFile
    case openFolder
    case save
    case saveAs
    case closeTab
    case find
    case replace
    case commandPalette
    case goToLine
    case toggleSidebar
    case softWrap
    case nextTheme
    case biggerFont
    case smallerFont
    case preferences

    var title: String {
        switch self {
        case .newFile: return L10n.newFile
        case .openFile: return L10n.openFile
        case .openFolder: return L10n.openFolder
        case .save: return L10n.save
        case .saveAs: return L10n.saveAs
        case .closeTab: return L10n.closeTab
        case .find: return L10n.t("查找", "Find")
        case .replace: return L10n.t("替换", "Replace")
        case .commandPalette: return L10n.commandPalette
        case .goToLine: return L10n.t("跳转到行…", "Go to Line…")
        case .toggleSidebar: return L10n.toggleSidebar
        case .softWrap: return L10n.t("切换自动换行", "Toggle Soft Wrap")
        case .nextTheme: return L10n.cycleTheme
        case .biggerFont: return L10n.biggerFontCmd
        case .smallerFont: return L10n.smallerFontCmd
        case .preferences: return L10n.preferences
        }
    }

    var keywords: [String] {
        switch self {
        case .newFile: return ["new", "create", "file"]
        case .openFile: return ["open", "file"]
        case .openFolder: return ["open", "folder", "directory", "project"]
        case .save: return ["save"]
        case .saveAs: return ["save", "as"]
        case .closeTab: return ["close", "tab"]
        case .find: return ["find", "search"]
        case .replace: return ["replace", "substitute"]
        case .commandPalette: return ["command", "palette"]
        case .goToLine: return ["goto", "line", "jump"]
        case .toggleSidebar: return ["sidebar", "toggle", "panel"]
        case .softWrap: return ["wrap", "soft"]
        case .nextTheme: return ["theme", "color", "appearance", "ink", "black", "paper", "snow", "dark", "light"]
        case .biggerFont: return ["font", "size", "bigger", "larger", "zoom", "increase"]
        case .smallerFont: return ["font", "size", "smaller", "zoom", "decrease"]
        case .preferences: return ["settings", "preferences", "theme", "options", "font"]
        }
    }
}

final class FileNode: NSObject {
    let id: URL
    let name: String
    let url: URL
    let isDirectory: Bool
    let children: [FileNode]

    init(id: URL, name: String, url: URL, isDirectory: Bool, children: [FileNode]) {
        self.id = id
        self.name = name
        self.url = url
        self.isDirectory = isDirectory
        self.children = children
        super.init()
    }
}

final class DocumentStore {
    static let shared = DocumentStore()

    private(set) var documents: [TextDocument] = []
    private(set) var selectedDocumentID: UUID?
    private(set) var folderURL: URL?
    private(set) var fileTree: [FileNode] = []
    var showSidebar = true
    var showFindBar = false
    var showReplace = false
    var softWrap = false
    var findQuery = ""
    var replaceQuery = ""
    var theme = EditorTheme.ink
    /// Editor monospaced font size in points (clamped 10…36).
    var fontSize: CGFloat = 13
    var findDirectionForward = true
    var windowFrame: NSRect?
    /// Sublime-like: silently write dirty files that already have a path.
    var autoSaveToDisk = true

    static let fontSizeMin: CGFloat = 10
    static let fontSizeMax: CGFloat = 36
    static let fontSizeDefault: CGFloat = 13
    static let fontSizeStep: CGFloat = 1

    private var persistWorkItem: DispatchWorkItem?
    private var isRestoring = false

    /// Used only when bootstrapping the first window from a restored session.
    private(set) var bootstrapSelectedID: UUID?

    var selectedDocument: TextDocument? {
        if let key = WindowManager.shared.keyEditor?.selectedDocument {
            return key
        }
        guard let selectedDocumentID else { return documents.first }
        return documents.first { $0.id == selectedDocumentID } ?? documents.first
    }

    private init() {
        if let session = SessionStore.load(), let lang = session.uiLanguage,
           let parsed = AppLanguage(rawValue: lang) {
            UserDefaults.standard.set(parsed.rawValue, forKey: "mactext.uiLanguage")
        }
        if !restoreSession() {
            // First window creates untitled via MainWindowController.
        }
    }

    func document(id: UUID) -> TextDocument? {
        documents.first { $0.id == id }
    }

    func document(fileURL url: URL) -> TextDocument? {
        let standardized = url.standardizedFileURL
        return documents.first { $0.fileURL?.standardizedFileURL == standardized }
    }

    func syncActiveSelection(_ id: UUID) {
        selectedDocumentID = id
        bootstrapSelectedID = id
    }

    @discardableResult
    func makeUntitledDocument() -> TextDocument {
        let untitledCount = documents.filter { $0.fileURL == nil }.count + 1
        let title = untitledCount == 1 ? "untitled" : "untitled \(untitledCount)"
        let doc = TextDocument(title: title, content: "", isDirty: false)
        documents.append(doc)
        selectedDocumentID = doc.id
        schedulePersist()
        return doc
    }

    @discardableResult
    func loadFileDocument(_ url: URL) -> TextDocument? {
        let standardized = url.standardizedFileURL
        if let existing = document(fileURL: standardized) {
            selectedDocumentID = existing.id
            return existing
        }
        do {
            let loaded = try TextFileLoader.load(url: standardized)
            let doc = TextDocument(
                title: standardized.lastPathComponent,
                fileURL: standardized,
                content: loaded.content,
                isDirty: false,
                language: LanguageKind.detect(from: standardized),
                enableHighlight: loaded.shouldHighlight
            )
            documents.append(doc)
            selectedDocumentID = doc.id
            schedulePersist()
            return doc
        } catch {
            presentError(L10n.t(
                "无法打开 \(standardized.lastPathComponent)：\n\(error.localizedDescription)",
                "Could not open \(standardized.lastPathComponent):\n\(error.localizedDescription)"
            ))
            return nil
        }
    }

    func removeDocumentIfOrphaned(_ id: UUID) {
        let stillOpen = WindowManager.shared.windows.contains { $0.tabIDs.contains(id) }
        guard !stillOpen else { return }
        documents.removeAll { $0.id == id }
        if selectedDocumentID == id {
            selectedDocumentID = documents.first?.id
        }
        schedulePersist()
    }

    func save(documentID id: UUID) {
        guard let doc = document(id: id) else { return }
        selectedDocumentID = id
        if let url = doc.fileURL {
            write(doc, to: url)
        } else {
            saveSelectedAs()
        }
    }

    func notify() {
        NotificationCenter.default.post(name: .macTextStoreChanged, object: self)
        schedulePersist()
    }

    func notifyMeta() {
        NotificationCenter.default.post(name: .macTextMetaChanged, object: self)
        schedulePersist()
    }

    func newUntitled(persist: Bool = true) {
        if let window = WindowManager.shared.keyEditor {
            window.addNewUntitled()
            return
        }
        _ = makeUntitledDocument()
        if persist { notify() }
    }

    func select(_ id: UUID) {
        if let window = WindowManager.shared.window(containing: id) {
            window.window?.makeKeyAndOrderFront(nil)
            window.selectTab(id)
            return
        }
        selectedDocumentID = id
        notify()
    }

    func close(_ id: UUID) {
        if let window = WindowManager.shared.window(containing: id) ?? WindowManager.shared.keyEditor {
            window.requestCloseTab(id)
            return
        }
        documents.removeAll { $0.id == id }
        notify()
    }

    func closeOthers(keeping id: UUID) {
        guard let window = WindowManager.shared.window(containing: id) ?? WindowManager.shared.keyEditor else { return }
        window.requestCloseOthers(keeping: id)
    }

    func openFiles(urls: [URL]) {
        if let window = WindowManager.shared.keyEditor {
            window.openURLs(urls)
            return
        }
        for url in urls {
            _ = loadFileDocument(url)
        }
        notify()
    }

    @discardableResult
    func openFile(_ url: URL) -> TextDocument? {
        if let window = WindowManager.shared.keyEditor {
            window.openURLs([url])
            return document(fileURL: url)
        }
        let doc = loadFileDocument(url)
        notify()
        return doc
    }

    func openFolder(_ url: URL) {
        folderURL = url.standardizedFileURL
        refreshFileTree()
        showSidebar = true
        notify()
    }

    func refreshFileTree() {
        guard let folderURL else {
            fileTree = []
            return
        }
        fileTree = buildTree(at: folderURL, depth: 0, maxDepth: 4)
    }

    private func buildTree(at url: URL, depth: Int, maxDepth: Int) -> [FileNode] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let sorted = items.sorted {
            let aDir = (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let bDir = (try? $1.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if aDir != bDir { return aDir && !bDir }
            return $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
        }

        return sorted.map { item in
            let values = try? item.resourceValues(forKeys: [.isDirectoryKey])
            let isDir = values?.isDirectory ?? false
            let children: [FileNode]
            if isDir, depth < maxDepth {
                children = buildTree(at: item, depth: depth + 1, maxDepth: maxDepth)
            } else {
                children = []
            }
            return FileNode(
                id: item,
                name: item.lastPathComponent,
                url: item,
                isDirectory: isDir,
                children: children
            )
        }
    }

    func saveSelected() {
        guard let doc = selectedDocument else { return }
        if let url = doc.fileURL {
            write(doc, to: url)
        } else {
            saveSelectedAs()
        }
    }

    func saveSelectedAs() {
        guard let doc = selectedDocument else { return }
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = doc.title
        panel.allowedContentTypes = [.plainText, .sourceCode, .data]
        if let folderURL {
            panel.directoryURL = folderURL
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        write(doc, to: url)
    }

    private func write(_ doc: TextDocument, to url: URL) {
        do {
            try doc.content.write(to: url, atomically: true, encoding: .utf8)
            doc.markSaved(at: url.standardizedFileURL)
            refreshFileTree()
            notify()
        } catch {
            presentError(L10n.t("无法保存：\(error.localizedDescription)", "Could not save: \(error.localizedDescription)"))
        }
    }

    func presentOpenFilesPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.item]
        if panel.runModal() == .OK {
            openFiles(urls: panel.urls)
        }
    }

    func presentOpenFolderPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            openFolder(url)
        }
    }

    func perform(_ action: EditorAction) {
        switch action {
        case .newFile:
            newUntitled()
        case .openFile:
            presentOpenFilesPanel()
        case .openFolder:
            presentOpenFolderPanel()
        case .save:
            saveSelected()
        case .saveAs:
            saveSelectedAs()
        case .closeTab:
            if let id = selectedDocumentID {
                close(id)
            }
        case .find:
            showFindBar = true
            showReplace = false
            notify()
        case .replace:
            showFindBar = true
            showReplace = true
            notify()
        case .commandPalette:
            NotificationCenter.default.post(name: Notification.Name("MacTextShowCommandPalette"), object: nil)
        case .goToLine:
            NotificationCenter.default.post(name: Notification.Name("MacTextShowGoToLine"), object: nil)
        case .toggleSidebar:
            showSidebar.toggle()
            notify()
        case .softWrap:
            softWrap.toggle()
            notify()
        case .nextTheme:
            cycleTheme()
        case .biggerFont:
            adjustFontSize(by: Self.fontSizeStep)
        case .smallerFont:
            adjustFontSize(by: -Self.fontSizeStep)
        case .preferences:
            showPreferences()
        }
    }

    func setFontSize(_ size: CGFloat) {
        let clamped = min(Self.fontSizeMax, max(Self.fontSizeMin, size.rounded()))
        guard abs(clamped - fontSize) > 0.01 else { return }
        fontSize = clamped
        notify()
    }

    func adjustFontSize(by delta: CGFloat) {
        setFontSize(fontSize + delta)
    }

    func cycleTheme() {
        let themes = EditorTheme.all
        guard let idx = themes.firstIndex(where: { $0.name == theme.name }) else {
            applyTheme(.ink)
            return
        }
        applyTheme(themes[(idx + 1) % themes.count])
    }

    func setTheme(named name: String) {
        guard let match = EditorTheme.named(name) else { return }
        guard match.name != theme.name else { return }
        applyTheme(match)
    }

    private func applyTheme(_ newTheme: EditorTheme) {
        theme = newTheme
        NSApp.appearance = NSAppearance(named: newTheme.appearanceName)
        notify()
    }

    func showPreferences() {
        PreferencesWindowController.shared.show()
    }

    private func migratedTheme(from legacyName: String) -> EditorTheme? {
        switch legacyName {
        case "Monokai", "Midnight": return .ink
        case "Graphite": return .black
        default: return nil
        }
    }

    func filteredCommands(query: String) -> [EditorAction] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return Array(EditorAction.allCases) }
        return EditorAction.allCases.filter { action in
            action.title.lowercased().contains(q)
                || action.keywords.contains { $0.contains(q) || q.contains($0) }
        }
    }

    func requestFindNext(forward: Bool = true) {
        findDirectionForward = forward
        NotificationCenter.default.post(
            name: .macTextFindNext,
            object: nil,
            userInfo: ["forward": forward, "query": findQuery]
        )
    }

    func requestReplaceOne() {
        NotificationCenter.default.post(
            name: .macTextReplaceOne,
            object: nil,
            userInfo: ["find": findQuery, "replace": replaceQuery]
        )
    }

    func requestReplaceAll() {
        NotificationCenter.default.post(
            name: .macTextReplaceAll,
            object: nil,
            userInfo: ["find": findQuery, "replace": replaceQuery]
        )
    }

    func requestGoToLine(_ line: Int) {
        NotificationCenter.default.post(
            name: .macTextGoToLine,
            object: nil,
            userInfo: ["line": line]
        )
    }

    func documentContentDidChange() {
        notifyMeta()
    }

    func cursorDidChange() {
        notifyMeta()
    }

    func updateWindowFrame(_ frame: NSRect) {
        windowFrame = frame
        schedulePersist()
    }

    @discardableResult
    func restoreSession() -> Bool {
        guard let session = SessionStore.load() else { return false }
        isRestoring = true
        defer { isRestoring = false }

        var restored: [TextDocument] = []
        for item in session.documents {
            let candidateURL = item.path.map { URL(fileURLWithPath: $0).standardizedFileURL }
            let fileExists = candidateURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false

            var content = item.content
            var dirty = item.isDirty
            var title = item.title
            var language = LanguageKind(rawValue: item.language) ?? .plain
            var fileURL: URL?
            var enableHighlight = content.utf8.count <= TextFileLoader.highlightLimitBytes

            if let url = candidateURL, fileExists {
                fileURL = url
                title = url.lastPathComponent
                language = LanguageKind.detect(from: url)
                if !dirty, let loaded = try? TextFileLoader.load(url: url) {
                    content = loaded.content
                    dirty = false
                    enableHighlight = loaded.shouldHighlight
                } else if dirty {
                    content = item.content
                    enableHighlight = content.utf8.count <= TextFileLoader.highlightLimitBytes
                }
            } else if candidateURL != nil {
                // Path remembered but file is gone — keep buffer as untitled.
                fileURL = nil
                dirty = true
                if title.isEmpty {
                    title = "untitled"
                }
            } else {
                fileURL = nil
                dirty = !content.isEmpty
                if title.isEmpty {
                    title = "untitled"
                }
            }

            let doc = TextDocument(
                id: item.id,
                title: title,
                fileURL: fileURL,
                content: content,
                isDirty: dirty,
                language: language,
                enableHighlight: enableHighlight
            )
            doc.cursorLine = max(1, item.cursorLine)
            doc.cursorColumn = max(1, item.cursorColumn)
            restored.append(doc)
        }

        guard !restored.isEmpty else { return false }

        documents = restored
        if let selected = session.selectedDocumentID,
           documents.contains(where: { $0.id == selected }) {
            selectedDocumentID = selected
            bootstrapSelectedID = selected
        } else {
            selectedDocumentID = documents.first?.id
            bootstrapSelectedID = selectedDocumentID
        }

        if let folderPath = session.folderPath {
            let folder = URL(fileURLWithPath: folderPath).standardizedFileURL
            if FileManager.default.fileExists(atPath: folder.path) {
                folderURL = folder
                refreshFileTree()
            }
        }

        showSidebar = session.showSidebar
        softWrap = session.softWrap
        if let auto = session.autoSaveToDisk {
            autoSaveToDisk = auto
        }
        if let size = session.fontSize {
            fontSize = min(Self.fontSizeMax, max(Self.fontSizeMin, CGFloat(size)))
        }
        if let match = EditorTheme.named(session.themeName)
            ?? migratedTheme(from: session.themeName) {
            theme = match
            NSApp.appearance = NSAppearance(named: match.appearanceName)
        }
        if let frameString = session.windowFrame {
            windowFrame = NSRectFromString(frameString)
        }
        return true
    }

    func persistSessionNow() {
        persistWorkItem?.cancel()
        persistWorkItem = nil
        guard !isRestoring else { return }

        // Always pull latest buffer text from open editors before writing.
        WindowManager.shared.flushAllEditors()

        if autoSaveToDisk {
            autoSaveDirtyFilesToDisk()
        }

        let docs = documents.map { doc -> SessionDocument in
            SessionDocument(
                id: doc.id,
                title: doc.title,
                path: doc.fileURL?.path,
                content: doc.content,
                isDirty: doc.isDirty,
                language: doc.language.rawValue,
                cursorLine: doc.cursorLine,
                cursorColumn: doc.cursorColumn
            )
        }

        // Skip writing an empty default blank session on first launch with nothing typed.
        let isBlankDefault = docs.count == 1
            && docs[0].path == nil
            && docs[0].content.isEmpty
            && !docs[0].isDirty
            && folderURL == nil

        let session = EditorSession(
            version: 1,
            documents: docs,
            selectedDocumentID: WindowManager.shared.keyEditor?.selectedTabID ?? selectedDocumentID,
            folderPath: folderURL?.path,
            showSidebar: showSidebar,
            softWrap: softWrap,
            themeName: theme.name,
            windowFrame: windowFrame.map { NSStringFromRect($0) },
            fontSize: Double(fontSize),
            uiLanguage: L10n.language.rawValue,
            autoSaveToDisk: autoSaveToDisk
        )

        if isBlankDefault, SessionStore.load() == nil {
            return
        }
        SessionStore.save(session)
    }

    /// Write every dirty document that already has a file URL (Sublime save_on_focus_lost style).
    private func autoSaveDirtyFilesToDisk() {
        var savedAny = false
        for doc in documents where doc.isDirty {
            guard let url = doc.fileURL else { continue }
            do {
                try doc.content.write(to: url, atomically: true, encoding: .utf8)
                doc.isDirty = false
                savedAny = true
            } catch {
                // Keep dirty; session.json still holds the buffer.
            }
        }
        if savedAny {
            NotificationCenter.default.post(name: .macTextMetaChanged, object: self)
        }
    }

    func setAutoSaveToDisk(_ enabled: Bool) {
        guard autoSaveToDisk != enabled else { return }
        autoSaveToDisk = enabled
        notify()
        if enabled {
            persistSessionNow()
        }
    }

    private func schedulePersist() {
        guard !isRestoring else { return }
        persistWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.persistSessionNow()
        }
        persistWorkItem = work
        // Tight debounce so crash/kill loses at most ~0.25s of typing.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func presentError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "MacText"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
