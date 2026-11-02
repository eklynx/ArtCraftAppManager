import AppKit
import Testing
@testable import ArtCraftAppManager

// docs/specs/04-main-window.md (REQ-WIN-28): About panel content.
struct AboutContentTests {
    @Test("REQ-WIN-28 credits contain the non-affiliation disclaimer")
    func disclaimer() {
        let text = AboutContent.credits().string
        #expect(text.contains("not affiliated with"))
        #expect(text.contains("Edgars Klepers"))
    }

    @Test("REQ-WIN-28 credits link to the Suite website and GitHub organisation")
    func links() {
        let credits = AboutContent.credits()
        var urls: [URL] = []
        credits.enumerateAttribute(.link, in: NSRange(location: 0, length: credits.length)) { value, _, _ in
            if let url = value as? URL { urls.append(url) }
        }
        #expect(urls == [URL(string: "https://getartcraft.com")!, URL(string: "https://github.com/storytold")!])
    }

    @Test("REQ-WIN-28 the AppIcon image the panel shows exists")
    func iconExists() {
        #expect(NSImage(named: "AppIcon") != nil)
    }
}
