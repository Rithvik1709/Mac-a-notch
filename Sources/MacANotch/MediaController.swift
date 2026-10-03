import AppKit

/// Now-playing state from Apple Music / Spotify (AppleScript) and browser tabs (YouTube etc.).
@MainActor
final class MediaController: ObservableObject {
    @Published var title = ""
    @Published var artist = ""
    @Published var isPlaying = false
    @Published var artwork: NSImage?
    @Published var hasTrack = false
    /// Where the track comes from, e.g. "Spotify" or "YouTube".
    @Published var sourceLabel = ""
    @Published var position: Double = 0
    @Published var duration: Double = 0
    @Published var shuffleOn = false
    @Published var repeatOn = false
    /// Shuffle is only available for Music and Spotify.
    @Published var canShuffle = false

    private var native: (app: String, parts: [String])?
    private var browserTrack: BrowserTrack?
    private var browserBusy = false
    private var artworkURL: String?
    private var timers: [Timer] = []

    private static let players = [("Spotify", "com.spotify.client"), ("Music", "com.apple.Music")]

    init() {
        timers.append(Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshNative() }
        })
        timers.append(Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshBrowser() }
        })
        // Cheap CoreAudio check so pause/play shows up quickly, independent of the slower tab scan.
        timers.append(Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshBrowserAudioState() }
        })
        // Smooth the progress bar between polls.
        timers.append(Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isPlaying, self.duration > 0 else { return }
                self.position = min(self.position + 0.5, self.duration)
            }
        })
    }

    // MARK: Polling

    private func refreshNative() {
        guard Pref.bool(Pref.media) else { return }
        let running = Self.players.filter { !NSRunningApplication.runningApplications(withBundleIdentifier: $0.1).isEmpty }
        DispatchQueue.global(qos: .utility).async {
            var best: (app: String, parts: [String])?
            for (name, _) in running {
                guard let parts = Self.query(name) else { continue }
                if best == nil || parts[0] == "playing" { best = (name, parts) }
                if parts[0] == "playing" { break }
            }
            DispatchQueue.main.async { self.native = best; self.recompute() }
        }
    }

    private func refreshBrowser() {
        guard Pref.bool(Pref.media), Pref.bool(Pref.browserMedia), !browserBusy else {
            if browserTrack != nil, !Pref.bool(Pref.browserMedia) { browserTrack = nil; recompute() }
            return
        }
        let names = BrowserMedia.runningBrowserNames()
        guard !names.isEmpty else {
            if browserTrack != nil { browserTrack = nil; recompute() }
            return
        }
        browserBusy = true
        DispatchQueue.global(qos: .utility).async {
            let track = BrowserMedia.scan(browserNames: names)
            DispatchQueue.main.async {
                self.browserBusy = false
                self.browserTrack = track
                self.recompute()
            }
        }
    }

    private func refreshBrowserAudioState() {
        guard Pref.bool(Pref.media), var track = browserTrack, !track.preciseState,
              let id = BrowserMedia.bundleID(forApp: track.app) else { return }
        let playing = BrowserMedia.isOutputtingAudio(bundlePrefix: id)
        guard playing != track.playing else { return }
        track.playing = playing
        browserTrack = track
        recompute()
    }

    // MARK: Combining sources

    /// Prefer whatever is actually playing (native player first), otherwise show the paused one.
    private func recompute() {
        let nativePlaying = native?.parts[0] == "playing"
        if let n = native, nativePlaying { applyNative(n) }
        else if let b = browserTrack, b.playing { applyBrowser(b) }
        else if let n = native { applyNative(n) }
        else if let b = browserTrack { applyBrowser(b) }
        else {
            title = ""; artist = ""; isPlaying = false; artwork = nil
            hasTrack = false; sourceLabel = ""; artworkURL = nil
            position = 0; duration = 0
        }
    }

    private static func number(_ parts: [String], _ i: Int) -> Double {
        guard parts.count > i else { return 0 }
        return Double(parts[i].replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func applyNative(_ n: (app: String, parts: [String])) {
        let p = n.parts
        hasTrack = true
        sourceLabel = n.app
        isPlaying = p[0] == "playing"
        setIfChanged(\.title, p[1])
        setIfChanged(\.artist, p[2])
        loadArtwork(p.count > 3 ? p[3] : "")
        position = Self.number(p, 4)
        // Spotify reports milliseconds, Music seconds.
        duration = n.app == "Spotify" ? Self.number(p, 5) / 1000 : Self.number(p, 5)
        canShuffle = true
        shuffleOn = p.count > 6 && p[6] == "true"
        repeatOn = p.count > 7 && p[7] != "false" && p[7] != "off"
    }

    private func applyBrowser(_ b: BrowserTrack) {
        hasTrack = true
        sourceLabel = b.service
        isPlaying = b.playing
        setIfChanged(\.title, b.title)
        setIfChanged(\.artist, b.artist)
        loadArtwork(b.artworkURL)
        position = b.position
        duration = b.duration
        canShuffle = false
        shuffleOn = false
        repeatOn = b.loop
    }

    private func setIfChanged(_ keyPath: ReferenceWritableKeyPath<MediaController, String>, _ value: String) {
        if self[keyPath: keyPath] != value { self[keyPath: keyPath] = value }
    }

    private func loadArtwork(_ url: String) {
        guard url != artworkURL else { return }
        artworkURL = url
        artwork = nil
        guard let u = URL(string: url), !url.isEmpty else { return }
        URLSession.shared.dataTask(with: u) { data, _, _ in
            guard let data, let img = NSImage(data: data) else { return }
            DispatchQueue.main.async { if self.artworkURL == url { self.artwork = img } }
        }.resume()
    }

    nonisolated private static func query(_ app: String) -> [String]? {
        let source: String
        if app == "Spotify" {
            source = """
            tell application "Spotify"
                if player state is stopped then return "stopped||||"
                return (player state as string) & "||" & (name of current track) & "||" & (artist of current track) & "||" & (artwork url of current track) & "||" & (player position as string) & "||" & ((duration of current track) as string) & "||" & (shuffling as string) & "||" & (repeating as string)
            end tell
            """
        } else {
            source = """
            tell application "Music"
                if player state is stopped then return "stopped||||"
                return (player state as string) & "||" & (name of current track) & "||" & (artist of current track) & "||" & "" & "||" & (player position as string) & "||" & ((duration of current track) as string) & "||" & (shuffle enabled as string) & "||" & (song repeat as string)
            end tell
            """
        }
        var error: NSDictionary?
        guard let out = NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue, error == nil else { return nil }
        let parts = out.components(separatedBy: "||")
        guard parts.count >= 3, parts[0] != "stopped" else { return nil }
        return parts
    }

    // MARK: Controls

    /// Run on the native player when it is the active source, otherwise on the browser tab.
    private func control(native script: @escaping (String) -> String, browser action: BrowserAction?) {
        let browserActive = browserTrack != nil && (browserTrack?.playing ?? false) && native?.parts[0] != "playing"
        if let n = native, !browserActive || browserTrack == nil {
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                NSAppleScript(source: script(n.app))?.executeAndReturnError(&error)
            }
        } else if let b = browserTrack, let action {
            DispatchQueue.global(qos: .userInitiated).async { BrowserMedia.command(action, on: b) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.refreshNative(); self.refreshBrowser() }
    }

    func playPause() { control(native: { "tell application \"\($0)\" to playpause" }, browser: .playPause) }
    func next() { control(native: { "tell application \"\($0)\" to next track" }, browser: .next) }
    func previous() { control(native: { "tell application \"\($0)\" to previous track" }, browser: .previous) }

    func seek(to seconds: Double) {
        let target = max(0, min(seconds, duration))
        position = target
        control(native: { "tell application \"\($0)\" to set player position to \(String(format: "%.2f", target))" },
                browser: .seek(target))
    }

    func toggleShuffle() {
        guard canShuffle else { return }
        shuffleOn.toggle()
        control(native: { app in
            app == "Spotify" ? "tell application \"Spotify\" to set shuffling to not shuffling"
                             : "tell application \"Music\" to set shuffle enabled to not shuffle enabled"
        }, browser: nil)
    }

    func toggleRepeat() {
        repeatOn.toggle()
        control(native: { app in
            app == "Spotify" ? "tell application \"Spotify\" to set repeating to not repeating"
                             : "tell application \"Music\"\nif song repeat is off then\nset song repeat to all\nelse\nset song repeat to off\nend if\nend tell"
        }, browser: .toggleLoop)
    }
}
