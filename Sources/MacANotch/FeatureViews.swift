import AVFoundation
import SwiftUI


struct CalendarView: View {
    @ObservedObject var calendar: CalendarModel

    var body: some View {
        switch calendar.access {
        case .unknown:
            placeholder(icon: "calendar", title: "See your next meetings here",
                        button: "Allow Calendar Access", action: calendar.requestAccess)
        case .denied:
            placeholder(icon: "calendar.badge.exclamationmark", title: "Calendar access is turned off",
                        button: "Open Privacy Settings", action: calendar.openPrivacySettings)
        case .granted:
            if calendar.events.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle").font(.system(size: 22))
                    Text("Nothing coming up").font(.system(size: 12))
                }
                .foregroundStyle(.white.opacity(0.5)).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 5) { ForEach(calendar.events) { EventRow(event: $0) } }
                }
            }
        }
    }

    private func placeholder(icon: String, title: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 22))
            Text(title).font(.system(size: 12))
            Button(button, action: action).buttonStyle(.plain).font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 12).padding(.vertical, 5).background(.white.opacity(0.18), in: Capsule())
        }
        .foregroundStyle(.white.opacity(0.7)).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct EventRow: View {
    let event: CalendarEvent

    private var timeText: String {
        if event.isAllDay { return "All day" }
        let f = DateFormatter()
        f.timeStyle = .short
        return "\(f.string(from: event.start)) – \(f.string(from: event.end))"
    }

    private var relative: String? {
        let minutes = Int(event.start.timeIntervalSinceNow / 60)
        if event.isAllDay { return nil }
        if minutes <= 0 { return "now" }
        if minutes < 60 { return "in \(minutes) min" }
        return nil
    }

    var body: some View {
        HStack(spacing: 8) {
            Capsule().fill(Color(nsColor: event.color)).frame(width: 3, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                Text(timeText).font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            if let relative { Text(relative).font(.system(size: 10)).foregroundStyle(.orange) }
            if let url = event.joinURL {
                Button { NSWorkspace.shared.open(url) } label: {
                    Label("Join", systemImage: "video.fill").font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 9).padding(.vertical, 4).background(Color.green.opacity(0.85), in: Capsule())
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }
}


struct ClaudeView: View {
    @ObservedObject var agents: AgentMonitor
    @State private var copied = false

    var body: some View {
        if agents.sessions.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "sparkles").font(.system(size: 22))
                Text("No Claude Code sessions yet").font(.system(size: 12))
                Text("Add the hooks to ~/.claude/settings.json, then start a session.")
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
                copyButton
            }
            .foregroundStyle(.white.opacity(0.7)).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 5) {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 5) { ForEach(agents.sessions) { SessionRow(session: $0) } }
                }
                HStack { Spacer(); copyButton }
            }
        }
    }

    private var copyButton: some View {
        Button {
            agents.copyHookConfig()
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
        } label: {
            Text(copied ? "Copied hook config" : "Copy hook config").font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 10).padding(.vertical, 3).background(.white.opacity(0.14), in: Capsule())
        }.buttonStyle(.plain)
    }
}

private struct SessionRow: View {
    let session: AgentSession

    private var label: String {
        switch session.state {
        case .working: "Working"
        case .attention: session.message.isEmpty ? "Needs your input" : session.message
        case .done: "Finished"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Group {
                switch session.state {
                case .working: ProgressView().controlSize(.small).scaleEffect(0.7)
                case .attention: Image(systemName: "exclamationmark.bubble.fill").foregroundStyle(.orange)
                case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
            .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(session.project).font(.system(size: 12, weight: .medium)).lineLimit(1)
                Text(label).font(.system(size: 10)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
            }
            Spacer()
            Text(session.updated, style: .relative).font(.system(size: 10)).foregroundStyle(.white.opacity(0.35))
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }
}


struct SystemView: View {
    @ObservedObject var system: SystemMonitor

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 18) {
                Gauge(title: "CPU", value: system.cpu, detail: "\(Int(system.cpu * 100))%", tint: .blue)
                Gauge(title: "GPU", value: system.gpu ?? 0, detail: system.gpu.map { "\(Int($0 * 100))%" } ?? "n/a", tint: .purple)
                Gauge(title: "Memory", value: system.memory,
                      detail: String(format: "%.1f/%.0f GB", system.memoryUsedGB, system.memoryTotalGB), tint: .orange)
                Gauge(title: "Disk", value: system.disk, detail: String(format: "%.0f GB free", system.diskFreeGB), tint: .green)
            }
            HStack(spacing: 22) {
                Label(Self.rate(system.netDown), systemImage: "arrow.down")
                Label(Self.rate(system.netUp), systemImage: "arrow.up")
            }
            .font(.system(size: 11, weight: .medium).monospacedDigit()).foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { system.start() }
        .onDisappear { system.stop() }
    }

    static func rate(_ bytesPerSecond: Double) -> String {
        switch bytesPerSecond {
        case ..<1_000: return String(format: "%.0f B/s", bytesPerSecond)
        case ..<1_000_000: return String(format: "%.0f KB/s", bytesPerSecond / 1_000)
        default: return String(format: "%.1f MB/s", bytesPerSecond / 1_000_000)
        }
    }
}

private struct Gauge: View {
    let title: String
    let value: Double
    let detail: String
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().stroke(.white.opacity(0.12), lineWidth: 6)
                Circle().trim(from: 0, to: min(max(value, 0), 1))
                    .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
                Text(title).font(.system(size: 10, weight: .semibold))
            }
            .frame(width: 54, height: 54)
            Text(detail).font(.system(size: 9).monospacedDigit()).foregroundStyle(.white.opacity(0.6))
        }
        .animation(.easeOut(duration: 0.4), value: value)
    }
}


struct ShortcutsView: View {
    @ObservedObject var shortcuts: ShortcutsModel

    var body: some View {
        Group {
            if shortcuts.loaded && shortcuts.names.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "bolt.slash").font(.system(size: 22))
                    Text("No Shortcuts found").font(.system(size: 12))
                    Text("Create one in the Shortcuts app").font(.system(size: 10))
                }
                .foregroundStyle(.white.opacity(0.5)).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 4) {
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 6)], spacing: 6) {
                            ForEach(shortcuts.names, id: \.self) { name in
                                Button { shortcuts.run(name) } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "bolt.fill").font(.system(size: 9)).foregroundStyle(.yellow)
                                        Text(name).font(.system(size: 11)).lineLimit(1)
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.horizontal, 8).padding(.vertical, 6)
                                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    if let status = shortcuts.status {
                        Text(status).font(.system(size: 10)).foregroundStyle(.green)
                    }
                }
            }
        }
        .onAppear { shortcuts.load() }
    }
}


final class CameraController: ObservableObject {
    enum Status { case idle, running, denied, unavailable }

    @Published var status: Status = .idle
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "camera")
    private var configured = false

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: run()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { granted ? self.run() : { self.status = .denied }() }
            }
        default: status = .denied
        }
    }

    private func run() {
        queue.async {
            if !self.configured {
                guard let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device),
                      self.session.canAddInput(input) else {
                    DispatchQueue.main.async { self.status = .unavailable }
                    return
                }
                self.session.addInput(input)
                self.configured = true
            }
            if !self.session.isRunning { self.session.startRunning() }
            DispatchQueue.main.async { self.status = .running }
        }
    }
    func stop() {
        queue.async { if self.session.isRunning { self.session.stopRunning() } }
        status = .idle
    }
}

struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1))
        view.layer = layer
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct MirrorView: View {
    @StateObject private var camera = CameraController()

    var body: some View {
        Group {
            switch camera.status {
            case .denied:
                message("camera.fill", "Camera access is turned off", "Enable it in System Settings → Privacy → Camera")
            case .unavailable:
                message("video.slash", "No camera found", nil)
            default:
                CameraPreview(session: camera.session)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.15)))
                    .frame(maxWidth: 220)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
    }

    private func message(_ icon: String, _ title: String, _ detail: String?) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 22))
            Text(title).font(.system(size: 12))
            if let detail { Text(detail).font(.system(size: 10)) }
        }
        .foregroundStyle(.white.opacity(0.5))
    }
}
