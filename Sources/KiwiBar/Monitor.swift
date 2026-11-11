import Foundation
import BandwagonCore
import Combine

@MainActor final class Monitor: ObservableObject {
    @Published var snapshot: Snapshot?
    @Published var history: Payload?
    @Published var samples: [UsageSample] = []
    @Published var limits: Payload?
    @Published var updated: Date?
    @Published var error: String?
    @Published var historyError: String?
    @Published var loading = false
    let envURL: URL
    var onChange: (() -> Void)?
    init(envURL: URL) { self.envURL = envURL }
    var title: String {
        guard let snapshot else { return error == nil ? "BWH …" : "BWH !" }
        let percent = snapshot.transferFraction.map { String(format: "%.0f%%", $0 * 100) } ?? "—"
        return "\(percent)\(error == nil ? "" : " !")"
    }
    func refresh() async {
        guard !loading else { return }
        loading = true; onChange?()
        defer { loading = false; onChange?() }
        do {
            let credentials: Credentials
            do { credentials = try Credentials(contents: String(contentsOf: envURL, encoding: .utf8)) }
            catch { throw MonitorError.credentials }
            let client = APIClient(credentials: credentials)
            let live = try await client.fetch(.live)
            snapshot = Snapshot(live); updated = Date(); error = nil; onChange?()
            do { history = try await client.fetch(.history); samples = UsageSample.parse(history ?? [:]); historyError = nil }
            catch { historyError = "Usage history could not be refreshed." }
            do { limits = try await client.fetch(.limits) }
            catch { limits = nil }
        } catch {
            if let e = error as? MonitorError { self.error = e.localizedDescription }
            else if let e = error as? URLError {
                self.error = "Cannot reach Bandwagon (network error \(e.code.rawValue))."
            } else {
                let e = error as NSError
                if e.domain == NSCocoaErrorDomain { self.error = "Cannot read Bandwagon response (Cocoa error \(e.code))." }
                else { self.error = "Cannot read Bandwagon metrics (error \(e.code))." }
            }
        }
    }
}
