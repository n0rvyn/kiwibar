import Testing
import Foundation
import Security
@testable import BandwagonCore

@Test func credentialsAreData() throws {
    let c = try Credentials(veid: " 123 ", apiKey: "test-a&b=+$(touch nope)")
    #expect(c.veid == "123")
    #expect(c.apiKey == "test-a&b=+$(touch nope)")
    #expect(APIClient.form(["api_key": c.apiKey]) == "api_key=test-a%26b%3D%2B%24%28touch%20nope%29")
    #expect(throws: (any Error).self) { try Credentials(veid: "abc", apiKey: "test") }
    #expect(throws: (any Error).self) { try Credentials(veid: "123", apiKey: " ") }
}
@Test func accountingAndUnavailableMetrics() throws {
    let data = Data(#"{"error":0,"data_counter":"100","plan_monthly_data":1000,"monthly_data_multiplier":"2","plan_ram":2048,"mem_available_kb":"1"}"#.utf8)
    let s = Snapshot(try APIClient.decode(data))
    #expect(s.transferUsed == 200)
    #expect(s.transferTotal == 2000)
    #expect(s.transferFraction == 0.1)
    #expect(s.memoryUsed == 1024)
    #expect(s.swapUsed == nil)
    #expect(s.state == "Unavailable")
    #expect(Snapshot([:]).transferFraction == nil)
    #expect(Snapshot(["plan_monthly_data": .number(0)]).transferFraction == nil)
}
@Test func rejectsAPIErrorsAndMissingEnvelope() {
    #expect(throws: (any Error).self) { try APIClient.decode(Data(#"{"error":5,"message":"private data"}"#.utf8)) }
    #expect(throws: (any Error).self) { try APIClient.decode(Data(#"{"hostname":"host"}"#.utf8)) }
    #expect(Set(Endpoint.allCases.map(\.rawValue)) == Set(["getLiveServiceInfo", "getRawUsageStats", "getRateLimitStatus"]))
}
@Test func historyChronologyAndMissingValues() throws {
    let data = Data(#"{"error":0,"data":[{"timestamp":600,"cpu_usage":19,"network_in_bytes":100},{"timestamp":"300","cpu_usage":"16","disk_read_bytes":-1},{"cpu_usage":8}]}"#.utf8)
    let rows = UsageSample.parse(try APIClient.decode(data))
    #expect(rows.count == 2)
    #expect(rows[0].date.timeIntervalSince1970 == 300)
    #expect(rows[0].cpu == 16)
    #expect(rows[0].diskRead == nil)
    #expect(rows[1].networkIn == 100)
    #expect(Snapshot(["ve_status": .string("running")]).state == "Running")
}

@Test func historyShowsOnlyTheRollingWeek() throws {
    let now = Date(timeIntervalSince1970: 2_000_000)
    let cutoff = now.timeIntervalSince1970 - 7 * 24 * 60 * 60
    let payload: Payload = ["data": .array([
        .object(["timestamp": .number(cutoff - 1), "cpu_usage": .number(999)]),
        .object(["timestamp": .number(cutoff), "cpu_usage": .number(10)]),
        .object(["timestamp": .number(now.timeIntervalSince1970), "cpu_usage": .number(20)]),
        .object(["timestamp": .number(now.timeIntervalSince1970 + 1), "cpu_usage": .number(888)])
    ])]
    let all = UsageSample.parse(payload)
    let visible = UsageSample.recentWeek(all, now: now)
    #expect(visible.map(\.cpu) == [10, 20])
    #expect(visible.first?.date == now.addingTimeInterval(-604_800))
    #expect(UsageSample.recentWeek(all, now: now.addingTimeInterval(604_802)).isEmpty)
    #expect(UsageSample.recentWeek([], now: now).isEmpty)
    #expect(all.count == 4)
}

@Test func keychainRoundTripAndReplacement() async throws {
    let service = "com.norvyn.KiwiBar.tests.\(UUID().uuidString)"
    defer {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword,
                       kSecAttrService as String: service,
                       kSecAttrAccount as String: "bandwagon-host"] as CFDictionary)
    }
    let store = KeychainCredentialStore(service: service)
    #expect(try await store.load() == nil)
    try await store.save(Credentials(veid: "123", apiKey: "test-key-one"))
    let first = try #require(await store.load())
    #expect(first.veid == "123")
    #expect(first.apiKey == "test-key-one")
    try await store.save(Credentials(veid: "456", apiKey: "test-key-two"))
    let reopened = KeychainCredentialStore(service: service)
    let second = try #require(await reopened.load())
    #expect(second.veid == "456")
    #expect(second.apiKey == "test-key-two")
}
