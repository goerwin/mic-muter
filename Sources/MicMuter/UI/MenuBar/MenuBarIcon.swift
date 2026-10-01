import AppKit

@MainActor
enum MenuBarIcon {
    private static let canvasSize = NSSize(width: 18, height: 16)
    private static var cache: [CacheKey: NSImage] = [:]

    private struct CacheKey: Hashable {
        let status: MicStatus
        let appearance: String
        let accent: String
    }

    static func image(for status: MicStatus) -> NSImage {
        let key = CacheKey(
            status: status,
            appearance: NSApp.effectiveAppearance.name.rawValue,
            accent: status.tintsMenuBarIcon ? NSColor.controlAccentColor.description : "template"
        )

        if let cached = cache[key] {
            return cached
        }

        let rendered = render(status: status)

        if cache.count >= 48 { cache.removeAll(keepingCapacity: true) }
        cache[key] = rendered
        return rendered
    }

    private static func render(status: MicStatus) -> NSImage {
        let name = MicGlyph.assetName(isSlashed: status.isSlashed)
        guard let base = NSImage(named: name) else {
            return fallbackImage(for: status)
        }

        if status.tintsMenuBarIcon {
            return tintedImage(from: base, color: .controlAccentColor)
        }
        return fittedImage(from: base, isTemplate: true, opacity: 0.55)
    }

    private static func fittedImage(from base: NSImage, isTemplate: Bool, opacity: CGFloat = 1) -> NSImage {
        let drawRect = NSRect(origin: fittedOrigin, size: fittedSize)

        let image = NSImage(size: canvasSize)
        image.lockFocus()
        base.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: opacity)
        image.unlockFocus()
        image.size = canvasSize
        image.isTemplate = isTemplate
        return image
    }

    private static func tintedImage(from base: NSImage, color: NSColor) -> NSImage {
        let drawRect = NSRect(origin: fittedOrigin, size: fittedSize)

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

    private static var fittedSize: NSSize {
        let vectorSize = MicGlyph.vectorSize
        let scale = min(canvasSize.width / vectorSize.width, canvasSize.height / vectorSize.height)
        return NSSize(width: vectorSize.width * scale, height: vectorSize.height * scale)
    }

    private static var fittedOrigin: NSPoint {
        let size = fittedSize
        return NSPoint(x: (canvasSize.width - size.width) / 2, y: (canvasSize.height - size.height) / 2)
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
    }
}
