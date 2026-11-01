import AppKit
import Foundation
import Testing

// docs/specs/04-main-window.md (REQ-WIN-26, REQ-WIN-19): the committed icon pack and menu bar icon.

private let assets = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("ArtCraftAppManager/Assets.xcassets")

private struct ContentsImage: Decodable {
    var filename: String?
    var scale: String
    var size: String?
}

private struct Contents: Decodable { var images: [ContentsImage] }

private func loadContents(_ set: String) throws -> (folder: URL, images: [ContentsImage]) {
    let folder = assets.appendingPathComponent(set)
    let data = try Data(contentsOf: folder.appendingPathComponent("Contents.json"))
    return (folder, try JSONDecoder().decode(Contents.self, from: data).images)
}

private func bitmap(_ url: URL) throws -> NSBitmapImageRep {
    try #require(NSBitmapImageRep(data: Data(contentsOf: url)))
}

private func pixelSize(points: Int, scale: String) -> Int { points * (Int(scale.dropLast()) ?? 1) }

struct AppIconAssetTests {
    @Test("REQ-WIN-26 every app icon slot has a PNG of the right pixel size with transparent corners")
    func appIconPack() throws {
        let (folder, images) = try loadContents("AppIcon.appiconset")
        #expect(images.count == 10)
        for image in images {
            let name = try #require(image.filename, "slot \(image.size ?? "?")@\(image.scale) has no file")
            let rep = try bitmap(folder.appendingPathComponent(name))
            let size = try #require(image.size)
            let points = try #require(Int(size.split(separator: "x")[0]))
            let expected = pixelSize(points: points, scale: image.scale)
            #expect(rep.pixelsWide == expected && rep.pixelsHigh == expected, "\(name) should be \(expected) px")
            #expect(rep.hasAlpha)
            #expect(rep.colorAt(x: 0, y: 0)?.alphaComponent == 0, "\(name) corner must be transparent")
            #expect(rep.colorAt(x: rep.pixelsWide / 2, y: rep.pixelsHigh / 2)?.alphaComponent == 1)
        }
    }

    @Test("REQ-WIN-19 menu bar icon is a full-colour 18 pt image with 1x and 2x files and transparent corners")
    func menuBarIcon() throws {
        let (folder, images) = try loadContents("MenuBarIcon.imageset")
        #expect(Set(images.map(\.scale)) == ["1x", "2x"])
        for image in images {
            let name = try #require(image.filename)
            let rep = try bitmap(folder.appendingPathComponent(name))
            let expected = pixelSize(points: 18, scale: image.scale)
            #expect(rep.pixelsWide == expected && rep.pixelsHigh == expected, "\(name) should be \(expected) px")
            #expect(rep.colorAt(x: 0, y: 0)?.alphaComponent == 0, "\(name) corner must be transparent")
        }
        let raw = try String(contentsOf: folder.appendingPathComponent("Contents.json"), encoding: .utf8)
        #expect(raw.contains("\"template-rendering-intent\" : \"original\"") || raw.contains("\"template-rendering-intent\": \"original\""))
    }
}
