import AppKit
import Foundation

enum AppLinks {
    static let website = URL(string: "https://linux503.github.io/MacText/")!
    static let websiteZh = URL(string: "https://linux503.github.io/MacText/zh/")!
    static let github = URL(string: "https://github.com/linux503/MacText")!
    static let releases = URL(string: "https://github.com/linux503/MacText/releases")!
    /// Stable, no GitHub API rate limit — updated with every release.
    static let versionJSON = URL(string: "https://linux503.github.io/MacText/version.json")!
    static let latestRedirect = URL(string: "https://github.com/linux503/MacText/releases/latest")!
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

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 20
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpAdditionalHeaders = [
            "User-Agent": "MacText/\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0")",
            "Accept": "application/json, text/plain, */*"
        ]
        return URLSession(configuration: config)
    }()

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static var skippedVersion: String? {
        get { UserDefaults.standard.string(forKey: skippedKey) }
        set { UserDefaults.standard.set(newValue, forKey: skippedKey) }
    }

    static func check(manual: Bool, completion: @escaping (Result<AppUpdateInfo?, Error>) -> Void) {
        // 1) Site version.json (no API rate limit)
        fetchVersionJSON { result in
            switch result {
            case .success(let info):
                finish(info: info, manual: manual, completion: completion)
            case .failure:
                // 2) GitHub /releases/latest redirect (also no API quota)
                fetchLatestViaRedirect { redirectResult in
                    switch redirectResult {
                    case .success(let info):
                        finish(info: info, manual: manual, completion: completion)
                    case .failure:
                        // 3) GitHub API last resort
                        fetchLatestViaAPI { apiResult in
                            switch apiResult {
                            case .success(let info):
                                finish(info: info, manual: manual, completion: completion)
                            case .failure(let error):
                                DispatchQueue.main.async { completion(.failure(error)) }
                            }
                        }
                    }
                }
            }
        }
    }

    private static func finish(
        info: AppUpdateInfo,
        manual: Bool,
        completion: @escaping (Result<AppUpdateInfo?, Error>) -> Void
    ) {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCheckKey)
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
    }

    // MARK: - Sources

    private static func fetchVersionJSON(completion: @escaping (Result<AppUpdateInfo, Error>) -> Void) {
        var request = URLRequest(url: AppLinks.versionJSON)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        session.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let data,
                  let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(.failure(makeError(L10n.updateCheckFailed)))
                return
            }
            // In-app updates follow the stable channel; beta is site-only.
            let channel = (json["stable"] as? [String: Any]) ?? json
            guard let version = channel["version"] as? String, !version.isEmpty else {
                completion(.failure(makeError(L10n.updateCheckFailed)))
                return
            }
            let tag = (channel["tag"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "v\(version)"
            let release = (channel["release"] as? String).flatMap(URL.init(string:))
                ?? URL(string: "https://github.com/linux503/MacText/releases/tag/\(tag)")!
            let dmg = (channel["dmg"] as? String).flatMap(URL.init(string:))
                ?? URL(string: "https://github.com/linux503/MacText/releases/download/\(tag)/MacText-\(version).dmg")
            let notes = (channel["notes"] as? String) ?? ""
            completion(.success(AppUpdateInfo(
                version: version,
                tagName: tag,
                releaseURL: release,
                dmgURL: dmg,
                notes: notes
            )))
        }.resume()
    }

    /// Follow /releases/latest → …/tag/vX.Y.Z without using the API.
    private static func fetchLatestViaRedirect(completion: @escaping (Result<AppUpdateInfo, Error>) -> Void) {
        var request = URLRequest(url: AppLinks.latestRedirect)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        session.dataTask(with: request) { _, response, error in
            if let error {
                completion(.failure(error))
                return
            }
            // URLSession follows redirects; response.url is the final tag page.
            let finalURL = response?.url
            let tag = tagFromReleaseURL(finalURL)
            guard let tag, !tag.isEmpty else {
                completion(.failure(makeError(L10n.updateCheckFailed)))
                return
            }
            let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            let release = URL(string: "https://github.com/linux503/MacText/releases/tag/\(tag)")!
            let dmg = URL(string: "https://github.com/linux503/MacText/releases/download/\(tag)/MacText-\(version).dmg")
            completion(.success(AppUpdateInfo(
                version: version,
                tagName: tag.hasPrefix("v") ? tag : "v\(version)",
                releaseURL: release,
                dmgURL: dmg,
                notes: ""
            )))
        }.resume()
    }

    private static func fetchLatestViaAPI(completion: @escaping (Result<AppUpdateInfo, Error>) -> Void) {
        var request = URLRequest(url: AppLinks.latestAPI)
        request.setValue("MacText/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        session.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard let data, (200..<300).contains(status) else {
                let message: String
                if status == 403 {
                    message = L10n.updateRateLimited
                } else {
                    message = L10n.updateCheckFailed
                }
                completion(.failure(makeError(message)))
                return
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else {
                completion(.failure(makeError(L10n.updateCheckFailed)))
                return
            }
            let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            let html = (json["html_url"] as? String).flatMap(URL.init(string:)) ?? AppLinks.releases
            let body = (json["body"] as? String) ?? ""
            var dmg: URL?
            if let assets = json["assets"] as? [[String: Any]] {
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
            completion(.success(AppUpdateInfo(
                version: version,
                tagName: tag,
                releaseURL: html,
                dmgURL: dmg,
                notes: body
            )))
        }.resume()
    }

    private static func tagFromReleaseURL(_ url: URL?) -> String? {
        guard let path = url?.path else { return nil }
        // /linux503/MacText/releases/tag/v1.1.1
        if let range = path.range(of: "/releases/tag/") {
            let tag = String(path[range.upperBound...]).split(separator: "/").first.map(String.init)
            return tag
        }
        return nil
    }

    private static func makeError(_ message: String) -> NSError {
        NSError(domain: "MacText.Update", code: 1, userInfo: [
            NSLocalizedDescriptionKey: message
        ])
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
            alert.addButton(withTitle: L10n.allReleases)
            if alert.runModal() == .alertSecondButtonReturn {
                NSWorkspace.shared.open(AppLinks.releases)
            }

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
