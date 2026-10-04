import AppKit
import SwiftUI

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = NotchState()
    let shelf = ShelfStore()
    let clipboard = ClipboardManager()
    let media = MediaController()
    let pomodoro = PomodoroModel()
    let highAlert = HighAlertModel()
    let calendar = CalendarModel()
    let agents = AgentMonitor()
    let system = SystemMonitor()
    let shortcuts = ShortcutsModel()

    private var hudMonitor: HUDMonitor?
    private var panel: NotchPanel!
    private var basket: BasketController!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var monitors: [Any] = []
    private var expandWork: DispatchWorkItem?

    private var dragBaseline = 0
    private var draggingContent = false
    private var lastDir = 0
    private var reversals: [Date] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        Pref.registerDefaults()
        basket = BasketController(shelf: shelf)
        setUpPanel()
        setUpStatusItem()
        setUpMonitors()
        hudMonitor = HUDMonitor(state: state)
        pomodoro.onFinish = { [weak self] phase in
            NSSound(named: "Glass")?.play()
            self?.hudMonitor?.showMessage(icon: phase == .focus ? "checkmark.circle.fill" : "cup.and.saucer.fill",
                                          title: phase == .focus ? "Focus complete" : "Break over",
                                          subtitle: phase == .focus ? "Time for a break" : "Back to focus", duration: 5)
        }
        calendar.onMeetingSoon = { [weak self] event, minutes in
            NSSound(named: "Glass")?.play()
            self?.hudMonitor?.showMessage(icon: "calendar", title: event.title,
                                          subtitle: minutes <= 1 ? "Starting now" : "Starts in \(minutes) min", duration: 6)
        }
        agents.onTransition = { [weak self] session in
            let done = session.state == .done
            self?.hudMonitor?.showMessage(icon: done ? "checkmark.circle.fill" : "exclamationmark.bubble.fill",
                                          title: done ? "Claude finished" : "Claude needs you",
                                          subtitle: session.project, duration: 5)
        }
        highAlert.onChange = { [weak self] on in
            self?.hudMonitor?.showMessage(icon: "cup.and.saucer.fill", title: on ? "High Alert on" : "High Alert off",
                                          subtitle: on ? "Your Mac will stay awake" : "Sleep settings restored", duration: 2.5)
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.positionPanel() }
        }
    }


    private func setUpPanel() {
        let pad = NotchState.panelPadding
        let size = CGSize(width: NotchState.expandedSize.width + pad * 2, height: NotchState.expandedSize.height + pad)
        panel = NotchPanel(contentRect: NSRect(origin: .zero, size: size),
                           styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.ignoresMouseEvents = true

        let root = NotchView(state: state, shelf: shelf, clipboard: clipboard, media: media,
                             pomodoro: pomodoro, calendar: calendar, agents: agents, system: system,
                             shortcuts: shortcuts, highAlert: highAlert)
        let host = NSHostingView(rootView: root)
        host.sizingOptions = []
        panel.contentView = host
        positionPanel()
        panel.orderFrontRegardless()
    }

    private func positionPanel() {
        guard let screen = NotchGeometry.targetScreen() else { return }
        state.notchSize = NotchGeometry.notchSize(for: screen)
        let f = screen.frame
        panel.setFrame(NSRect(x: f.midX - panel.frame.width / 2, y: f.maxY - panel.frame.height,
                              width: panel.frame.width, height: panel.frame.height), display: true)
    }


    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "Mac-a-notch")
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Notch", action: #selector(toggleNotch), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Mac-a-notch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.items.forEach { $0.target = $0.action == #selector(NSApplication.terminate(_:)) ? NSApp : self }
        statusItem.menu = menu
    }

    @objc private func toggleNotch() { setExpanded(!state.expanded) }

    @objc func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            w.title = "Mac-a-notch Settings"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            settingsWindow = w
        }
        setExpanded(false)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }


    private func setExpanded(_ expanded: Bool) {
        guard state.expanded != expanded else { return }
        expandWork?.cancel()
        if expanded {
            if let first = NotchTab.allCases.first(where: { Pref.bool($0.prefKey) }), !Pref.bool(state.tab.prefKey) {
                state.tab = first
            }
            if Pref.bool(Pref.media), media.hasTrack, media.isPlaying, !draggingContent { state.tab = .media }
            if Pref.bool(Pref.hapticFeedback) {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
            state.hud = nil
            panel.ignoresMouseEvents = false
            panel.makeKey()
        } else {
            panel.ignoresMouseEvents = true
            panel.resignKey()
        }
        state.expanded = expanded
    }


    private func setUpMonitors() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .leftMouseDown, .leftMouseUp]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            let type = event.type, dx = event.deltaX
            MainActor.assumeIsolated { self?.onMouse(type, dx: dx) }
        }) { monitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            let type = event.type, dx = event.deltaX
            MainActor.assumeIsolated { self?.onMouse(type, dx: dx) }
            return event
        }) { monitors.append(local) }
    }

    private func onMouse(_ type: NSEvent.EventType, dx: CGFloat) {
        switch type {
        case .leftMouseDown:
            dragBaseline = NSPasteboard(name: .drag).changeCount
            draggingContent = false
        case .leftMouseUp:
            draggingContent = false
            reversals.removeAll()
            basket.scheduleHide()
        case .leftMouseDragged:
            if !draggingContent, NSPasteboard(name: .drag).changeCount != dragBaseline { draggingContent = true }
            if draggingContent { trackJiggle(dx: dx) }
        default: break
        }
        evaluateHover()
    }

    private func trackJiggle(dx: CGFloat) {
        guard Pref.bool(Pref.basket), abs(dx) > 3 else { return }
        let dir = dx > 0 ? 1 : -1
        guard dir != lastDir else { return }
        lastDir = dir
        let now = Date()
        reversals = reversals.filter { now.timeIntervalSince($0) < 0.8 } + [now]
        if reversals.count >= 5 {
            reversals.removeAll()
            basket.show(near: NSEvent.mouseLocation)
        }
    }

    private func evaluateHover() {
        guard let screen = panel.screen ?? NotchGeometry.targetScreen() else { return }
        let loc = NSEvent.mouseLocation
        let f = screen.frame
        let notch = state.notchSize

        if state.expanded {
            guard NSEvent.pressedMouseButtons & 1 == 0 else { return }
            let w = NotchState.expandedSize.width, h = NotchState.expandedSize.height
            let inside = loc.x >= f.midX - w / 2 - 14 && loc.x <= f.midX + w / 2 + 14
                && loc.y >= f.maxY - h - 14 && loc.y <= f.maxY
            if !inside { setExpanded(false) }
            return
        }

        let liveShowing = pomodoro.started || (Pref.bool(Pref.liveActivity) && Pref.bool(Pref.media) && media.hasTrack && media.isPlaying)
        let slackX: CGFloat = liveShowing ? LiveActivityLayout.sideWidth : draggingContent ? 60 : 8
        let slackY: CGFloat = draggingContent ? 30 : 4
        let hot = abs(loc.x - f.midX) <= notch.width / 2 + slackX && loc.y >= f.maxY - notch.height - slackY && loc.y <= f.maxY
        guard hot, Pref.bool(Pref.hoverOpen) || draggingContent else {
            expandWork?.cancel(); expandWork = nil
            return
        }
        guard expandWork == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            self?.expandWork = nil
            self?.setExpanded(true)
        }
        expandWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (draggingContent ? 0.05 : 0.15), execute: work)
    }
}
