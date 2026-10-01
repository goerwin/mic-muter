import CoreGraphics
import SwiftUI

/// Single body path + optional slash. Avoids SF Symbols bounds mismatch.
enum MicGlyph {
    /// Design space is 64 x 64 with y increasing downward, matching SwiftUI.
    static let designSize: CGFloat = 64

    static let strokeWidth: CGFloat = 7

    private static let centerX: CGFloat = 32

    // Body capsule.
    private static let bodyWidth: CGFloat = 20
    private static let bodyHeight: CGFloat = 34
    private static let bodyTop: CGFloat = 4

    // Cradle plus stand.
    private static let cradleRadius: CGFloat = 17
    private static let cradleCenterY: CGFloat = 30
    private static let cradleTopY: CGFloat = 24
    private static let standBottomY: CGFloat = 56
    private static let baseHalfWidth: CGFloat = 10

    private static let slashStart = CGPoint(x: 9, y: 55)
    private static let slashEnd = CGPoint(x: 55, y: 9)

    /// Filled mic body. Identical in every state.
    static func body() -> CGPath {
        CGMutablePath(
            roundedRect: CGRect(
                x: centerX - bodyWidth / 2,
                y: bodyTop,
                width: bodyWidth,
                height: bodyHeight
            ),
            cornerWidth: bodyWidth / 2,
            cornerHeight: bodyWidth / 2,
            transform: nil
        )
    }

    /// Stroked cradle around the body, plus the stand and base.
    static func stand() -> CGPath {
        let path = CGMutablePath()
        let leftX = centerX - cradleRadius
        let rightX = centerX + cradleRadius

        path.move(to: CGPoint(x: leftX, y: cradleTopY))
        path.addLine(to: CGPoint(x: leftX, y: cradleCenterY))
        path.addArc(
            center: CGPoint(x: centerX, y: cradleCenterY),
            radius: cradleRadius,
            startAngle: .pi,
            endAngle: 0,
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rightX, y: cradleTopY))

        path.move(to: CGPoint(x: centerX, y: cradleCenterY + cradleRadius))
        path.addLine(to: CGPoint(x: centerX, y: standBottomY))

        path.move(to: CGPoint(x: centerX - baseHalfWidth, y: standBottomY))
        path.addLine(to: CGPoint(x: centerX + baseHalfWidth, y: standBottomY))
        return path
    }

    /// Diagonal stroke drawn over the mic for slashed states.
    static func slash() -> CGPath {
        let path = CGMutablePath()
        path.move(to: slashStart)
        path.addLine(to: slashEnd)
        return path
    }

    static func draw(in cgContext: CGContext, canvasSize: CGSize, color: CGColor, isSlashed: Bool) {
        let scale = min(canvasSize.width, canvasSize.height) / designSize
        let drawnSize = designSize * scale
        cgContext.saveGState()
        cgContext.translateBy(
            x: (canvasSize.width - drawnSize) / 2,
            y: (canvasSize.height - drawnSize) / 2 + drawnSize
        )
        cgContext.scaleBy(x: scale, y: -scale)
        cgContext.setFillColor(color)
        cgContext.setStrokeColor(color)
        cgContext.setLineWidth(strokeWidth)
        cgContext.setLineCap(.round)
        cgContext.setLineJoin(.round)
        cgContext.addPath(body())
        cgContext.fillPath()
        cgContext.addPath(stand())
        cgContext.strokePath()
        if isSlashed {
            cgContext.addPath(slash())
            cgContext.strokePath()
        }
        cgContext.restoreGState()
    }

    static func draw(in context: inout GraphicsContext, size: CGSize, isSlashed: Bool) {
        let scale = min(size.width, size.height) / designSize
        let drawnSize = designSize * scale
        context.translateBy(x: (size.width - drawnSize) / 2, y: (size.height - drawnSize) / 2)
        context.scaleBy(x: scale, y: scale)
        context.fill(Path(body()), with: .foreground)
        context.stroke(Path(stand()), with: .foreground, lineWidth: strokeWidth)
        if isSlashed {
            context.stroke(Path(slash()), with: .foreground, lineWidth: strokeWidth)
        }
    }
}

struct MicGlyphView: View {
    let isSlashed: Bool

    var body: some View {
        Canvas { context, size in
            var ctx = context
            MicGlyph.draw(in: &ctx, size: size, isSlashed: isSlashed)
        }
        .accessibilityHidden(true)
    }
}
