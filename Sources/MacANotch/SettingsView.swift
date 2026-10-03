import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage(Pref.shelf) private var shelf = true
    @AppStorage(Pref.basket) private var basket = true
    @AppStorage(Pref.clipboard) private var clipboard = true
    @AppStorage(Pref.media) private var media = true
    @AppStorage(Pref.timer) private var timer = true
    @AppStorage(Pref.tools) private var tools = true
    @AppStorage(Pref.calendar) private var calendar = true
    @AppStorage(Pref.claude) private var claude = true
    @AppStorage(Pref.system) private var system = true
    @AppStorage(Pref.shortcuts) private var shortcuts = true
    @AppStorage(Pref.mirror) private var mirror = true
    @AppStorage(Pref.hoverOpen) private var hoverOpen = true
    @AppStorage(Pref.hapticFeedback) private var haptics = true
    @AppStorage(Pref.clipboardLimit) private var limit = 50
    @AppStorage(Pref.islandMode) private var island = false
    @AppStorage(Pref.liveActivity) private var liveActivity = true
    @AppStorage(Pref.browserMedia) private var browserMedia = true
    @AppStorage(Pref.lockHUD) private var lockHUD = true
    @AppStorage(Pref.batteryHUD) private var batteryHUD = true
    @AppStorage(Pref.capsLockHUD) private var capsLockHUD = true
    @AppStorage(Pref.volumeHUD) private var volumeHUD = true
    @AppStorage(Pref.brightnessHUD) private var brightnessHUD = true
    @AppStorage(Pref.airpodsHUD) private var airpodsHUD = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Features") {
                Toggle("Notch shelf (drag & drop files)", isOn: $shelf)
                Toggle("Floating basket (jiggle while dragging)", isOn: $basket)
                Toggle("Clipboard manager", isOn: $clipboard)
                Toggle("Media player (Music & Spotify)", isOn: $media)
                Toggle("Pomodoro timer", isOn: $timer)
                Toggle("Tools (High Alert, emoji picker)", isOn: $tools)
                Toggle("Calendar and meetings", isOn: $calendar)
                Toggle("Claude Code status", isOn: $claude)
                Toggle("Shortcuts launcher", isOn: $shortcuts)
                Toggle("System monitor", isOn: $system)
                Toggle("Camera mirror", isOn: $mirror)
            }
            Section("Media") {
                Toggle("Live activity in the collapsed notch", isOn: $liveActivity)
                Toggle("Detect browser media (YouTube, SoundCloud…)", isOn: $browserMedia)
                Text("For song details and play/pause from Chrome, Brave, Arc or Edge enable View → Developer → Allow JavaScript from Apple Events (Safari: Develop menu). Without it only the tab title is shown.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("HUDs") {
                Toggle("Volume HUD", isOn: $volumeHUD)
                Toggle("Brightness HUD", isOn: $brightnessHUD)
                Toggle("AirPods / Bluetooth audio HUD", isOn: $airpodsHUD)
                Toggle("Battery HUD (plug in, low, full)", isOn: $batteryHUD)
                Toggle("Lock / unlock animation", isOn: $lockHUD)
                Toggle("Caps Lock HUD", isOn: $capsLockHUD)
            }
            Section("Behavior") {
                Toggle("Open on hover", isOn: $hoverOpen)
                Toggle("Haptic feedback", isOn: $haptics)
                Toggle("Dynamic Island style (ignore hardware notch)", isOn: $island)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                    }
            }
            Section("Clipboard") {
                Stepper("History size: \(limit)", value: $limit, in: 10...500, step: 10)
                Text("Password managers and concealed copies are never recorded.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 1010)
    }
}
