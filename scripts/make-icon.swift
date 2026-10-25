// Draws the 1024 px app icon: a moon gate in a 磁青 wall, gold moonlight inside,
// and a plum branch slanting in across the opening.
// Usage: swift scripts/make-icon.swift <output.png>
import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <output.png>\n".utf8))
    exit(64)
}

let canvas = 1024
// macOS icon grid: an 824 pt body centred on the 1024 canvas.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyRadius: CGFloat = 185
// The collapsed badge's 44 × 44 grid, stretched over the body, so both icons share one drawing.
let gridScale = body.width / 44
let gateCenter = CGPoint(x: 512, y: 512)
let gateRadius: CGFloat = 281

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

let wallTop = color(0x25345E)
let paperDeep = color(0x16203B)
let branchInk = color(0x111A30)
let gold = color(0xC8A96A)
let goldLight = color(0xE8D29C)
let goldDark = color(0x9A7B45)
let moonlight = color(0xEEDDAE)
let moonEdge = color(0xA3854D)
let blossomWhite = color(0xF6EFD9)

func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
    guard let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: locations
    ) else {
        FileHandle.standardError.write(Data("could not create a gradient\n".utf8))
        exit(1)
    }
    return gradient
}

func onGrid(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: body.minX + x * gridScale, y: body.minY + y * gridScale)
}

func polyline(_ points: [(CGFloat, CGFloat)]) -> CGPath {
    let path = CGMutablePath()
    path.addLines(between: points.map { onGrid($0.0, $0.1) })
    return path
}

func circle(_ center: CGPoint, _ radius: CGFloat) -> CGPath {
    CGPath(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2), transform: nil)
}

guard let context = CGContext(
    data: nil, width: canvas, height: canvas, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    FileHandle.standardError.write(Data("could not create a drawing context\n".utf8))
    exit(1)
}
// Draw top-down, like the badge's grid.
context.translateBy(x: 0, y: CGFloat(canvas))
context.scaleBy(x: 1, y: -1)

let bodyPath = CGPath(roundedRect: body, cornerWidth: bodyRadius, cornerHeight: bodyRadius, transform: nil)

// Soft drop shadow under the body. Shadow offsets ignore the flip, so negative is down.
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.32))
context.addPath(bodyPath)
context.setFillColor(paperDeep)
context.fillPath()
context.restoreGState()

context.saveGState()
context.addPath(bodyPath)
context.clip()

// The wall: 磁青, a little lighter at the top.
context.drawLinearGradient(
    gradient([wallTop, paperDeep], [0, 1]),
    start: CGPoint(x: 0, y: body.minY), end: CGPoint(x: 0, y: body.maxY), options: []
)

// Gold moonlight through the opening, brightest towards the upper left.
let opening = circle(gateCenter, gateRadius)
context.saveGState()
context.addPath(opening)
context.clip()
let glow = CGPoint(x: gateCenter.x - 0.1 * gateRadius * 2, y: gateCenter.y - 0.14 * gateRadius * 2)
context.drawRadialGradient(
    gradient([moonlight, gold, moonEdge], [0, 0.55, 1]),
    startCenter: glow, startRadius: 0, endCenter: glow, endRadius: 0.78 * gateRadius * 2,
    options: [.drawsAfterEndLocation]
)
// The wall's thickness shades the top of the opening: a blurred ring, drawn off canvas
// so that only its shadow lands here.
let offCanvas: CGFloat = 4000
context.setShadow(offset: CGSize(width: offCanvas, height: 0), blur: 34, color: color(0x0B1222, 0.5))
context.addPath(circle(CGPoint(x: gateCenter.x - offCanvas, y: gateCenter.y - 28), 300))
context.setLineWidth(46)
context.setStrokeColor(color(0x000000))
context.strokePath()
context.restoreGState()

// The gate's gilded rim.
context.saveGState()
context.addPath(circle(gateCenter, gateRadius + 6))
context.setLineWidth(13)
context.replacePathWithStrokedPath()
context.clip()
let rimBox = CGRect(x: gateCenter.x - gateRadius, y: gateCenter.y - gateRadius, width: gateRadius * 2, height: gateRadius * 2)
context.drawLinearGradient(
    gradient([goldLight, gold, goldDark], [0, 0.5, 1]),
    start: CGPoint(x: rimBox.minX, y: rimBox.minY), end: CGPoint(x: rimBox.maxX, y: rimBox.maxY), options: []
)
context.restoreGState()

// The plum branch, in silhouette against the moonlight. Same lines as the badge, finer and fuller.
let trunk = polyline([(5, 35.2), (11, 31.4), (14.6, 27.4), (20.4, 24.6)])
let bough = polyline([(20.4, 24.6), (23.8, 20), (31.6, 16.2)])
let twigs = [
    polyline([(14.6, 27.4), (13.8, 23.8)]), polyline([(23.8, 20), (23.4, 17)]),
    polyline([(27.4, 18.1), (29.4, 21.4)]), polyline([(9.2, 32.5), (8.4, 29.6)]),
    polyline([(17.4, 26), (18.8, 28.2)]),
]
context.setStrokeColor(branchInk)
context.setLineCap(.round)
context.setLineJoin(.round)
for (path, width) in [(trunk, 1.7), (bough, 1.1)] + twigs.map({ ($0, 0.7) }) {
    context.addPath(path)
    context.setLineWidth(width * gridScale)
    context.strokePath()
}

let blossoms: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
    (13.6, 21.8, 2.6), (23.3, 14.8, 2.9), (29.8, 22.2, 2.2), (8.2, 28.6, 1.9),
]
for (index, blossom) in blossoms.enumerated() {
    let turn = -90 + Double(index) * 23
    context.setFillColor(blossomWhite)
    for petal in 0..<5 {
        let angle = (turn + Double(petal) * 72) * .pi / 180
        let center = onGrid(blossom.x + cos(angle) * blossom.size * 0.6, blossom.y + sin(angle) * blossom.size * 0.6)
        context.addPath(circle(center, blossom.size * 0.44 * gridScale))
    }
    context.fillPath()
    context.setFillColor(goldDark)
    context.addPath(circle(onGrid(blossom.x, blossom.y), 0.5 * gridScale))
    context.fillPath()
}

let buds: [(x: CGFloat, y: CGFloat, radius: CGFloat)] = [
    (31.9, 15.9, 0.8), (27.6, 18.2, 0.65), (19.2, 28.8, 0.6), (16.6, 24, 0.55), (25.6, 21.4, 0.55),
]
context.setFillColor(blossomWhite)
for bud in buds {
    context.addPath(circle(onGrid(bud.x, bud.y), bud.radius * gridScale))
}
context.fillPath()

context.restoreGState()

guard let image = context.makeImage(),
      let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("could not encode the icon\n".utf8))
    exit(1)
}
do {
    try png.write(to: URL(fileURLWithPath: arguments[1]))
} catch {
    FileHandle.standardError.write(Data("could not write \(arguments[1]): \(error)\n".utf8))
    exit(1)
}
