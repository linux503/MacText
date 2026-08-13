import AppKit

/// Owns editor windows so tabs can be torn off and merged like Sublime.
final class WindowManager {
    static let shared = WindowManager()

    private(set) var windows: [MainWindowController] = []

    private init() {}

    var keyEditor: MainWindowController? {
        if let key = NSApp.keyWindow,
           let match = windows.first(where: { $0.window === key }) {
            return match
        }
        return windows.first { $0.window?.isVisible == true } ?? windows.first
    }

    @discardableResult
    func openInitialWindow() -> MainWindowController {
        let ids = DocumentStore.shared.documents.map(\.id)
        let selected = DocumentStore.shared.bootstrapSelectedID
        let frame = DocumentStore.shared.windowFrame
        return makeWindow(tabIDs: ids.isEmpty ? [] : ids, selectedID: selected, frame: frame, isPrimary: true)
    }

    @discardableResult
    func makeWindow(
        tabIDs: [UUID],
        selectedID: UUID?,
        frame: NSRect? = nil,
        origin: NSPoint? = nil,
        isPrimary: Bool = false
    ) -> MainWindowController {
        let controller = MainWindowController(
            tabIDs: tabIDs,
            selectedID: selectedID,
            savedFrame: frame,
            cascadeOrigin: origin,
            isPrimary: isPrimary
        )
        windows.append(controller)
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        return controller
    }

    func unregister(_ controller: MainWindowController) {
        windows.removeAll { $0 === controller }
    }

    /// Tear a tab out into a new window at the given screen point.
    func detachTab(_ documentID: UUID, from source: MainWindowController, screenPoint: NSPoint) {
        guard source.tabIDs.contains(documentID) else { return }
        source.removeTab(documentID, destroyIfEmpty: true)
        let origin = NSPoint(x: screenPoint.x - 120, y: screenPoint.y - 40)
        makeWindow(tabIDs: [documentID], selectedID: documentID, origin: origin)
        DocumentStore.shared.notify()
    }

    /// Move a tab into another window (merge).
    func moveTab(_ documentID: UUID, from source: MainWindowController, to target: MainWindowController, at index: Int?) {
        guard source !== target else {
            if let index {
                source.reorderTab(documentID, to: index)
            }
            return
        }
        guard source.tabIDs.contains(documentID) else { return }
        source.removeTab(documentID, destroyIfEmpty: true)
        target.insertTab(documentID, at: index)
        target.selectTab(documentID)
        DocumentStore.shared.notify()
    }

    func flushAllEditors() {
        for window in windows {
            window.flushEditorToDocument()
        }
    }

    func window(containing documentID: UUID) -> MainWindowController? {
        windows.first { $0.tabIDs.contains(documentID) }
    }
}
