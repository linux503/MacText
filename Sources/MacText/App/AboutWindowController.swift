import AppKit

/// Custom About window with website / GitHub / update actions.
final class AboutWindowController: NSWindowController {
    static let shared = AboutWindowController()

    private let versionLabel = NSTextField(labelWithString: "")
    private let creditsLabel = NSTextField(wrappingLabelWithString: "")

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.about
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        refresh()
        window?.title = L10n.about
        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let icon = NSImageView(frame: .zero)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
            ?? Bundle.main.url(forResource: "MacTextIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            icon.image = image
        } else {
            icon.image = NSApp.applicationIconImage
        }

        let title = NSTextField(labelWithString: "MacText")
        title.font = NSFont.systemFont(ofSize: 22, weight: .semibold)
        title.alignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false

        versionLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .center
        versionLabel.translatesAutoresizingMaskIntoConstraints = false

        creditsLabel.font = NSFont.systemFont(ofSize: 12)
        creditsLabel.textColor = .secondaryLabelColor
        creditsLabel.alignment = .center
        creditsLabel.maximumNumberOfLines = 4
        creditsLabel.translatesAutoresizingMaskIntoConstraints = false

        let websiteBtn = NSButton(title: L10n.website, target: self, action: #selector(openWebsite))
        websiteBtn.bezelStyle = .rounded
        websiteBtn.translatesAutoresizingMaskIntoConstraints = false

        let githubBtn = NSButton(title: "GitHub", target: self, action: #selector(openGitHub))
        githubBtn.bezelStyle = .rounded
        githubBtn.translatesAutoresizingMaskIntoConstraints = false

        let updateBtn = NSButton(title: L10n.checkForUpdates, target: self, action: #selector(checkUpdates))
        updateBtn.bezelStyle = .rounded
        updateBtn.translatesAutoresizingMaskIntoConstraints = false

        let releasesBtn = NSButton(title: L10n.allReleases, target: self, action: #selector(openReleases))
        releasesBtn.bezelStyle = .rounded
        releasesBtn.translatesAutoresizingMaskIntoConstraints = false

        let row1 = NSStackView(views: [websiteBtn, githubBtn])
        row1.orientation = .horizontal
        row1.spacing = 12
        row1.distribution = .fillEqually
        row1.translatesAutoresizingMaskIntoConstraints = false

        let row2 = NSStackView(views: [updateBtn, releasesBtn])
        row2.orientation = .horizontal
        row2.spacing = 12
        row2.distribution = .fillEqually
        row2.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(icon)
        content.addSubview(title)
        content.addSubview(versionLabel)
        content.addSubview(creditsLabel)
        content.addSubview(row1)
        content.addSubview(row2)

        NSLayoutConstraint.activate([
            icon.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            icon.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            icon.widthAnchor.constraint(equalToConstant: 72),
            icon.heightAnchor.constraint(equalToConstant: 72),

            title.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 12),
            title.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            title.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),

            versionLabel.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            versionLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            versionLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),

            creditsLabel.topAnchor.constraint(equalTo: versionLabel.bottomAnchor, constant: 12),
            creditsLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            creditsLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),

            row1.topAnchor.constraint(equalTo: creditsLabel.bottomAnchor, constant: 20),
            row1.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            row1.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),

            row2.topAnchor.constraint(equalTo: row1.bottomAnchor, constant: 10),
            row2.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            row2.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),
            row2.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -20)
        ])
    }

    private func refresh() {
        let short = UpdateChecker.currentVersion
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        versionLabel.stringValue = "v\(short)  ·  build \(build)"
        creditsLabel.stringValue = L10n.aboutCredits
        window?.backgroundColor = DocumentStore.shared.theme.editorChrome
    }

    @objc private func openWebsite() {
        NSWorkspace.shared.open(AppLinks.preferredWebsite)
    }

    @objc private func openGitHub() {
        NSWorkspace.shared.open(AppLinks.github)
    }

    @objc private func openReleases() {
        NSWorkspace.shared.open(AppLinks.releases)
    }

    @objc private func checkUpdates() {
        UpdateChecker.check(manual: true) { result in
            UpdateChecker.presentResult(manual: true, result: result)
        }
    }
}
