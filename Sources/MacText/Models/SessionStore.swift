import AppKit
import Foundation

struct SessionDocument: Codable {
    var id: UUID
    var title: String
    var path: String?
    var content: String
    var isDirty: Bool
    var language: String
    var cursorLine: Int
    var cursorColumn: Int
}

struct EditorSession: Codable {
    var version: Int
    var documents: [SessionDocument]
    var selectedDocumentID: UUID?
    var folderPath: String?
    var showSidebar: Bool
    var softWrap: Bool
    var themeName: String
    var windowFrame: String?
    /// Editor monospaced font point size. Optional for older session files.
    var fontSize: Double?
}

enum SessionStore {
    private static let fileName = "session.json"

    static var sessionURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("MacText", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }

    static func load() -> EditorSession? {
        let url = sessionURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let session = try? JSONDecoder().decode(EditorSession.self, from: data),
              session.version >= 1,
              !session.documents.isEmpty
        else {
            return nil
        }
        return session
    }

    static func save(_ session: EditorSession) {
        do {
            let data = try JSONEncoder().encode(session)
            try data.write(to: sessionURL, options: [.atomic])
        } catch {
            // Best-effort persistence; ignore write failures.
        }
    }
}
