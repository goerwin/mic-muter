import AppKit

@main
struct MenuBarIconSmokeTest {
    @MainActor
    static func main() {
        _ = NSApplication.shared
        for status in MicStatus.allCases {
            let image = MenuBarIcon.image(for: status)
            guard let data = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: data) else {
                fatalError("No bitmap for \(status)")
            }
            let hasVisiblePixel = (0..<bitmap.pixelsWide).contains { x in
                (0..<bitmap.pixelsHigh).contains { y in
                    (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0
                }
            }
            precondition(hasVisiblePixel, "Missing-asset fallback is blank for \(status)")
            precondition(image.isTemplate, "Menu bar icons should adapt to the system appearance")
        }
        print("Menu bar icon fallback smoke test passed.")
    }
}
