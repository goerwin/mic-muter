import AppKit
import SwiftUI

enum MicGlyph {
    static let vectorSize = CGSize(width: 72, height: 87)
    static let assetName = "Mic"
    static let assetSlashName = "MicSlash"

    static func assetName(isSlashed: Bool) -> String {
        isSlashed ? assetSlashName : assetName
    }

    static func nsImage(isSlashed: Bool) -> NSImage? {
        NSImage(named: assetName(isSlashed: isSlashed))
    }

    @available(*, deprecated, message: "Use vector assets")
    static func body() -> CGPath {
        CGMutablePath(
            roundedRect: CGRect(x: 22, y: 7, width: 20, height: 30),
            cornerWidth: 10,
            cornerHeight: 10,
            transform: nil
        )
    }

    static func draw(in cgContext: CGContext, canvasSize: CGSize, color: CGColor, isSlashed: Bool) {
        guard let base = nsImage(isSlashed: isSlashed) else { return }
        let scale = min(canvasSize.width / vectorSize.width, canvasSize.height / vectorSize.height)
        let drawSize = CGSize(width: vectorSize.width * scale, height: vectorSize.height * scale)
        let origin = CGPoint(x: (canvasSize.width - drawSize.width) / 2, y: (canvasSize.height - drawSize.height) / 2)
        let rect = CGRect(origin: origin, size: drawSize)

        cgContext.saveGState()
        if let cgImage = base.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            cgContext.saveGState()
            cgContext.translateBy(x: 0, y: canvasSize.height)
            cgContext.scaleBy(x: 1, y: -1)
            let flippedRect = CGRect(x: rect.origin.x, y: canvasSize.height - rect.origin.y - rect.height, width: rect.width, height: rect.height)
            cgContext.clip(to: flippedRect, mask: cgImage)
            cgContext.setFillColor(color)
            cgContext.fill(CGRect(origin: .zero, size: canvasSize))
            cgContext.restoreGState()
        } else {
            let nsContext = NSGraphicsContext(cgContext: cgContext, flipped: false)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = nsContext
            NSColor(cgColor: color)?.set()
            NSRect(origin: .zero, size: canvasSize).fill(using: .sourceOver)
            base.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1)
            NSGraphicsContext.restoreGraphicsState()
        }
        cgContext.restoreGState()
    }

    static func draw(in context: inout GraphicsContext, size: CGSize, isSlashed: Bool) {
        let resolved = context.resolve(Image(assetName(isSlashed: isSlashed)).renderingMode(.template))
        let scale = min(size.width / vectorSize.width, size.height / vectorSize.height)
        let drawSize = CGSize(width: vectorSize.width * scale, height: vectorSize.height * scale)
        let origin = CGPoint(x: (size.width - drawSize.width) / 2, y: (size.height - drawSize.height) / 2)
        context.draw(resolved, in: CGRect(origin: origin, size: drawSize))
    }
}

struct MicGlyphView: View {
    let isSlashed: Bool

    var body: some View {
        Image(MicGlyph.assetName(isSlashed: isSlashed), bundle: .main)
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .accessibilityHidden(true)
    }
}
