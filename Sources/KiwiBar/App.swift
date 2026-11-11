import AppKit
import SwiftUI
import BandwagonCore

struct KiwiBarApplication: App {
    @NSApplicationDelegateAdaptor(AccessoryDelegate.self) private var delegate
    @State private var monitor = Monitor()
    var body: some Scene {
        MenuBarExtra {
            Panel(monitor: monitor)
        } label: {
            StatusLabel(monitor: monitor)
        }.menuBarExtraStyle(.window)
        Settings {
            SettingsView(monitor: monitor)
        }.windowResizability(.contentSize)
    }
}

@MainActor final class AccessoryDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) { NSApp.setActivationPolicy(.accessory) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

private struct StatusLabel: View {
    @Bindable var monitor: Monitor
    @Environment(\.openSettings) private var openSettings
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: monitor.error == nil ? "server.rack" : "exclamationmark.triangle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(monitor.error != nil ? Color.orange : (monitor.snapshot?.state == "Running" ? .green : .secondary))
            Text(monitor.title).monospacedDigit()
        }
        .fixedSize()
        .accessibilityLabel("KiwiBar \(monitor.title)")
        .task {
            let showSettings = CommandLine.arguments.contains("--settings")
            if showSettings {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
            await monitor.restore()
            if !monitor.configured && !showSettings {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
            if monitor.configured { await monitor.refresh() }
        }
        .task {
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(300)) }
                catch { return }
                await monitor.refresh()
            }
        }
    }
}

@MainActor enum Diagnostics {
    static func run(_ args: [String]) async throws {
        let monitor = Monitor()
        if args.contains("--probe") {
            await monitor.restore()
            guard monitor.configured else { print(monitor.error ?? "Open KiwiBar Settings to connect your host."); exit(1) }
            await monitor.refresh()
            guard let snapshot = monitor.snapshot else { print(monitor.error ?? "No metrics returned."); exit(1) }
            print("Live API succeeded. State: \(snapshot.state). Transfer: \(snapshot.transferFraction.map { String(format: "%.0f%%", $0 * 100) } ?? "unavailable"). History samples: \(monitor.samples.count).")
            return
        }
        if let index = args.firstIndex(of: "--render"), args.indices.contains(index + 1) {
            if args.contains("--sample") {
                    let sample = "{\"error\":0,\"hostname\":\"sample.host\",\"ve_status\":\"Running\",\"data_counter\":107374182400,\"plan_monthly_data\":1073741824000,\"data_next_reset\":1796000000,\"plan_ram\":2147483648,\"mem_available_kb\":1048576,\"load_average\":\"0.10 0.12 0.08\",\"plan_disk\":21474836480,\"ve_used_disk_space_b\":5368709120,\"swap_total_kb\":1048576,\"swap_available_kb\":1048576,\"is_cpu_throttled\":0,\"is_disk_throttled\":0,\"node_location\":\"US, Los Angeles\",\"plan\":\"Sample\",\"os\":\"Ubuntu\"}"
                    monitor.snapshot = Snapshot(try APIClient.decode(Data(sample.utf8))); monitor.updated = Date(); monitor.configured = true; monitor.initializing = false

                    let now = Date().timeIntervalSince1970
                    let records: [JSONValue] = (0..<288).map { index in
                        let wave = abs(sin(Double(index) / 13))
                        return .object(["timestamp": .number(now - Double(287 - index) * 300), "cpu_usage": .number(12 + wave * 30), "network_in_bytes": .number(1_000_000 + wave * 40_000_000), "network_out_bytes": .number(500_000 + abs(cos(Double(index) / 19)) * 25_000_000), "disk_read_bytes": .number(wave * 1_000_000), "disk_write_bytes": .number(abs(sin(Double(index) / 7)) * 3_000_000)])
                    }
                    monitor.samples = UsageSample.parse(["data": .array(records)])

            } else {
                await monitor.restore()
                await monitor.refresh()
            }
            let renderer = ImageRenderer(content: Panel(monitor: monitor).content.padding(16).frame(width: 440).background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, args.contains("--dark") ? .dark : .light))
            renderer.scale = 2
            guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) else { throw MonitorError.response }
            try png.write(to: URL(fileURLWithPath: args[index + 1]))
            print("Rendered chart content")
        }
    }
}
