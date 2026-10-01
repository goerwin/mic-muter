import AppKit

enum MenuBarIcon {
    private static let canvasSize = NSSize(width: 18, height: 16)
    private static var cache: [MicStatus: NSImage] = [:]
    private static var cachedAppearance: String?
    private static var cachedAccent: String?

    static func image(for status: MicStatus) -> NSImage {
        let appearance = NSApp.effectiveAppearance.name.rawValue
        let accent = NSColor.controlAccentColor.description
        if cachedAppearance != appearance || cachedAccent != accent {
            cache.removeAll()
            cachedAppearance = appearance
            cachedAccent = accent
        }
        if let cached = cache[status] { return cached }

        let name = MicGlyph.assetName(isSlashed: status.isSlashed)
        guard let base = NSImage(named: name) else {
            return fallbackImage(for: status)
        }

        let image: NSImage
        if status.tintsMenuBarIcon {
            image = tintedImage(from: base, color: NSColor.controlAccentColor, canvasSize: canvasSize)
        } else {
            image = fittedImage(from: base, canvasSize: canvasSize, isTemplate: true, opacity: 0.55)
        }
        cache[status] = image
        return image
    }

    private static func fittedImage(from base: NSImage, canvasSize: NSSize, isTemplate: Bool, opacity: CGFloat = 1) -> NSImage {
        let vectorSize = MicGlyph.vectorSize
        let scale = min(canvasSize.width / vectorSize.width, canvasSize.height / vectorSize.height)
        let drawSize = NSSize(width: vectorSize.width * scale, height: vectorSize.height * scale)
        let origin = NSPoint(x: (canvasSize.width - drawSize.width) / 2, y: (canvasSize.height - drawSize.height) / 2)

        let image = NSImage(size: canvasSize)
        image.lockFocus()
        base.draw(in: NSRect(origin: origin, size: drawSize), from: .zero, operation: .sourceOver, fraction: opacity)
        image.unlockFocus()
        image.size = canvasSize
        image.isTemplate = isTemplate
        return image
    }

    private static func tintedImage(from base: NSImage, color: NSColor, canvasSize: NSSize) -> NSImage {
        let vectorSize = MicGlyph.vectorSize
        let scale = min(canvasSize.width / vectorSize.width, canvasSize.height / vectorSize.height)
        let drawSize = NSSize(width: vectorSize.width * scale, height: vectorSize.height * scale)
        let origin = NSPoint(x: (canvasSize.width - drawSize.width) / 2, y: (canvasSize.height - drawSize.height) / 2)
        let drawRect = NSRect(origin: origin, size: drawSize)

        let image = NSImage(size: canvasSize)
        image.lockFocus()
        base.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1)
        color.set()
        drawRect.fill(using: .sourceAtop)
        image.unlockFocus()
        image.size = canvasSize
        image.isTemplate = false
        return image
    }

    private static func fallbackImage(for status: MicStatus) -> NSImage {
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

    static func invalidateCache() {
        cache.removeAll()
        cachedAppearance = nil
        cachedAccent = nil
    }
}
