import AppKit
import SwiftUI

struct RewindLogo: View {
    let size: CGFloat
    var badge = false

    static let menuImage = makeImage(pixels: 72, points: 18, badge: false)
    private static let glyph = makeImage(pixels: 256, points: 64, badge: false)
    private static let tile = makeImage(pixels: 512, points: 128, badge: true)

    var body: some View {
        Image(nsImage: badge ? Self.tile : Self.glyph)
            .renderingMode(badge ? .original : .template)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private static func makeImage(pixels: Int, points: CGFloat, badge: Bool) -> NSImage {
        let size = NSSize(width: points, height: points)
        let image = RewindMark.image(pixels: pixels, badge: badge)
            .map { NSImage(cgImage: $0, size: size) } ?? NSImage(size: size)
        image.isTemplate = !badge
        return image
    }
}
