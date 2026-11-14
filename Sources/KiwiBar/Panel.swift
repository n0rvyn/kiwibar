import SwiftUI
import BandwagonCore

func bytes(_ value: Double?) -> String {
    guard let value, value >= 0, value.isFinite, value < Double(Int64.max) else { return "—" }
    return ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .binary)
}
struct Panel: View {
    @Bindable var monitor: Monitor
    @State private var contentHeight: CGFloat = 180
    private var availableContentHeight: CGFloat { max(180, (NSScreen.main?.visibleFrame.height ?? 800) - 160) }
    private var panelWidth: CGFloat { min(440, (NSScreen.main?.visibleFrame.width ?? 800) - 32) }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "server.rack").font(.title2).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 3) {
                    Text(monitor.snapshot?.text("hostname") ?? "KiwiBar").font(.headline).textSelection(.enabled)
                    Text(monitor.snapshot?.text("node_location") ?? "Bandwagon Host").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                let state = monitor.snapshot?.state ?? (!monitor.configured && !monitor.initializing ? "Not connected" : (monitor.error == nil ? "Connecting" : "Unavailable"))
                Label(state, systemImage: state == "Running" ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .font(.caption).foregroundStyle(state == "Running" ? Color.green : Color.secondary)
            }.padding(16)
            Divider()
            ScrollView {
                content.padding(16)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: min(contentHeight, availableContentHeight))
            Divider()
            HStack {
                if let date = monitor.updated {
                    Text("\(monitor.error == nil ? "Updated" : "Stale") \(date.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                } else { Text("No metrics loaded").font(.caption).foregroundStyle(.secondary) }
                Spacer()
                if monitor.loading { ProgressView().controlSize(.small) }
                SettingsLink { Image(systemName: "gearshape") }
                    .help("Settings").accessibilityLabel("Settings")
                Button { Task { await monitor.refresh() } } label: { Image(systemName: "arrow.clockwise") }.help("Refresh now · auto refresh every 5 minutes").disabled(monitor.loading || !monitor.configured).accessibilityLabel("Refresh now")
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }.padding(12).help("Auto refresh every 5 minutes. API points: \(monitor.limits?["remaining_points_15min"]?.number.map { String(format: "%.0f", $0) } ?? "—") / 15 min; \(monitor.limits?["remaining_points_24h"]?.number.map { String(format: "%.0f", $0) } ?? "—") / 24 h")
        }.frame(width: panelWidth).background(.background)
    }
    // Shared content allows offscreen vector rendering without AppKit-backed ScrollView.
    var content: some View {
        let samples = UsageSample.recentWeek(monitor.samples)
        return VStack(alignment: .leading, spacing: 18) {
            if let error = monitor.error {
                Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.callout)
                if monitor.snapshot == nil { Text("Check your connection, or update your credentials in Settings.").font(.caption).foregroundStyle(.secondary) }
            }
            if let s = monitor.snapshot {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Label("Transfer", systemImage: "arrow.up.arrow.down").font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        if let f = s.transferFraction { Text(f, format: .percent.precision(.fractionLength(0))).font(.title2).fontWeight(.semibold) }
                    }
                    ProgressView(value: min(max(s.transferFraction ?? 0, 0), 1)).tint((s.transferFraction ?? 0) >= 0.9 ? .orange : .accentColor)
                    HStack {
                        Text("\(bytes(s.transferUsed)) / \(bytes(s.transferTotal))")
                        Spacer()
                        if let reset = s.number("data_next_reset") { Text("↻ \(Date(timeIntervalSince1970: reset).formatted(.dateTime.month(.abbreviated).day()))") }
                    }.font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 0) {
                    ResourceGauge(name: "RAM", used: s.memoryUsed, total: s.number("plan_ram"), color: .blue)
                    ResourceGauge(name: "Swap", used: s.swapUsed, total: s.number("swap_total_kb").map { $0 * 1024 }, color: .purple)
                    ResourceGauge(name: "Mapped disk", used: s.number("ve_used_disk_space_b"), total: s.number("plan_disk"), color: .teal)
                        .help("Allocated disk image space, not filesystem usage")
                }
                HStack {
                    Label("Load", systemImage: "cpu").foregroundStyle(.secondary)
                    Text((s.text("load_average") ?? "—").split(separator: " ").prefix(3).joined(separator: "  ")).monospacedDigit()
                    Spacer()
                    throttle("CPU", s.number("is_cpu_throttled"))
                    throttle("Disk", s.number("is_disk_throttled"))
                }.font(.caption)
                VStack(alignment: .leading, spacing: 14) {
                    if let e = monitor.historyError { Label(e, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange) }
                    if samples.isEmpty {
                        HStack { Image(systemName: "chart.xyaxis.line"); Text(monitor.loading ? "Loading history…" : "History unavailable") }.font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 24)
                    } else {
                        SparkChart(title: "CPU", samples: samples, series: [ChartSeries(name: "Usage", color: .orange, value: \.cpu)], byteValues: false)
                            .help("cpu_usage as reported by Bandwagon; provider units, not CPU percent")
                        SparkChart(title: "Network", samples: samples, series: [ChartSeries(name: "↓ In", color: .blue, value: \.networkIn), ChartSeries(name: "↑ Out", color: .purple, value: \.networkOut)], byteValues: true)
                        SparkChart(title: "Disk I/O", samples: samples, series: [ChartSeries(name: "Read", color: .teal, value: \.diskRead), ChartSeries(name: "Write", color: .orange, value: \.diskWrite)], byteValues: true)
                        if let start = samples.first?.date, let end = samples.last?.date {
                            HStack { Text(start.formatted(date: .abbreviated, time: .omitted)); Spacer(); Text(end.formatted(date: .abbreviated, time: .omitted)) }.font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 5) {
                    Text(s.addresses.joined(separator: " · ")).textSelection(.enabled)
                    Text([s.text("plan"), s.text("os")].compactMap { $0 }.joined(separator: " · ")).foregroundStyle(.secondary)
                }.font(.caption)
            } else if !monitor.configured && !monitor.initializing {
                VStack(spacing: 12) {
                    Image(systemName: "server.rack").font(.largeTitle).foregroundStyle(.secondary)
                    Text("Connect your host").font(.headline)
                    SettingsLink { Text("Open Settings") }.buttonStyle(.borderedProminent)
                }.frame(maxWidth: .infinity).padding(.vertical, 40)
            } else if monitor.loading || monitor.initializing { HStack { Spacer(); ProgressView("Loading metrics…"); Spacer() }.padding(.vertical, 40) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    func throttle(_ name: String, _ value: Double?) -> some View {
        Image(systemName: value == nil ? "questionmark.circle" : (value == 0 ? "checkmark.shield" : "exclamationmark.triangle.fill"))
            .foregroundStyle(value == nil ? Color.secondary : (value == 0 ? .green : .orange))
            .help("\(name) throttling: \(value == nil ? "unavailable" : (value == 0 ? "no" : "active"))")
            .accessibilityLabel("\(name) throttling: \(value == nil ? "unavailable" : (value == 0 ? "no" : "active"))")
    }
}
struct ResourceGauge: View {
    let name: String
    let used: Double?
    let total: Double?
    let color: Color
    var ratio: Double? { guard let used, let total, total > 0 else { return nil }; return used / total }
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(color.opacity(0.14), lineWidth: 5)
                if let ratio { Circle().trim(from: 0, to: min(max(ratio, 0), 1)).stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90)) }
                Text(ratio.map { String(format: "%.0f%%", $0 * 100) } ?? "—").font(.system(.callout, design: .rounded)).fontWeight(.semibold)
            }.frame(width: 58, height: 58)
            Text(name).font(.caption).fontWeight(.medium)
            Text("\(bytes(used)) / \(bytes(total))").font(.caption2).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).accessibilityElement(children: .combine)
    }
}
struct ChartSeries {
    let name: String
    let color: Color
    let value: KeyPath<UsageSample, Double?>
}
struct SparkChart: View {
    let title: String
    let samples: [UsageSample]
    let series: [ChartSeries]
    let byteValues: Bool
    var maximum: Double { max(series.flatMap { item in samples.compactMap { $0[keyPath: item.value] } }.max() ?? 1, 1) }
    func format(_ v: Double?) -> String { byteValues ? bytes(v) : (v.map { String(format: "%.1f", $0) } ?? "—") }
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title).font(.caption).fontWeight(.medium)
                Spacer()
                ForEach(series.indices, id: \.self) { i in
                    HStack(spacing: 3) {
                        Circle().fill(series[i].color).frame(width: 5, height: 5)
                        Text("\(series[i].name) \(format(samples.last?[keyPath: series[i].value]))")
                    }.font(.caption2).foregroundStyle(.secondary)
                }
            }
            let maxValue = maximum
            Canvas { context, size in
                for fraction in [0.0, 0.5, 1.0] {
                    var line = Path(); let y = size.height * fraction
                    line.move(to: CGPoint(x: 0, y: y)); line.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(line, with: .color(.secondary.opacity(0.12)), lineWidth: 0.5)
                }
                guard let first = samples.first?.date.timeIntervalSince1970, let last = samples.last?.date.timeIntervalSince1970 else { return }
                let duration = max(last - first, 1)
                for item in series {
                    var line = Path(); var connected = false
                    for sample in samples {
                        guard let v = sample[keyPath: item.value] else { connected = false; continue }
                        let p = CGPoint(x: (sample.date.timeIntervalSince1970 - first) / duration * size.width, y: size.height - v / maxValue * (size.height - 3))
                        if connected { line.addLine(to: p) } else { line.move(to: p); connected = true }
                    }
                    context.stroke(line, with: .color(item.color), lineWidth: 1)
                }
            }.frame(height: 64).overlay(alignment: .topLeading) { Text(format(maxValue)).font(.system(size: 9)).foregroundStyle(.tertiary).padding(.top, 2) }
            .accessibilityLabel("\(title) history, \(samples.count) samples, peak \(format(maxValue))")
        }.help(byteValues ? "Bytes per sample, as reported by Bandwagon" : "Usage as reported by Bandwagon")
    }
}
