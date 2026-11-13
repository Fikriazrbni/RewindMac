import AppKit

@main
enum MakeIcon {
    static func main() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for size in [16, 32, 64, 128, 256, 512, 1024] {
            let data = try png(pixels: size, badge: true)
            if [16, 32, 128, 256, 512].contains(size) {
                try data.write(to: directory.appendingPathComponent("icon_\(size)x\(size).png"))
            }
            if [32, 64, 256, 512, 1024].contains(size) {
                let points = size / 2
                try data.write(to: directory.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
            }
        }

        if CommandLine.arguments.count > 2 {
            let preview = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
            try FileManager.default.createDirectory(at: preview, withIntermediateDirectories: true)
            try png(pixels: 384, badge: true).write(to: preview.appendingPathComponent("RewindMac-icon.png"))
            try png(pixels: 36, badge: false).write(to: preview.appendingPathComponent("RewindMac-menu.png"))
        }
    }

    private static func png(pixels: Int, badge: Bool) throws -> Data {
        guard let image = RewindMark.image(pixels: pixels, badge: badge),
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }
}
