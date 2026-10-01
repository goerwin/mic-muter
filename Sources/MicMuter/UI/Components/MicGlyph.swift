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

    static func draw(in cgContext: CGContext, canvasSize: CGSize, color: CGColor, isSlashed: Bool) {
        guard let base = nsImage(isSlashed: isSlashed) else { return }
        let rect = fittedRect(canvasSize: canvasSize)

        cgContext.saveGState()
        if let cgImage = base.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            cgContext.saveGState()
            cgContext.translateBy(x: 0, y: canvasSize.height)
            cgContext.scaleBy(x: 1, y: -1)
            let flippedRect = CGRect(
                x: rect.origin.x,
                y: canvasSize.height - rect.origin.y - rect.height,
                width: rect.width,
                height: rect.height
            )
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

    static func fittedRect(canvasSize: CGSize) -> CGRect {
        let scale = min(canvasSize.width / vectorSize.width, canvasSize.height / vectorSize.height)
        let drawSize = CGSize(width: vectorSize.width * scale, height: vectorSize.height * scale)
        let origin = CGPoint(x: (canvasSize.width - drawSize.width) / 2, y: (canvasSize.height - drawSize.height) / 2)
        return CGRect(origin: origin, size: drawSize)
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
