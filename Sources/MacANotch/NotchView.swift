import SwiftUI
import UniformTypeIdentifiers

struct NotchView: View {
    @ObservedObject var state: NotchState
    @ObservedObject var shelf: ShelfStore
    @ObservedObject var clipboard: ClipboardManager
    @ObservedObject var media: MediaController
    @ObservedObject var pomodoro: PomodoroModel
    @ObservedObject var calendar: CalendarModel
    @ObservedObject var agents: AgentMonitor
    @ObservedObject var system: SystemMonitor
    @ObservedObject var shortcuts: ShortcutsModel
    @ObservedObject var highAlert: HighAlertModel

    @AppStorage(Pref.shelf) private var shelfOn = true
    @AppStorage(Pref.clipboard) private var clipboardOn = true
    @AppStorage(Pref.media) private var mediaOn = true

    private var tabs: [NotchTab] {
        NotchTab.allCases.filter { UserDefaults.standard.bool(forKey: $0.prefKey) }
    }

    private var hudSize: CGSize? {
        guard !state.expanded, let hud = state.hud else { return nil }
        return HUDLayout.size(for: hud, notch: state.notchSize)
    }
    @AppStorage(Pref.liveActivity) private var liveOn = true

    private var liveSize: CGSize? {
        if !state.expanded, state.hud == nil, pomodoro.started {
            return CGSize(width: state.notchSize.width + HUDLayout.sideWidth * 2, height: state.notchSize.height)
        }
        guard !state.expanded, state.hud == nil, liveOn, Pref.bool(Pref.media), media.hasTrack, media.isPlaying else { return nil }
        return LiveActivityLayout.size(notch: state.notchSize)
    }
    private var collapsedSize: CGSize { hudSize ?? liveSize ?? state.notchSize }
    private var width: CGFloat { state.expanded ? NotchState.expandedSize.width : collapsedSize.width }
    private var height: CGFloat { state.expanded ? NotchState.expandedSize.height : collapsedSize.height }

    var body: some View {
        ZStack(alignment: .top) {
            NotchShape(topRadius: state.expanded ? 18 : 6, bottomRadius: state.expanded ? 26 : hudSize == nil ? 12 : 18)
                .fill(.black)
                .frame(width: width, height: height)
                .shadow(color: .black.opacity(state.expanded ? 0.45 : 0), radius: 14, y: 6)
                .overlay(alignment: .bottom) {
                    // Small dot hints that the shelf holds files while collapsed.
                    if !state.expanded && !shelf.items.isEmpty && liveSize == nil {
                        Circle().fill(.blue).frame(width: 5, height: 5).offset(y: -3)
                    }
                }

            if let size = liveSize {
                Group {
                    if pomodoro.started { PomodoroPillView(pomodoro: pomodoro, notch: state.notchSize) }
                    else { LiveActivityView(media: media, notch: state.notchSize) }
                }
                .frame(width: size.width, height: size.height)
                    .transition(.notchContent)
            }

            if let hud = state.hud, let size = hudSize {
                HUDView(hud: hud, notch: state.notchSize)
                    .frame(width: size.width, height: size.height)
                    .transition(.notchContent)
            }

            if state.expanded {
                content
                    .frame(width: width, height: height)
                    .clipShape(NotchShape(topRadius: 18, bottomRadius: 26))
                    .transition(.notchContent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: state.expanded)
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: state.hud?.id)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: liveSize != nil)
        .onDrop(of: [UTType.fileURL], isTargeted: $state.dropTargeted) { providers in
            state.tab = .shelf
            return shelf.handleDrop(providers)
        }
    }

    private var content: some View {
        VStack(spacing: 8) {
            Spacer().frame(height: max(state.notchSize.height - 4, 12))
            tabBar
            Group {
                switch state.tab {
                case .shelf: ShelfView(shelf: shelf, targeted: state.dropTargeted)
                case .clipboard: ClipboardView(clipboard: clipboard)
                case .media: MediaView(media: media)
                case .calendar: CalendarView(calendar: calendar)
                case .timer: TimerView(pomodoro: pomodoro)
                case .claude: ClaudeView(agents: agents)
                case .shortcuts: ShortcutsView(shortcuts: shortcuts)
                case .system: SystemView(system: system)
                case .mirror: MirrorView()
                case .tools: ToolsView(highAlert: highAlert)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 36)
        .padding(.bottom, 20)
        .foregroundStyle(.white)
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(tabs) { tab in
                Button { state.tab = tab } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                        if state.tab == tab { Text(tab.title) }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(state.tab == tab ? Color.white.opacity(0.18) : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(state.tab == tab ? .white : .white.opacity(0.55))
            }
            Spacer()
            Button { NSApp.sendAction(#selector(AppDelegate.openSettings), to: nil, from: nil) } label: {
                Image(systemName: "gearshape").font(.system(size: 11))
            }
            .buttonStyle(.plain).foregroundStyle(.white.opacity(0.55))
        }
    }
}

struct ShelfView: View {
    @ObservedObject var shelf: ShelfStore
    let targeted: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(targeted ? Color.blue : .white.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                .background(targeted ? Color.blue.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 14))

            if shelf.items.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.down.doc").font(.system(size: 22))
                    Text("Drop files here").font(.system(size: 12))
                }
                .foregroundStyle(.white.opacity(0.5))
            } else {
                HStack(spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(shelf.items) { item in ShelfItemView(item: item, shelf: shelf) }
                        }
                        .padding(10)
                    }
                    VStack(spacing: 8) {
                        if let message = shelf.message {
                            Text(message).font(.system(size: 10)).foregroundStyle(.green)
                        }
                        if shelf.items.count > 1 {
                            Button("Zip all") { shelf.zip(shelf.items) }
                                .buttonStyle(.plain).font(.system(size: 11, weight: .medium))
                        }
                        Button("Clear") { shelf.clear() }
                            .buttonStyle(.plain).font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(width: 70).padding(.trailing, 6)
                }
            }
        }
    }
}

struct ShelfItemView: View {
    let item: ShelfItem
    @ObservedObject var shelf: ShelfStore
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 3) {
            Image(nsImage: item.icon).resizable().frame(width: 44, height: 44)
            Text(item.name).font(.system(size: 10)).lineLimit(1).frame(width: 64)
        }
        .padding(6)
        .background(hovering ? Color.white.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button { shelf.remove(item) } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.white, .gray)
                }.buttonStyle(.plain)
            }
        }
        .onHover { hovering = $0 }
        .onDrag { NSItemProvider(object: item.url as NSURL) }
        .onTapGesture(count: 2) { NSWorkspace.shared.open(item.url) }
        .contextMenu {
            Button("Open") { NSWorkspace.shared.open(item.url) }
            Button("Reveal in Finder") { shelf.reveal(item) }
            Button("Copy") { shelf.copy(item) }
            Button("AirDrop…") { shelf.airDrop(item) }
            Divider()
            Button("Zip") { shelf.zip([item]) }
            if shelf.isImage(item) {
                Button("Convert to PNG") { shelf.convert(item, to: .png) }
                Button("Convert to JPEG") { shelf.convert(item, to: .jpeg) }
            }
            Divider()
            Button("Remove") { shelf.remove(item) }
        }
    }
}

struct ClipboardView: View {
    @ObservedObject var clipboard: ClipboardManager
    @State private var query = ""
    @State private var status: String?

    private var filtered: [ClipItem] {
        let sorted = clipboard.items.sorted { $0.favorite && !$1.favorite }
        guard !query.isEmpty else { return sorted }
        return sorted.filter { $0.text?.localizedCaseInsensitiveContains(query) ?? false }
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.5))
                TextField("Search clipboard history", text: $query).textFieldStyle(.plain).font(.system(size: 12))
                if let status { Text(status).font(.system(size: 10)).foregroundStyle(.green) }
                Button("Clear") { clipboard.clearUnfavorited() }
                    .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

            if filtered.isEmpty {
                Spacer()
                Text("Nothing copied yet").font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 4) { ForEach(filtered) { row($0) } }
                }
            }
        }
    }

    private func flash(_ message: String) {
        status = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { status = nil }
    }

    private func row(_ item: ClipItem) -> some View {
        HStack(spacing: 8) {
            if let text = item.text {
                Text(text).font(.system(size: 11)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
            } else if let img = clipboard.image(for: item) {
                Image(nsImage: img).resizable().scaledToFit().frame(height: 30)
                Spacer()
                Button("OCR") { clipboard.ocr(item) { flash($0 ? "Text copied" : "No text found") } }
                    .buttonStyle(.plain).font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2).background(.white.opacity(0.15), in: Capsule())
            }
            Button { clipboard.toggleFavorite(item) } label: {
                Image(systemName: item.favorite ? "star.fill" : "star").foregroundStyle(item.favorite ? .yellow : .white.opacity(0.4))
            }.buttonStyle(.plain)
            Button { clipboard.delete(item) } label: {
                Image(systemName: "trash").foregroundStyle(.white.opacity(0.4))
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture { clipboard.copy(item); flash("Copied") }
    }
}

struct MediaView: View {
    @ObservedObject var media: MediaController

    var body: some View {
        if !media.hasTrack {
            VStack(spacing: 4) {
                Image(systemName: "music.note").font(.system(size: 22))
                Text("Nothing playing").font(.system(size: 12))
                Text("Play something in Music, Spotify or a browser tab").font(.system(size: 10))
            }
            .foregroundStyle(.white.opacity(0.5)).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack(spacing: 14) {
                Group {
                    if let art = media.artwork { Image(nsImage: art).resizable().scaledToFill() }
                    else { Image(systemName: "music.note").font(.system(size: 28)).foregroundStyle(.white.opacity(0.5)) }
                }
                .frame(width: 92, height: 92).background(.white.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .top) {
                        Text(media.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                        Spacer(minLength: 6)
                        EqualizerBars(active: media.isPlaying)
                    }
                    Text("\(media.artist) · \(media.sourceLabel)")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                    controls
                    SeekBar(media: media)
                }
            }
            .padding(.horizontal, 6)
        }
    }

    private var controls: some View {
        HStack(spacing: 0) {
            Button { media.toggleShuffle() } label: { Image(systemName: "shuffle") }
                .foregroundStyle(media.shuffleOn ? Color.green : .white.opacity(media.canShuffle ? 0.6 : 0.2))
                .disabled(!media.canShuffle)
            Spacer()
            Button { media.previous() } label: { Image(systemName: "backward.fill") }
            Spacer()
            Button { media.playPause() } label: { Image(systemName: media.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 20)) }
            Spacer()
            Button { media.next() } label: { Image(systemName: "forward.fill") }
            Spacer()
            Button { media.toggleRepeat() } label: { Image(systemName: "repeat") }
                .foregroundStyle(media.repeatOn ? Color.green : .white.opacity(0.6))
        }
        .font(.system(size: 13))
        .buttonStyle(.plain)
        .padding(.trailing, 6)
    }
}

/// Draggable progress bar with elapsed / total time.
struct SeekBar: View {
    @ObservedObject var media: MediaController
    @State private var dragFraction: Double?

    private func format(_ seconds: Double) -> String {
        let s = Int(max(0, seconds))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    var body: some View {
        let fraction = dragFraction ?? (media.duration > 0 ? min(media.position / media.duration, 1) : 0)
        HStack(spacing: 6) {
            Text(format(fraction * media.duration)).font(.system(size: 9).monospacedDigit()).foregroundStyle(.white.opacity(0.5))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.2))
                    Capsule().fill(.white).frame(width: geo.size.width * fraction)
                }
                .frame(height: dragFraction != nil ? 6 : 4)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { dragFraction = min(max($0.location.x / geo.size.width, 0), 1) }
                    .onEnded { value in
                        let f = min(max(value.location.x / geo.size.width, 0), 1)
                        media.seek(to: f * media.duration)
                        dragFraction = nil
                    })
            }
            .frame(height: 14)
            Text(format(media.duration)).font(.system(size: 9).monospacedDigit()).foregroundStyle(.white.opacity(0.5))
        }
        .opacity(media.duration > 0 ? 1 : 0.35)
        .allowsHitTesting(media.duration > 0)
    }
}
