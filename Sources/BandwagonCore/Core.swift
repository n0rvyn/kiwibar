import Foundation

public struct Credentials: Sendable {
    public let veid: String
    public let apiKey: String
    public init(contents: String) throws {
        var values: [String: String] = [:]
        for raw in contents.components(separatedBy: .newlines) {
            var line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("export ") { line = String(line.dropFirst(7)) }
            guard !line.hasPrefix("#"), let separator = line.firstIndex(of: "=") else { continue }
            let key = line[..<separator].trimmingCharacters(in: .whitespaces)
            var value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            if value.count >= 2, let first = value.first, (first == "\"" || first == "'"), value.last == first {
                value = String(value.dropFirst().dropLast())
            } else if let comment = value.range(of: " #") { value = String(value[..<comment.lowerBound]).trimmingCharacters(in: .whitespaces) }
            values[key] = value
        }
        guard let id = values["VEID"], !id.isEmpty, id.allSatisfy({ $0.isASCII && $0.isNumber }), let key = values["API_KEY"], !key.isEmpty else { throw MonitorError.credentials }
        veid = id; apiKey = key
    }
}

public enum MonitorError: Error, LocalizedError {
    case credentials, http(Int), api(Int), response, redirected
    public var errorDescription: String? {
        switch self {
        case .credentials: "Cannot read VEID and API_KEY from .env."
        case .http(let code): "Bandwagon returned HTTP \(code)."
        case .api(let code): "Bandwagon API error \(code)."
        case .response: "Bandwagon returned an invalid response."
        case .redirected: "Unexpected API redirect refused."
        }
    }
}

public enum Endpoint: String, CaseIterable, Sendable {
    case live = "getLiveServiceInfo", history = "getRawUsageStats", limits = "getRateLimitStatus"
}

public enum JSONValue: Decodable, Sendable {
    case number(Double), string(String), object([String: JSONValue]), array([JSONValue]), bool(Bool), null
    public init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([String: JSONValue].self) { self = .object(v) }
        else { self = .array(try c.decode([JSONValue].self)) }
    }
    public var number: Double? { switch self { case .number(let x): x.isFinite ? x : nil; case .string(let x): Double(x).flatMap { $0.isFinite ? $0 : nil }; case .bool(let x): x ? 1 : 0; default: nil } }
    public var string: String? { switch self { case .string(let x): x; case .number(let x): String(x); default: nil } }
    public var object: [String: JSONValue]? { if case .object(let x) = self { x } else { nil } }
    public var array: [JSONValue]? { if case .array(let x) = self { x } else { nil } }
}
public typealias Payload = [String: JSONValue]

public struct Snapshot: Sendable {
    public let fields: Payload
    public init(_ fields: Payload) { self.fields = fields }
    public func number(_ key: String) -> Double? { fields[key]?.number }
    public func text(_ key: String) -> String? { fields[key]?.string }
    public var multiplier: Double { let m = number("monthly_data_multiplier") ?? 1; return m > 0 ? m : 1 }
    public var transferUsed: Double? { number("data_counter").map { $0 * multiplier } }
    public var transferTotal: Double? { number("plan_monthly_data").map { $0 * multiplier } }
    public var transferFraction: Double? { guard let u = transferUsed, let t = transferTotal, u >= 0, t > 0 else { return nil }; return u / t }
    public var state: String { if number("suspended") == 1 { return "Suspended" }; let value = text("ve_status") ?? "Unavailable"; return value.prefix(1).uppercased() + value.dropFirst().lowercased() }
    public var addresses: [String] { fields["ip_addresses"]?.array?.compactMap(\.string) ?? [] }
    public var memoryUsed: Double? { guard let total = number("plan_ram"), let available = number("mem_available_kb"), total > 0 else { return nil }; return max(0, total - available * 1024) }
    public var swapUsed: Double? { guard let total = number("swap_total_kb"), let available = number("swap_available_kb") else { return nil }; return max(0, total - available) * 1024 }
}

private final class NoRedirect: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) { completionHandler(nil) }
}
public struct APIClient: Sendable {
    let credentials: Credentials
    let session: URLSession
    public init(credentials: Credentials) {
        self.credentials = credentials
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 35
        config.timeoutIntervalForResource = 45
        config.urlCache = nil
        config.httpCookieStorage = nil
        session = URLSession(configuration: config, delegate: NoRedirect(), delegateQueue: nil)
    }
    public func fetch(_ endpoint: Endpoint) async throws -> Payload {
        var request = URLRequest(url: URL(string: "https://api.64clouds.com/v1/" + endpoint.rawValue)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.form(["veid": credentials.veid, "api_key": credentials.apiKey]).data(using: .utf8)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw MonitorError.response }
        guard !(300..<400).contains(http.statusCode) else { throw MonitorError.redirected }
        guard http.statusCode == 200 else { throw MonitorError.http(http.statusCode) }
        return try Self.decode(data)
    }
    public static func form(_ values: [String: String]) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return values.sorted { $0.key < $1.key }.map { $0.key.addingPercentEncoding(withAllowedCharacters: allowed)! + "=" + $0.value.addingPercentEncoding(withAllowedCharacters: allowed)! }.joined(separator: "&")
    }
    public static func decode(_ data: Data) throws -> Payload {
        let result = try JSONDecoder().decode(Payload.self, from: data)
        guard let error = result["error"]?.number else { throw MonitorError.response }
        guard error == 0 else { guard let code = Int(exactly: error) else { throw MonitorError.response }; throw MonitorError.api(code) }
        return result
    }
}
