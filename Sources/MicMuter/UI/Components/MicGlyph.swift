import AppKit
import SwiftUI

enum MicGlyph {
    static let assetName = "Mic"
    static let assetSlashName = "MicSlash"

    static func assetName(isSlashed: Bool) -> String {
        isSlashed ? assetSlashName : assetName
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
