import AppKit
import Foundation

enum AppLinks {
    static let website = URL(string: "https://linux503.github.io/MacText/")!
    static let websiteZh = URL(string: "https://linux503.github.io/MacText/zh/")!
    static let github = URL(string: "https://github.com/linux503/MacText")!
    static let releases = URL(string: "https://github.com/linux503/MacText/releases")!
    static let latestAPI = URL(string: "https://api.github.com/repos/linux503/MacText/releases/latest")!

    static var preferredWebsite: URL {
        L10n.isChinese ? websiteZh : website
    }
}

struct AppUpdateInfo {
    let version: String
    let tagName: String
    let releaseURL: URL
    let dmgURL: URL?
    let notes: String
}

enum UpdateChecker {
    private static let skippedKey = "mactext.skippedUpdateVersion"
    private static let lastCheckKey = "mactext.lastUpdateCheck"

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static var skippedVersion: String? {
        get { UserDefaults.standard.string(forKey: skippedKey) }
        set { UserDefaults.standard.set(newValue, forKey: skippedKey) }
    }

    static func check(manual: Bool, completion: @escaping (Result<AppUpdateInfo?, Error>) -> Void) {
        var request = URLRequest(url: AppLinks.latestAPI, timeoutInterval: 15)
        request.setValue("MacText/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let data,
                  let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "MacText.Update", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: L10n.updateCheckFailed
                    ])))
                }
                return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let tag = (json?["tag_name"] as? String) ?? ""
                let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
                let html = (json?["html_url"] as? String).flatMap(URL.init(string:)) ?? AppLinks.releases
                let body = (json?["body"] as? String) ?? ""
                var dmg: URL?
                if let assets = json?["assets"] as? [[String: Any]] {
                    for asset in assets {
                        let name = (asset["name"] as? String) ?? ""
                        if name.lowercased().hasSuffix(".dmg"),
                           let urlStr = asset["browser_download_url"] as? String,
                           let url = URL(string: urlStr) {
                            dmg = url
                            break
                        }
                    }
                }

                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCheckKey)

                let info = AppUpdateInfo(
                    version: version,
                    tagName: tag.isEmpty ? "v\(version)" : tag,
                    releaseURL: html,
                    dmgURL: dmg,
                    notes: body
                )

                let newer = compareVersions(info.version, currentVersion) > 0
                DispatchQueue.main.async {
                    if newer {
                        if !manual, skippedVersion == info.version {
                            completion(.success(nil))
                        } else {
                            completion(.success(info))
                        }
                    } else {
                        completion(.success(nil))
                    }
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }

    /// Returns -1 / 0 / 1 for a < b / equal / a > b (numeric segments).
    static func compareVersions(_ a: String, _ b: String) -> Int {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        let n = max(pa.count, pb.count)
        for i in 0..<n {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x < y ? -1 : 1 }
        }
        return 0
    }

    static func presentResult(manual: Bool, result: Result<AppUpdateInfo?, Error>) {
        switch result {
        case .failure(let error):
            guard manual else { return }
            let alert = NSAlert()
            alert.messageText = L10n.checkForUpdates
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: L10n.ok)
            alert.runModal()

        case .success(let info):
            guard let info else {
                if manual {
                    let alert = NSAlert()
                    alert.messageText = L10n.upToDateTitle
                    alert.informativeText = String(format: L10n.upToDateBody, currentVersion)
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: L10n.ok)
                    alert.runModal()
                }
                return
            }
            presentUpdate(info)
        }
    }

    static func presentUpdate(_ info: AppUpdateInfo) {
        let alert = NSAlert()
        alert.messageText = L10n.updateAvailableTitle
        alert.informativeText = String(
            format: L10n.updateAvailableBody,
            info.version,
            currentVersion
        )
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.downloadUpdate)
        alert.addButton(withTitle: L10n.skipThisVersion)
        alert.addButton(withTitle: L10n.later)

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            NSWorkspace.shared.open(info.dmgURL ?? info.releaseURL)
        case .alertSecondButtonReturn:
            skippedVersion = info.version
        default:
            break
        }
    }
}
