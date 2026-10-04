import AppKit
import SwiftUI

@MainActor
final class MediaController: ObservableObject {
    @Published var title = ""
    @Published var artist = ""
    @Published var isPlaying = false
    @Published var artwork: NSImage?
    @Published var hasTrack = false
    @Published var sourceLabel = ""
    @Published var position: Double = 0
    @Published var duration: Double = 0
    @Published var shuffleOn = false
    @Published var repeatOn = false
    @Published var canShuffle = false

    private(set) var positionDate = Date()

    func currentPosition(at date: Date = Date()) -> Double {
        guard isPlaying, duration > 0 else { return position }
        let elapsed = max(0, date.timeIntervalSince(positionDate))
        return min(duration, position + elapsed)
    }

    private var native: (app: String, parts: [String])?
    private var browserTrack: BrowserTrack?
    private var browserBusy = false
    private var artworkURL: String?
    private var artworkTask: URLSessionDataTask?
    private var timers: [Timer] = []

    private static let players = [("Spotify", "com.spotify.client"), ("Music", "com.apple.Music")]

    nonisolated(unsafe) private static let imageCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 150
        cache.totalCostLimit = 60 * 1024 * 1024
        return cache
    }()

    nonisolated private static let artworkSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(memoryCapacity: 25 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024)
        config.timeoutIntervalForRequest = 8
        config.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: config)
    }()

    init() {
        timers.append(Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshNative() }
        })
        timers.append(Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshBrowser() }
        })
        timers.append(Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshBrowserAudioState() }
        })

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshNative() }
        }
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshNative() }
        }
    }


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


    private func recompute() {
        let nativePlaying = native?.parts[0] == "playing"
        if let n = native, nativePlaying { applyNative(n) }
        else if let b = browserTrack, b.playing { applyBrowser(b) }
        else if let n = native { applyNative(n) }
        else if let b = browserTrack { applyBrowser(b) }
        else {
            title = ""; artist = ""; isPlaying = false; artwork = nil
            hasTrack = false; sourceLabel = ""; artworkURL = nil
            position = 0; duration = 0; positionDate = Date()
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
        let newIsPlaying = p[0] == "playing"
        let newTitle = p[1]
        let newArtist = p[2]
        let trackChanged = newTitle != title || newArtist != artist

        setIfChanged(\.title, newTitle)
        setIfChanged(\.artist, newArtist)
        loadArtwork(p.count > 3 ? p[3] : "")

        let polledPos = Self.number(p, 4)
        duration = n.app == "Spotify" ? Self.number(p, 5) / 1000 : Self.number(p, 5)
        canShuffle = true
        shuffleOn = p.count > 6 && p[6] == "true"
        repeatOn = p.count > 7 && p[7] != "false" && p[7] != "off"

        updatePosition(polled: polledPos, isPlaying: newIsPlaying, trackChanged: trackChanged)
    }

    private func applyBrowser(_ b: BrowserTrack) {
        let trackChanged = b.title != title || b.artist != artist
        hasTrack = true
        sourceLabel = b.service
        setIfChanged(\.title, b.title)
        setIfChanged(\.artist, b.artist)
        loadArtwork(b.artworkURL)
        duration = b.duration
        canShuffle = false
        shuffleOn = false
        repeatOn = b.loop

        updatePosition(polled: b.position, isPlaying: b.playing, trackChanged: trackChanged)
    }

    private func updatePosition(polled: Double, isPlaying newIsPlaying: Bool, trackChanged: Bool) {
        let wasPlaying = self.isPlaying
        self.isPlaying = newIsPlaying

        if trackChanged {
            position = polled
            positionDate = Date()
            return
        }

        if !newIsPlaying {
            position = polled
            positionDate = Date()
            return
        }

        if !wasPlaying {
            position = polled
            positionDate = Date()
            return
        }

        let interpolated = currentPosition()
        let delta = abs(polled - interpolated)

        if delta > 1.5 {
            position = polled
            positionDate = Date()
        } else if delta > 0.3 {
            position = (interpolated * 0.7) + (polled * 0.3)
            positionDate = Date()
        }
    }

    private func setIfChanged(_ keyPath: ReferenceWritableKeyPath<MediaController, String>, _ value: String) {
        if self[keyPath: keyPath] != value { self[keyPath: keyPath] = value }
    }

    private static func normalizeArtworkURL(_ raw: String) -> String {
        var url = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.hasPrefix("spotify:image:") {
            let id = url.replacingOccurrences(of: "spotify:image:", with: "")
            url = "https://i.scdn.co/image/\(id)"
        } else if url.hasPrefix("http://") {
            url = "https://" + url.dropFirst(7)
        }
        return url
    }

    private func loadArtwork(_ rawURL: String) {
        let url = Self.normalizeArtworkURL(rawURL)
        guard url != artworkURL else { return }
        artworkURL = url
        artworkTask?.cancel()

        guard !url.isEmpty, let u = URL(string: url) else {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                self.artwork = nil
            }
            return
        }

        if let cached = Self.imageCache.object(forKey: url as NSString) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                self.artwork = cached
            }
            return
        }

        var request = URLRequest(url: u)
        request.cachePolicy = .returnCacheDataElseLoad
        let task = Self.artworkSession.dataTask(with: request) { [weak self] data, _, _ in
            guard let data, let img = NSImage(data: data) else {
                DispatchQueue.main.async {
                    guard let self, self.artworkURL == url else { return }
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                        self.artwork = nil
                    }
                }
                return
            }
            Self.imageCache.setObject(img, forKey: url as NSString, cost: data.count)
            DispatchQueue.main.async {
                guard let self, self.artworkURL == url else { return }
                withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                    self.artwork = img
                }
            }
        }
        task.priority = URLSessionTask.highPriority
        artworkTask = task
        task.resume()
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

    func playPause() {
        if isPlaying {
            position = currentPosition()
            isPlaying = false
        } else {
            positionDate = Date()
            isPlaying = true
        }
        control(native: { "tell application \"\($0)\" to playpause" }, browser: .playPause)
    }

    func next() {
        position = 0
        positionDate = Date()
        control(native: { "tell application \"\($0)\" to next track" }, browser: .next)
    }

    func previous() {
        position = 0
        positionDate = Date()
        control(native: { "tell application \"\($0)\" to previous track" }, browser: .previous)
    }

    func seek(to seconds: Double) {
        let target = max(0, min(seconds, duration))
        position = target
        positionDate = Date()
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
