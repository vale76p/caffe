import AppKit

// Renderizza l'SF Symbol "cup.and.saucer" in un PNG quadrato trasparente.
// Uso: swift make_icon.swift <output.png> <dimensione>
let args = CommandLine.arguments
guard args.count == 3, let size = Double(args[2]), size > 0 else {
    FileHandle.standardError.write("uso: swift make_icon.swift <output.png> <size>\n".data(using: .utf8)!)
    exit(2)
}
guard let symbol = NSImage(systemSymbolName: "cup.and.saucer", accessibilityDescription: "Caffè"),
      let scaled = symbol.withSymbolConfiguration(.init(pointSize: size * 0.8, weight: .regular)) else {
    FileHandle.standardError.write("simbolo non disponibile\n".data(using: .utf8)!)
    exit(3)
}
let px = Int(size)
guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
    FileHandle.standardError.write("bitmap non creata\n".data(using: .utf8)!)
    exit(4)
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
scaled.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("png non codificato\n".data(using: .utf8)!)
    exit(5)
}
try! png.write(to: URL(fileURLWithPath: args[1]))
