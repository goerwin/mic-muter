import AppKit

@MainActor
enum MenuBarIcon {
    private static let canvasSize = NSSize(width: 18, height: 16)
    private static var cache: [CacheKey: NSImage] = [:]

    private struct CacheKey: Hashable {
        let status: MicStatus
        let appearance: String
    }

    static func image(for status: MicStatus) -> NSImage {
        let key = CacheKey(
            status: status,
            appearance: NSApp.effectiveAppearance.name.rawValue
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
        let symbolName = status.isSlashed ? "mic.slash.fill" : "mic.fill"
        let base =
            NSImage(named: name)
            ?? NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        guard let base else { return NSImage(size: canvasSize) }

        let opacity: CGFloat = status == .unmuted ? 1 : 0.55
        return fittedImage(from: base, opacity: opacity)
    }

    private static func fittedImage(from base: NSImage, opacity: CGFloat = 1) -> NSImage {
        let drawRect = fittedRect(for: base)

        let image = NSImage(size: canvasSize)
        image.lockFocus()
        base.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: opacity)
        image.unlockFocus()
        image.size = canvasSize
        image.isTemplate = true
        return image
    }

    private static func fittedRect(for base: NSImage) -> NSRect {
        let size = base.size
        guard size.width > 0, size.height > 0 else { return NSRect(origin: .zero, size: canvasSize) }
        let scale = min(canvasSize.width / size.width, canvasSize.height / size.height)
        let fitted = NSSize(width: size.width * scale, height: size.height * scale)
        return NSRect(
            x: (canvasSize.width - fitted.width) / 2, y: (canvasSize.height - fitted.height) / 2,
            width: fitted.width, height: fitted.height
        )
    }

    static func invalidateCache() {
        cache.removeAll()
    }
}
