import Testing
import Foundation
@testable import BandwagonCore

@Test func credentialsAreData() throws {
    let c = try Credentials(contents: "# comment\nexport VEID='123'\nAPI_KEY=\"a&b=+$(touch nope)\"\n")
    #expect(c.veid == "123")
    #expect(c.apiKey == "a&b=+$(touch nope)")
    #expect(APIClient.form(["api_key": c.apiKey]) == "api_key=a%26b%3D%2B%24%28touch%20nope%29")
    #expect(throws: (any Error).self) { try Credentials(contents: "VEID=abc\nAPI_KEY=test") }
    #expect(throws: (any Error).self) { try Credentials(contents: "VEID=123\nAPI_KEY=") }
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
