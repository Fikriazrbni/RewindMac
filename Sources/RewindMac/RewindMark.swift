import CoreGraphics

/// The arc rewinds around a clock. The detached segments are recorded blocks of activity.
enum RewindMark {
    private static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private static let center = CGPoint(x: 512, y: 512)
    private static let radius: CGFloat = 260

    static func image(pixels: Int, badge: Bool) -> CGImage? {
        guard let context = CGContext(
            data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
            bytesPerRow: 0, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        let scale = CGFloat(pixels) / (badge ? 1024 : 680)
        context.scaleBy(x: scale, y: scale)
        if badge {
            drawBadge(in: context)
        } else {
            context.translateBy(x: -172, y: -172)
        }
        drawMark(in: context, colored: badge)
        return context.makeImage()
    }

    private static func drawBadge(in context: CGContext) {
        let outline = CGPath(
            roundedRect: CGRect(x: 64, y: 64, width: 896, height: 896),
            cornerWidth: 218, cornerHeight: 218, transform: nil
        )
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -15), blur: 28, color: color(0.06, 0.04, 0.12, alpha: 0.45))
        context.setFillColor(color(0.10, 0.07, 0.20))
        context.addPath(outline)
        context.fillPath()
        context.restoreGState()

        context.saveGState()
        context.addPath(outline)
        context.clip()
        context.drawLinearGradient(
            gradient([color(0.31, 0.21, 0.62), color(0.16, 0.10, 0.33), color(0.07, 0.05, 0.16)]),
            start: CGPoint(x: 150, y: 950), end: CGPoint(x: 850, y: 70),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
        let glow = CGPoint(x: 780, y: 810)
        context.drawRadialGradient(
            gradient([color(0.69, 0.44, 0.99, alpha: 0.32), color(0.69, 0.44, 0.99, alpha: 0)]),
            startCenter: glow, startRadius: 0, endCenter: glow, endRadius: 570, options: []
        )
        context.setStrokeColor(color(0.92, 0.84, 1, alpha: 0.13))
        context.setLineWidth(2)
        for ringRadius in [CGFloat(355), 391] {
            context.strokeEllipse(in: CGRect(
                x: center.x - ringRadius, y: center.y - ringRadius,
                width: 2 * ringRadius, height: 2 * ringRadius
            ))
        }
        context.restoreGState()

        context.setStrokeColor(color(0.91, 0.83, 1, alpha: 0.28))
        context.setLineWidth(3)
        context.addPath(outline)
        context.strokePath()
    }

    private static func drawMark(in context: CGContext, colored: Bool) {
        context.setLineCap(.round)
        context.setLineJoin(.round)
        let arrowEnd = CGPoint(x: 248, y: 573)
        let rewind = CGMutablePath()
        rewind.addArc(center: center, radius: radius, startAngle: radians(301), endAngle: radians(510), clockwise: false)
        rewind.addLine(to: arrowEnd)
        rewind.move(to: CGPoint(x: 228, y: 695))
        rewind.addLine(to: arrowEnd)
        rewind.addLine(to: CGPoint(x: 368, y: 603))
        context.setLineWidth(60)
        context.addPath(rewind)
        if colored {
            context.saveGState()
            context.replacePathWithStrokedPath()
            context.clip()
            context.drawLinearGradient(
                gradient([color(0.88, 1, 0.61), color(0.68, 0.98, 0.72), color(0.72, 0.66, 1)]),
                start: CGPoint(x: 260, y: 740), end: CGPoint(x: 800, y: 240),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
            context.restoreGState()
        } else {
            context.setStrokeColor(color(0, 0, 0))
            context.strokePath()
        }

        context.setLineWidth(60)
        context.setStrokeColor(colored ? color(0.72, 0.64, 1) : color(0, 0, 0))
        context.addArc(center: center, radius: radius, startAngle: radians(263), endAngle: radians(279), clockwise: false)
        context.strokePath()
        context.setStrokeColor(colored ? color(0.54, 0.42, 0.89) : color(0, 0, 0))
        context.addArc(center: center, radius: radius, startAngle: radians(227), endAngle: radians(241), clockwise: false)
        context.strokePath()

        context.setStrokeColor(colored ? color(0.98, 0.96, 1) : color(0, 0, 0))
        context.setLineWidth(51)
        context.move(to: CGPoint(x: 512, y: 654))
        context.addLine(to: center)
        context.addLine(to: CGPoint(x: 616, y: 445))
        context.strokePath()
    }

    private static func radians(_ degrees: CGFloat) -> CGFloat { degrees * .pi / 180 }

    private static func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, alpha: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    private static func gradient(_ colors: [CGColor]) -> CGGradient {
        CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: nil)!
    }
}
