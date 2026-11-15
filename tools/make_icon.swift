import Cocoa

// 用法: make_icon <输出 .iconset 目录>
_ = NSApplication.shared
let outDir = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
    NSImage(size: image.size, flipped: false) { rect in
        image.draw(in: rect)
        color.set()
        rect.fill(using: .sourceAtop)
        return true
    }
}

func render(px: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let s = CGFloat(px)
    let inset = s * 0.1
    let rect = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
    NSGradient(starting: NSColor(calibratedRed: 1.00, green: 0.72, blue: 0.20, alpha: 1),
               ending:   NSColor(calibratedRed: 0.96, green: 0.45, blue: 0.08, alpha: 1))!
        .draw(in: path, angle: -90)

    let cfg = NSImage.SymbolConfiguration(pointSize: s * 0.5, weight: .regular)
    if let base = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: nil),
       let sym = base.withSymbolConfiguration(cfg) {
        let white = tinted(sym, .white)
        let size = sym.size
        white.draw(in: NSRect(x: (s - size.width) / 2, y: (s - size.height) / 2,
                              width: size.width, height: size.height))
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let sizes: [(Int, String)] = [
    (16, "icon_16x16"), (32, "icon_16x16@2x"),
    (32, "icon_32x32"), (64, "icon_32x32@2x"),
    (128, "icon_128x128"), (256, "icon_128x128@2x"),
    (256, "icon_256x256"), (512, "icon_256x256@2x"),
    (512, "icon_512x512"), (1024, "icon_512x512@2x"),
]
for (px, name) in sizes {
    try render(px: px).write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
}
