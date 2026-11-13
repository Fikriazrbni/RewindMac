import SwiftUI
import AppKit
import RewindCore

@MainActor
enum RecapExporter {
    static func png(poster: SharePoster) throws -> Data {
        let renderer = ImageRenderer(content: poster)
        renderer.scale = 2
        renderer.colorMode = .nonLinear
        renderer.isOpaque = true
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) { renderer.allowedDynamicRange = .standard }
        #endif
        guard let image = renderer.cgImage,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw StorageError(message: "The recap could not be rendered.")
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let standardImage = context.makeImage(),
              let data = NSBitmapImageRep(cgImage: standardImage).representation(using: .png, properties: [:]) else {
            throw StorageError(message: "The recap could not be encoded as PNG.")
        }
        return data
    }
}
