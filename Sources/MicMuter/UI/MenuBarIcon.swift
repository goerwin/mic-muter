import AppKit

enum MenuBarIcon {
    private static let canvasSize = NSSize(width: 18, height: 16)
    private static let pointSize: CGFloat = 13

    static func image(for status: MicStatus) -> NSImage {
        let template = !status.tintsMenuBarIcon
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        var symbol = NSImage(systemSymbolName: status.menuBarSymbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)

        if !template,
            let configured = symbol?.withSymbolConfiguration(
                NSImage.SymbolConfiguration(hierarchicalColor: .controlAccentColor)
            )
        {
            symbol = configured
        }

        let pixelsWide = Int(canvasSize.width * 2)
        let pixelsHigh = Int(canvasSize.height * 2)
        guard
            let symbol,
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
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high

        let xOffset: CGFloat = status.usesSlashSymbol ? -0.6 : 0
        let drawRect = NSRect(
            x: (canvasSize.width - symbol.size.width) / 2 + xOffset,
            y: (canvasSize.height - symbol.size.height) / 2,
            width: symbol.size.width,
            height: symbol.size.height
        )
        symbol.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1)

        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: canvasSize)
        image.addRepresentation(rep)
        image.isTemplate = template
        return image
    }
}
