// Renders an SVG to a square PNG with a transparent background (qlmanage paints an opaque one).
// usage: swift render-svg.swift in.svg size out.png [shadow]
// CoreSVG ignores SVG filters, so the app icon's body drop shadow is drawn here with NSShadow when "shadow" is given.
import AppKit

let a = CommandLine.arguments
guard a.count >= 4, let img = NSImage(contentsOf: URL(fileURLWithPath: a[1])), let s = Int(a[2]) else {
    print("usage: render-svg.swift in.svg size out.png [shadow]"); exit(1)
}
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: s, pixelsHigh: s, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high
if a.count > 4, a[4] == "shadow" {
    let k = CGFloat(s) / 1024
    let shadow = NSShadow()
    shadow.shadowOffset = NSSize(width: 0, height: -14 * k)
    shadow.shadowBlurRadius = 36 * k
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.set()
}
img.draw(in: NSRect(x: 0, y: 0, width: s, height: s))
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[3]))
