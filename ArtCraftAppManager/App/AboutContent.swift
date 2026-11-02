import AppKit

/// Content of the standard About panel (REQ-WIN-28): disclaimer, links and credits text.
enum AboutContent {
    static let suiteWebsite = URL(string: "https://getartcraft.com")!
    static let suiteGitHubOrg = URL(string: "https://github.com/storytold")!

    static let disclaimer = "ArtCraft Application Manager is an independent project by Edgars Klepers. It is not affiliated with, endorsed by, or sponsored by the creators of the ArtCraft suite."

    /// The `credits` text: the disclaimer, then one clickable line per link.
    static func credits() -> NSAttributedString {
        let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        let base: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: NSColor.labelColor, .paragraphStyle: centered,
        ]
        let text = NSMutableAttributedString(string: disclaimer + "\n\n", attributes: base)
        func link(_ title: String, _ url: URL) -> NSAttributedString {
            var attributes = base
            attributes[.link] = url
            return NSAttributedString(string: title, attributes: attributes)
        }
        text.append(link("ArtCraft website", suiteWebsite))
        text.append(NSAttributedString(string: "\n", attributes: base))
        text.append(link("ArtCraft on GitHub", suiteGitHubOrg))
        return text
    }

    /// Opens the standard About panel with the Manager's own icon and the credits above.
    @MainActor static func showAboutPanel() {
        var options: [NSApplication.AboutPanelOptionKey: Any] = [.credits: credits()]
        if let icon = NSImage(named: "AppIcon") { options[.applicationIcon] = icon }
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: options)
    }
}
