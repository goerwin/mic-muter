import AppKit

enum MenuBarIcon {
    private static let canvasSize = NSSize(width: 18, height: 16)

    static func image(for status: MicStatus) -> NSImage {
        let pixelsWide = Int(canvasSize.width * 2)
        let pixelsHigh = Int(canvasSize.height * 2)
        guard
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: pixelsWide,
                pixelsHigh: pixelsHigh,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        else {
            return NSImage(size: canvasSize)
        }

        rep.size = canvasSize
        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current = context
        context?.imageInterpolation = .high

        if let cgContext = context?.cgContext {
            let color: CGColor =
                status.tintsMenuBarIcon ? NSColor.controlAccentColor.cgColor : NSColor.black.cgColor
            MicGlyph.draw(in: cgContext, canvasSize: canvasSize, color: color, isSlashed: status.isSlashed)
        }

        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: canvasSize)
        image.addRepresentation(rep)
        image.isTemplate = !status.tintsMenuBarIcon
        return image
    }
}
