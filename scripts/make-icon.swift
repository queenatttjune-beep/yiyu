// Draws the 1024 px app icon: 隅 in gold on 磁青 paper.
// Usage: swift scripts/make-icon.swift <output.png>
import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <output.png>\n".utf8))
    exit(64)
}

let canvas: CGFloat = 1024
// macOS icon grid: an 824 pt body centred on the 1024 canvas.
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let paper = NSColor(srgbRed: 0x1E / 255, green: 0x2B / 255, blue: 0x4D / 255, alpha: 1)
let paperDeep = NSColor(srgbRed: 0x16 / 255, green: 0x20 / 255, blue: 0x3B / 255, alpha: 1)
let gold = NSColor(srgbRed: 0xC8 / 255, green: 0xA9 / 255, blue: 0x6A / 255, alpha: 1)

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    FileHandle.standardError.write(Data("could not create a drawing context\n".utf8))
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
NSGradient(starting: paper, ending: paperDeep)?.draw(in: shape, angle: -90)

let inner = body.insetBy(dx: 44, dy: 44)
let frame = NSBezierPath(roundedRect: inner, xRadius: 146, yRadius: 146)
frame.lineWidth = 6
gold.withAlphaComponent(0.55).setStroke()
frame.stroke()

// The filled corner square echoes the menu bar icon: 一隅, one corner.
let cornerSize: CGFloat = 104
let corner = NSRect(
    x: inner.maxX - 78 - cornerSize + 40,
    y: inner.maxY - 78 - cornerSize + 40,
    width: cornerSize, height: cornerSize
)
gold.setFill()
NSBezierPath(roundedRect: corner, xRadius: 26, yRadius: 26).fill()

let font = NSFont(name: "STSongti-SC-Bold", size: 470) ?? NSFont.systemFont(ofSize: 470, weight: .bold)
let glyph = NSAttributedString(string: "隅", attributes: [.font: font, .foregroundColor: gold])
let glyphSize = glyph.size()
glyph.draw(at: NSPoint(x: body.midX - glyphSize.width / 2, y: body.midY - glyphSize.height / 2 - 18))

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("could not encode the icon\n".utf8))
    exit(1)
}
do {
    try png.write(to: URL(fileURLWithPath: arguments[1]))
} catch {
    FileHandle.standardError.write(Data("could not write \(arguments[1]): \(error)\n".utf8))
    exit(1)
}
