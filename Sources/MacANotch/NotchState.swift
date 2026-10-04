import AppKit
import SwiftUI

enum NotchTab: String, CaseIterable, Identifiable {
    case shelf, clipboard, media, calendar, timer, claude, shortcuts, system, mirror, tools
    var id: String { rawValue }

    var title: String {
        switch self {
        case .shelf: "Shelf"
        case .clipboard: "Clipboard"
        case .media: "Media"
        case .calendar: "Calendar"
        case .timer: "Timer"
        case .claude: "Claude"
        case .shortcuts: "Shortcuts"
        case .system: "System"
        case .mirror: "Mirror"
        case .tools: "Tools"
        }
    }

    var icon: String {
        switch self {
        case .shelf: "tray.full"
        case .clipboard: "doc.on.clipboard"
        case .media: "music.note"
        case .calendar: "calendar"
        case .timer: "timer"
        case .claude: "sparkles"
        case .shortcuts: "bolt.fill"
        case .system: "cpu"
        case .mirror: "camera.fill"
        case .tools: "wrench.and.screwdriver"
        }
    }

    var prefKey: String {
        switch self {
        case .shelf: Pref.shelf
        case .clipboard: Pref.clipboard
        case .media: Pref.media
        case .calendar: Pref.calendar
        case .timer: Pref.timer
        case .claude: Pref.claude
        case .shortcuts: Pref.shortcuts
        case .system: Pref.system
        case .mirror: Pref.mirror
        case .tools: Pref.tools
        }
    }
}

@MainActor
final class NotchState: ObservableObject {
    static let expandedSize = CGSize(width: 580, height: 225)
    static let panelPadding: CGFloat = 20

    @Published var expanded = false
    @Published var tab: NotchTab = .shelf
    @Published var dropTargeted = false
    @Published var hud: HUDEvent?
    @Published var notchSize = CGSize(width: 190, height: 32)
}

enum NotchGeometry {
    static func targetScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens.first
    }

    static func notchSize(for screen: NSScreen) -> CGSize {
        if !Pref.bool(Pref.islandMode), screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            return CGSize(width: screen.frame.width - left.width - right.width,
                          height: screen.safeAreaInsets.top)
        }
        return CGSize(width: 190, height: 32)
    }
}

struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set { topRadius = newValue.first; bottomRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let t = min(topRadius, h / 2), b = min(bottomRadius, h / 2)
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addQuadCurve(to: CGPoint(x: t, y: t), control: CGPoint(x: t, y: 0))
        p.addLine(to: CGPoint(x: t, y: h - b))
        p.addQuadCurve(to: CGPoint(x: t + b, y: h), control: CGPoint(x: t, y: h))
        p.addLine(to: CGPoint(x: w - t - b, y: h))
        p.addQuadCurve(to: CGPoint(x: w - t, y: h - b), control: CGPoint(x: w - t, y: h))
        p.addLine(to: CGPoint(x: w - t, y: t))
        p.addQuadCurve(to: CGPoint(x: w, y: 0), control: CGPoint(x: w - t, y: 0))
        p.closeSubpath()
        return p
    }
}

extension AnyTransition {
    static var notchContent: AnyTransition {
        .asymmetric(insertion: .opacity.animation(.easeInOut(duration: 0.18).delay(0.1)),
                    removal: .opacity.animation(.easeOut(duration: 0.06)))
    }
}
