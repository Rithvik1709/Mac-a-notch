import SwiftUI

enum LiveActivityLayout {
    static let sideWidth: CGFloat = 115

    static func size(notch: CGSize) -> CGSize {
        CGSize(width: notch.width + sideWidth * 2, height: notch.height)
    }
}

struct LiveActivityView: View {
    @ObservedObject var media: MediaController
    let notch: CGSize

    private var side: CGFloat { LiveActivityLayout.sideWidth }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 7) {
                ArtworkView(image: media.artwork, size: 22, cornerRadius: 5)
                EqualizerBars(active: media.isPlaying)
            }
            .padding(.leading, 12)
            .frame(width: side, alignment: .leading)

            Spacer().frame(width: notch.width)

            MarqueeText(text: media.title, width: side - 22)
                .id(media.title)
                .padding(.leading, 8)
                .frame(width: side, alignment: .leading)
        }
        .frame(height: notch.height)
        .foregroundStyle(.white)
    }
}

struct EqualizerBars: View {
    let active: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: !active)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule().fill(.white.opacity(0.85))
                        .frame(width: 2.5, height: 4 + 10 * abs(sin(t * (3.2 + Double(i) * 0.9) + Double(i))))
                }
            }
            .frame(height: 16)
        }
    }
}

struct MarqueeText: View {
    let text: String
    let width: CGFloat
    @State private var offset: CGFloat = 0

    private let font = NSFont.systemFont(ofSize: 11, weight: .medium)
    private let gap: CGFloat = 28

    private var textWidth: CGFloat { (text as NSString).size(withAttributes: [.font: font]).width }

    var body: some View {
        Group {
            if textWidth <= width {
                label.frame(width: width, alignment: .leading)
            } else {
                HStack(spacing: gap) { label; label }
                    .fixedSize()
                    .offset(x: offset)
                    .frame(width: width, alignment: .leading)
                    .clipped()
                    .onAppear { start() }
            }
        }
    }

    private var label: some View {
        Text(text).font(Font(font)).lineLimit(1).fixedSize()
    }

    private func start() {
        offset = 0
        let distance = textWidth + gap
        withAnimation(.linear(duration: Double(distance) / 28).delay(1.2).repeatForever(autoreverses: false)) {
            offset = -distance
        }
    }
}
