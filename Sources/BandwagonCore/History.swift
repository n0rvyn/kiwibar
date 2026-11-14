import Foundation

public struct UsageSample: Sendable {
    public let date: Date
    public let cpu: Double?
    public let networkIn: Double?
    public let networkOut: Double?
    public let diskRead: Double?
    public let diskWrite: Double?
    public init?(_ fields: Payload) {
        guard let timestamp = fields["timestamp"]?.number, timestamp > 0 else { return nil }
        date = Date(timeIntervalSince1970: timestamp)
        func nonnegative(_ key: String) -> Double? { fields[key]?.number.flatMap { $0 >= 0 ? $0 : nil } }
        cpu = nonnegative("cpu_usage")
        networkIn = nonnegative("network_in_bytes"); networkOut = nonnegative("network_out_bytes")
        diskRead = nonnegative("disk_read_bytes"); diskWrite = nonnegative("disk_write_bytes")
    }
    public static func parse(_ payload: Payload) -> [UsageSample] {
        let records = payload["data"]?.array ?? payload["stats"]?.array ?? []
        return records.compactMap { $0.object.flatMap(UsageSample.init) }.sorted { $0.date < $1.date }
    }
    public static func recentWeek(_ samples: [UsageSample], now: Date = Date()) -> [UsageSample] {
        let start = now.addingTimeInterval(-7 * 24 * 60 * 60)
        return samples.filter { $0.date >= start && $0.date <= now }
    }
}
