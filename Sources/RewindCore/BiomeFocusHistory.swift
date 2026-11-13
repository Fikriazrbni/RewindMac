import Foundation
import zlib

/// Local App.InFocus segments are a fallback when newer macOS versions leave
/// little app usage in KnowledgeC. Only the SEGB v2 format is supported.
enum BiomeFocusHistory {
    private struct Event {
        var date: Date
        var bundle: String
        var started: Bool
    }

    static func read(directory: URL, interval: DateInterval) throws -> [ActivitySession] {
        let files = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey]
        )
        var events: [Event] = []
        var recognized = false
        var foundSegment = false
        for file in files where UInt64(file.lastPathComponent) != nil {
            let metadata = try file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard metadata.isRegularFile == true, (metadata.fileSize ?? 0) <= 32 * 1024 * 1024 else { continue }
            foundSegment = true
            let data = try Data(contentsOf: file)
            guard data.count >= 32, data.starts(with: "SEGB".utf8) else { continue }
            let count = Int(read32(data, 4))
            guard count <= (data.count - 32) / 16 else { continue }
            recognized = true
            let tableStart = data.count - count * 16
            var recordStart = 32
            for entry in 0..<count {
                let offset = data.count - (entry + 1) * 16
                let end = 32 + Int(read32(data, offset))
                if end == 32 { continue }
                guard end <= tableStart, end >= recordStart + 8 else { break }
                if read32(data, offset + 4) == 1 {
                    let payload = data[(recordStart + 8)..<end]
                    let checksum = payload.withUnsafeBytes {
                        crc32(0, $0.bindMemory(to: UInt8.self).baseAddress, UInt32($0.count))
                    }
                    if checksum == read32(data, recordStart), let event = decode(Data(payload)),
                       event.date >= interval.start.addingTimeInterval(-86_400), event.date <= interval.end {
                        events.append(event)
                    }
                }
                recordStart = (end + 3) & ~3
            }
        }
        if foundSegment && !recognized {
            throw StorageError(message: "This Mac’s app focus history uses an unsupported Biome format.")
        }
        var starts: [String: Date] = [:]
        var result: [ActivitySession] = []
        for event in events.sorted(by: { $0.date < $1.date }) {
            if event.started {
                starts[event.bundle] = event.date
            } else if let start = starts.removeValue(forKey: event.bundle),
                      event.date > start, event.date.timeIntervalSince(start) <= 86_400 {
                result.append(ActivitySession(
                    app: AppIdentity(event.bundle, event.bundle),
                    start: start, end: event.date, source: .screenTime
                ))
            }
        }
        return result
    }

    private static func decode(_ bytes: Data) -> Event? {
        var position = 0
        func varint() -> UInt64? {
            var value: UInt64 = 0
            for shift in stride(from: 0, to: 64, by: 7) {
                guard position < bytes.count else { return nil }
                let byte = bytes[position]
                position += 1
                if shift == 63 && byte > 1 { return nil }
                value |= UInt64(byte & 0x7f) << shift
                if byte < 0x80 { return value }
            }
            return nil
        }

        var kind: UInt64?
        var start: UInt64 = 0 // Protobuf can omit a false start flag.
        var timestamp: Double?
        var bundle: String?
        while position < bytes.count {
            guard let tag = varint(), tag >> 3 > 0 else { return nil }
            let field = tag >> 3
            switch tag & 7 {
            case 0:
                guard let value = varint() else { return nil }
                if field == 2 { kind = value }
                if field == 3 { start = value }
            case 1:
                guard bytes.count - position >= 8 else { return nil }
                if field == 4 {
                    let raw = bytes[position..<(position + 8)].withUnsafeBytes {
                        $0.loadUnaligned(as: UInt64.self)
                    }
                    timestamp = Double(bitPattern: UInt64(littleEndian: raw))
                }
                position += 8
            case 2:
                guard let length = varint(), length <= UInt64(bytes.count - position) else { return nil }
                if field == 6 {
                    bundle = String(data: bytes[position..<(position + Int(length))], encoding: .utf8)
                }
                position += Int(length)
            case 5:
                guard bytes.count - position >= 4 else { return nil }
                position += 4
            default:
                return nil
            }
        }
        guard kind == 1, start <= 1, let timestamp, timestamp.isFinite,
              let bundle, ScreenTimeImport.isBundleIdentifier(bundle) else { return nil }
        return Event(date: Date(timeIntervalSinceReferenceDate: timestamp), bundle: bundle, started: start == 1)
    }

    private static func read32(_ data: Data, _ offset: Int) -> UInt32 {
        data[offset..<(offset + 4)].withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self)) }
    }
}
