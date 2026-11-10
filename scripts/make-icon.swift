// Draws the 1024x1024 app icon PNG. Usage: swift scripts/make-icon.swift <output.png>
import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <output.png>\n".utf8))
    exit(64)
}

let size = 1024
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    FileHandle.standardError.write(Data("could not create drawing context\n".utf8))
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

// macOS icon grid: an 824pt rounded square centred on a 1024 canvas.
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
shadow.shadowBlurRadius = 24
shadow.shadowOffset = NSSize(width: 0, height: -10)
NSGraphicsContext.saveGraphicsState()
shadow.set()
NSColor.white.setFill()
shape.fill()
NSGraphicsContext.restoreGraphicsState()

let gradient = NSGradient(
    starting: NSColor(srgbRed: 0.30, green: 0.68, blue: 1.00, alpha: 1),
    ending: NSColor(srgbRed: 0.03, green: 0.33, blue: 0.86, alpha: 1)
)
gradient?.draw(in: shape, angle: -90)

/// Draws an SF Symbol in a single colour, centred on the canvas and nudged by `offset`.
func drawSymbol(_ name: String, pointSize: CGFloat, weight: NSFont.Weight, color: NSColor, offset: NSPoint = .zero) {
    let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
    guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(configuration) else {
        FileHandle.standardError.write(Data("missing symbol \(name)\n".utf8))
        exit(1)
    }
    let symbolSize = symbol.size
    let origin = NSPoint(
        x: (CGFloat(size) - symbolSize.width) / 2 + offset.x,
        y: (CGFloat(size) - symbolSize.height) / 2 + offset.y
    )
    symbol.draw(in: NSRect(origin: origin, size: symbolSize))
}

// A white cloud with blue sync arrows inside it.
drawSymbol("icloud.fill", pointSize: 470, weight: .regular, color: .white)
drawSymbol("arrow.triangle.2.circlepath", pointSize: 190, weight: .bold,
           color: NSColor(srgbRed: 0.05, green: 0.40, blue: 0.92, alpha: 1),
           offset: NSPoint(x: 0, y: -22))

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("could not encode PNG\n".utf8))
    exit(1)
}
do {
    try png.write(to: URL(fileURLWithPath: arguments[1]))
} catch {
    FileHandle.standardError.write(Data("could not write icon: \(error)\n".utf8))
    exit(1)
}
