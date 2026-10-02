import AppKit
import Foundation

// Platform exports only: preserve the original artwork, transparency and shape.
let sourceURL = URL(fileURLWithPath: "assets/logo-original.png")
guard let source = NSBitmapImageRep(data: try Data(contentsOf: sourceURL)) else {
    fatalError("Unable to read assets/logo-original.png")
}
var minimumX = source.pixelsWide
var minimumY = source.pixelsHigh
var maximumX = 0
var maximumY = 0
for row in 0..<source.pixelsHigh {
    for column in 0..<source.pixelsWide {
        if (source.colorAt(x: column, y: row)?.alphaComponent ?? 0) > 0.05 {
            minimumX = min(minimumX, column)
            minimumY = min(minimumY, row)
            maximumX = max(maximumX, column)
            maximumY = max(maximumY, row)
        }
    }
}
guard maximumX > minimumX, maximumY > minimumY, let image = source.cgImage else {
    fatalError("Logo has no visible artwork")
}
let edge = 4
let crop = CGRect(x: max(0, minimumX - edge), y: max(0, minimumY - edge),
                  width: min(source.pixelsWide - minimumX + edge, maximumX - minimumX + 1 + edge * 2),
                  height: min(source.pixelsHigh - minimumY + edge, maximumY - minimumY + 1 + edge * 2))
guard let symbol = image.cropping(to: crop) else { fatalError("Unable to crop logo") }
let artwork = NSImage(cgImage: symbol, size: crop.size)

func export(size: Int, url: URL, template: Bool = false) throws {
    let canvasHeight = template ? 26 : size
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: canvasHeight,
                                        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Unable to allocate icon") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    let inset = template ? 0.0 : 0.07
    let extent = Double(size) * (1 - 2 * inset)
    let factor = min(extent / crop.width, Double(canvasHeight) * (1 - 2 * inset) / crop.height)
    let width = crop.width * factor
    let height = crop.height * factor
    artwork.draw(in: NSRect(x: (Double(size) - width) / 2, y: (Double(canvasHeight) - height) / 2,
                           width: width, height: height))
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Unable to encode PNG") }
    try png.write(to: url)
}

let fileManager = FileManager.default
let iconset = URL(fileURLWithPath: "assets/AppIcon.iconset")
try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try export(size: points, url: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try export(size: points * 2, url: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
try export(size: 1024, url: URL(fileURLWithPath: "assets/logo.png"))
try export(size: 44, url: URL(fileURLWithPath: "Sources/FloatingAyah/Resources/MenuBarIcon.png"), template: true)
print("Exported transparent master, menu-bar image, and ten iconset sizes. No enclosing shape added.")
