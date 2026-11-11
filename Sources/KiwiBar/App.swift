import AppKit
import SwiftUI
import BandwagonCore

func defaultEnvPath() -> String {
    let local = FileManager.default.currentDirectoryPath + "/.env"
    if FileManager.default.fileExists(atPath: local) { return local }
    return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/kiwibar/.env").path
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var monitor: Monitor!
    var timer: Timer?
    var task: Task<Void, Never>?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        let envPath: String
        if let index = args.firstIndex(of: "--env"), args.indices.contains(index + 1) { envPath = args[index + 1] }
        else if let configured = Bundle.main.object(forInfoDictionaryKey: "BandwagonEnvPath") as? String { envPath = configured }
        else { envPath = defaultEnvPath() }
        monitor = Monitor(envURL: URL(fileURLWithPath: envPath))
        NSApp.setActivationPolicy(.accessory)
        popover = NSPopover(); popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: Panel(monitor: monitor))
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self; statusItem.button?.action = #selector(togglePanel)
        monitor.onChange = { [weak self] in self?.updateStatus() }
        updateStatus()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in Task { @MainActor in await self?.monitor.refresh() } }
        task = Task { await monitor.refresh() }
        #if DEBUG
        let verificationShow = Bundle.main.object(forInfoDictionaryKey: "KiwiVerificationShowOnLaunch") as? Bool ?? false
        #else
        let verificationShow = false
        #endif
        if args.contains("--show") || verificationShow { togglePanel() }
    }
    func updateStatus() {
        statusItem.button?.title = monitor.title
        let running = monitor.snapshot?.state == "Running"
        let symbol = monitor.error != nil ? "exclamationmark.triangle.fill" : "server.rack"
        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: monitor.snapshot?.state ?? "Connecting") {
            let color: NSColor = monitor.error != nil ? .systemOrange : (running ? .systemGreen : (monitor.snapshot == nil ? .secondaryLabelColor : .systemRed))
            let config = NSImage.SymbolConfiguration(paletteColors: [color])
            statusItem.button?.image = image.withSymbolConfiguration(config)
        }
        statusItem.button?.toolTip = monitor.error ?? "Bandwagon Host · \(monitor.snapshot?.state ?? "Connecting")"
    }
    @objc func togglePanel() {
        guard let button = statusItem.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else { popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY); NSApp.activate(ignoringOtherApps: true) }
    }
    func applicationWillTerminate(_ notification: Notification) { timer?.invalidate(); task?.cancel() }
}
@main struct Main {
    @MainActor static func main() async {
        let args = CommandLine.arguments
        if args.contains("--help") || args.contains("-h") {
            print("KiwiBar 1.0.0 — Bandwagon Host menu bar monitor")
            print("Usage: KiwiBar [--env PATH] [--probe | --render PATH --sample [--dark]]")
            print("Default credentials: .env in the current directory, then ~/.config/kiwibar/.env")
            return
        }
        if args.contains("--version") { print("1.0.0"); return }
        if args.contains("--probe") || args.contains("--render") {
            let envIndex = args.firstIndex(of: "--env")
            let envPath = envIndex.flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil } ?? defaultEnvPath()
            let monitor = Monitor(envURL: URL(fileURLWithPath: envPath))
        if args.contains("--probe") {
                await monitor.refresh()
                if let s = monitor.snapshot {
                    print("Live API succeeded. State: \(s.state). Transfer percentage: \(s.transferFraction.map { String(format: "%.1f", $0 * 100) } ?? "unavailable").")
                    print("Live fields: \(s.fields.keys.filter { $0 != "screendump_png_base64" }.sorted().joined(separator: ", "))")
                    if let h = monitor.history {
                        print("History fields: \(h.keys.sorted().joined(separator: ", "))")
                        for key in h.keys.sorted() {
                            if let rows = h[key]?.array { print("\(key): \(rows.count) rows; first record: \(rows.first.map { String(describing: $0) } ?? "none")") }
                        }
                    }
                    print(monitor.historyError ?? "History API succeeded.")
                } else { print(monitor.error ?? "No metrics returned."); exit(1) }
            return
        }
        if let index = args.firstIndex(of: "--render"), args.indices.contains(index + 1) {
                if args.contains("--sample") {
                    let sample = "{\"error\":0,\"hostname\":\"sample.host\",\"ve_status\":\"Running\",\"data_counter\":107374182400,\"plan_monthly_data\":1073741824000,\"data_next_reset\":1796000000,\"plan_ram\":2147483648,\"mem_available_kb\":1048576,\"load_average\":\"0.10 0.12 0.08\",\"plan_disk\":21474836480,\"ve_used_disk_space_b\":5368709120,\"swap_total_kb\":1048576,\"swap_available_kb\":1048576,\"is_cpu_throttled\":0,\"is_disk_throttled\":0,\"node_location\":\"US, Los Angeles\",\"plan\":\"Sample\",\"os\":\"Ubuntu\"}"
                    monitor.snapshot = Snapshot(try! APIClient.decode(Data(sample.utf8))); monitor.updated = Date()
                } else { await monitor.refresh() }
                if args.contains("--sample") {
                    let now = Date().timeIntervalSince1970
                    let records: [JSONValue] = (0..<288).map { index in
                        let wave = abs(sin(Double(index) / 13))
                        return .object(["timestamp": .number(now - Double(287 - index) * 300), "cpu_usage": .number(12 + wave * 30), "network_in_bytes": .number(1_000_000 + wave * 40_000_000), "network_out_bytes": .number(500_000 + abs(cos(Double(index) / 19)) * 25_000_000), "disk_read_bytes": .number(wave * 1_000_000), "disk_write_bytes": .number(abs(sin(Double(index) / 7)) * 3_000_000)])
                    }
                    monitor.samples = UsageSample.parse(["data": .array(records)])
                }
                let renderer = ImageRenderer(content: Panel(monitor: monitor).content.padding(16).frame(width: 440).background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, args.contains("--dark") ? .dark : .light))
                renderer.scale = 2
                if let image = renderer.nsImage, let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) {
                    do { try png.write(to: URL(fileURLWithPath: args[index + 1])); print("Rendered panel") } catch { print("Render write failed") }
                } else { print("Render failed") }
            return
        }

        }
        runApplication()
    }
    @MainActor static func runApplication() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
        withExtendedLifetime(delegate) {}
    }
}
