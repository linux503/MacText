import AppKit

@main
enum MacTextMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // Paths passed on the command line (git / custom external editor / CLI).
        let urls = CommandLine.arguments.dropFirst().compactMap { arg -> URL? in
            if arg.hasPrefix("-") || arg.hasPrefix("+") { return nil }
            let url = URL(fileURLWithPath: arg).standardizedFileURL
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        if !urls.isEmpty {
            DispatchQueue.main.async {
                DocumentStore.shared.openLaunchURLs(urls)
            }
        }
        app.run()
    }
}
