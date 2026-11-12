import SwiftUI
import ServiceManagement
import BandwagonCore

private enum ConnectionLayout {
    static let width: CGFloat = 440
    static let inset: CGFloat = 24
    static let fieldInset: CGFloat = 16
    static let corner: CGFloat = 14
    static let icon: CGFloat = 48
}

struct SettingsView: View {
    @Bindable var monitor: Monitor
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focus: Field?
    @Environment(\.scenePhase) private var scenePhase
    @State private var loginStatus = SMAppService.mainApp.status
    @State private var loginError: String?
    @State private var changingLogin = false
    @State private var veid = ""
    @State private var apiKey = ""
    @State private var saving = false
    @State private var connecting = false
    @State private var loading = true
    @State private var error: String?
    private enum Field { case veid, apiKey }
    private var working: Bool { saving || connecting }
    private var valid: Bool { (try? Credentials(veid: veid, apiKey: apiKey)) != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: ConnectionLayout.inset) {
            HStack(spacing: ConnectionLayout.fieldInset) {
                Image(systemName: "server.rack")
                    .font(.title2).fontWeight(.medium).foregroundStyle(.teal)
                    .frame(width: ConnectionLayout.icon, height: ConnectionLayout.icon)
                    .background(.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: ConnectionLayout.corner))
                VStack(alignment: .leading, spacing: 4) {
                    Text("KiwiBar").font(.title2).fontWeight(.semibold)
                    Text("Your Bandwagon host, at a glance.").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("HOST CONNECTION").font(.caption2).fontWeight(.semibold).tracking(1).foregroundStyle(.secondary)
                    Spacer()
                    Label("Read only", systemImage: "eye").font(.caption2).foregroundStyle(.secondary)
                }
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "number").foregroundStyle(.secondary).frame(width: 18).padding(.top, 2)
                        VStack(alignment: .leading, spacing: 7) {
                            Text("VEID").font(.caption).fontWeight(.medium).foregroundStyle(.secondary)
                            TextField("Your server ID", text: $veid)
                                .font(.body.monospacedDigit()).focused($focus, equals: .veid)
                                .onSubmit { focus = .apiKey }.accessibilityIdentifier("veid").accessibilityLabel("VEID")
                        }
                    }.padding(ConnectionLayout.fieldInset)
                    Divider().padding(.leading, ConnectionLayout.fieldInset)
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "key.horizontal").foregroundStyle(.secondary).frame(width: 18).padding(.top, 2)
                        VStack(alignment: .leading, spacing: 7) {
                            Text("API KEY").font(.caption).fontWeight(.medium).foregroundStyle(.secondary)
                            SecureField("Paste your API key", text: $apiKey)
                                .focused($focus, equals: .apiKey)
                                .onSubmit { if valid && !working && !loading { Task { await save() } } }
                                .accessibilityIdentifier("api-key").accessibilityLabel("API key")
                        }
                    }.padding(ConnectionLayout.fieldInset)
                }
                .textFieldStyle(.plain).disabled(loading || working)
                .frame(maxWidth: .infinity)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: ConnectionLayout.corner))
                .overlay { RoundedRectangle(cornerRadius: ConnectionLayout.corner).strokeBorder(.primary.opacity(0.08)) }
                if !veid.isEmpty && !veid.trimmingCharacters(in: .whitespacesAndNewlines).allSatisfy({ $0.isASCII && $0.isNumber }) {
                    Text("VEID contains numbers only.").font(.caption).foregroundStyle(.orange)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Launch at Login", isOn: Binding(
                    get: { loginStatus == .enabled || loginStatus == .requiresApproval },
                    set: { enabled in Task { await setLaunchAtLogin(enabled) } }
                ))
                .toggleStyle(.switch)
                .disabled(changingLogin)
                .accessibilityIdentifier("launch-at-login")
                if loginStatus == .requiresApproval {
                    Button("Open Login Items Settings") { SMAppService.openSystemSettingsLoginItems() }
                }
                if let loginError {
                    Label(loginError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
            VStack(spacing: 12) {
                Button { Task { await save() } } label: {
                    HStack(spacing: 8) {
                        if working || loading { ProgressView().controlSize(.small) }
                        Text(saving ? "Saving…" : (connecting ? "Connecting…" : "Save & Connect"))
                        if !working && !loading { Image(systemName: "arrow.right") }
                    }.frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .keyboardShortcut(.defaultAction).disabled(loading || working || !valid)
                .accessibilityIdentifier("save-connect")
                Label("Stored securely in macOS Keychain", systemImage: "lock.shield")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(ConnectionLayout.inset).frame(width: ConnectionLayout.width)
        .background(Color(nsColor: .windowBackgroundColor)).tint(.teal)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { loginStatus = SMAppService.mainApp.status }
        }
        .task {
            loginStatus = SMAppService.mainApp.status
            do {
                if let saved = try await monitor.savedCredentials() { veid = saved.veid; apiKey = saved.apiKey }
            } catch { self.error = error.localizedDescription }
            loading = false
            if veid.isEmpty { focus = .veid }
        }
    }
    private func setLaunchAtLogin(_ enabled: Bool) async {
        changingLogin = true
        loginError = nil
        defer { changingLogin = false; loginStatus = SMAppService.mainApp.status }
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try await SMAppService.mainApp.unregister() }
        } catch {
            loginError = "Could not change Launch at Login: \(error.localizedDescription)"
        }
    }
    private func save() async {
        saving = true; error = nil
        do {
            try await monitor.saveCredentials(veid: veid, apiKey: apiKey)
            saving = false; connecting = true
            await monitor.refresh()
            connecting = false
            if monitor.snapshot != nil { dismiss() }
            else { self.error = monitor.error ?? "Credentials saved. The host could not be reached; try connecting again." }
        } catch { self.error = error.localizedDescription; saving = false; connecting = false }
    }
}
