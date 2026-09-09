import Foundation

public protocol CommuteServiceProtocol: Sendable {
    var targetSSID: String { get }
    var targetURL: URL { get }
    func isCheckOutAllowed(at date: Date) -> Bool
    func timeUntilCheckOut(at date: Date) -> (hours: Int, minutes: Int, seconds: Int)?
    func checkInternalNetwork() async -> Bool
}

public final class CommuteService: CommuteServiceProtocol, @unchecked Sendable {
    public static let shared = CommuteService()

    public let targetSSID: String = "skaxedu"
    public let targetURL: URL = URL(string: "https://att.skala-ai.com/att-checkin")!

    private let kstTimeZone = TimeZone(identifier: "Asia/Seoul") ?? TimeZone(secondsFromGMT: 9 * 3600)!

    public init() {}

    public func isCheckOutAllowed(at date: Date = Date()) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = kstTimeZone

        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)

        return (hour > 17) || (hour == 17 && minute >= 50)
    }

    public func timeUntilCheckOut(at date: Date = Date()) -> (hours: Int, minutes: Int, seconds: Int)? {
        if isCheckOutAllowed(at: date) {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = kstTimeZone

        var targetComponents = calendar.dateComponents([.year, .month, .day], from: date)
        targetComponents.hour = 17
        targetComponents.minute = 50
        targetComponents.second = 0

        guard let targetDate = calendar.date(from: targetComponents) else {
            return nil
        }

        let diff = Int(targetDate.timeIntervalSince(date))
        if diff <= 0 { return nil }

        let hours = diff / 3600
        let minutes = (diff % 3600) / 60
        let seconds = diff % 60
        return (hours, minutes, seconds)
    }

    public func checkInternalNetwork() async -> Bool {
        // 1. Check current Wi-Fi SSID via networksetup or CLI if available
        let ssid = getCurrentWiFiSSID()
        if let ssid = ssid, ssid == targetSSID {
            return true
        }

        // 2. Reachability fallback: HEAD request to targetURL with short timeout
        var request = URLRequest(url: targetURL)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 2.0

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...499).contains(http.statusCode) {
                return true
            }
        } catch {
            // Unreachable outside internal network
        }

        return false
    }

    private func getCurrentWiFiSSID() -> String? {
        let pipe = Pipe()
        let errorPipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = ["-getairportnetwork", "en0"]
        process.standardOutput = pipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Format: "Current Wi-Fi Network: skaxedu"
                let prefix = "Current Wi-Fi Network: "
                if let range = output.range(of: prefix) {
                    let ssid = output[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                    return ssid.isEmpty ? nil : ssid
                }
            }
        } catch {
            return nil
        }
        return nil
    }
}
