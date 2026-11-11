import Foundation
import Observation
import BandwagonCore

@Observable @MainActor final class Monitor {
    var snapshot: Snapshot?
    var samples: [UsageSample] = []
    var limits: Payload?
    var updated: Date?
    var error: String?
    var historyError: String?
    var loading = false
    var configured = false
    var initializing = true
    @ObservationIgnored private let store: any CredentialStore
    @ObservationIgnored private var restored = false
    @ObservationIgnored private var revision = UUID()

    init(store: any CredentialStore = KeychainCredentialStore()) { self.store = store }
    var title: String {
        guard let snapshot else { return error == nil ? "—" : "!" }
        let percent = snapshot.transferFraction.map { String(format: "%.0f%%", $0 * 100) } ?? "—"
        return "\(percent)\(error == nil ? "" : " !")"
    }
    func restore() async {
        guard !restored else { return }
        restored = true
        defer { initializing = false }
        do { configured = try await store.load() != nil }
        catch { self.error = error.localizedDescription }
    }
    func savedCredentials() async throws -> Credentials? { try await store.load() }
    func saveCredentials(veid: String, apiKey: String) async throws {
        let credentials = try Credentials(veid: veid, apiKey: apiKey)
        try await store.save(credentials)
        revision = UUID()
        configured = true
        initializing = false
        snapshot = nil; samples = []; limits = nil; updated = nil
        error = nil; historyError = nil; loading = false
    }
    func refresh() async {
        guard configured, !loading else { return }
        let run = revision
        loading = true
        defer { if run == revision { loading = false } }
        do {
            guard let credentials = try await store.load() else {
                if run == revision { configured = false; error = nil }
                return
            }
            guard run == revision else { return }
            let client = APIClient(credentials: credentials)
            let live = try await client.fetch(.live)
            guard run == revision else { return }
            snapshot = Snapshot(live); updated = Date(); error = nil
            do {
                let history = try await client.fetch(.history)
                guard run == revision else { return }
                samples = UsageSample.parse(history); historyError = nil
            } catch { if run == revision { historyError = "Usage history could not be refreshed." } }
            do {
                let result = try await client.fetch(.limits)
                if run == revision { limits = result }
            } catch { if run == revision { limits = nil } }
        } catch {
            guard run == revision else { return }
            if let e = error as? MonitorError { self.error = e.localizedDescription }
            else if let e = error as? KeychainError { self.error = e.localizedDescription }
            else if let e = error as? URLError { self.error = "Cannot reach Bandwagon (network error \(e.code.rawValue))." }
            else { self.error = "Cannot read Bandwagon metrics (error \((error as NSError).code))." }
        }
    }
}
