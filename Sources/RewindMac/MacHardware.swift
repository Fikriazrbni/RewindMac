import Foundation

enum MacHardware {
    // Read once per launch, off the main actor when the model footer is selected.
    static let posterLabel: String? = {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["-detailLevel", "mini", "-timeout", "5", "-json", "SPHardwareDataType"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  let report = try JSONSerialization.jsonObject(with: data) as? [String: [[String: Any]]],
                  let hardware = report["SPHardwareDataType"]?.first,
                  let model = hardware["machine_name"] as? String, !model.isEmpty else { return nil }

            guard let chip = (hardware["chip_type"] ?? hardware["cpu_type"]) as? String,
                  !chip.isEmpty else { return model }
            let chipName = chip.hasPrefix("Apple ") ? String(chip.dropFirst("Apple ".count)) : chip
            return "\(model) · \(chipName)"
        } catch {
            return nil
        }
    }()
}
