import AppKit
import CoreText
import SwiftUI

// The set the app plays on: a backdrop, the menu bar strip with the notch drawn in, a
// stand-in window per copy of Claude, and an overlay for the title, captions and keycaps.
// The site's look: black ground, Geist, the serif italic accent, the profile colours.

enum Typeface {
    static let sans = "Geist"
    static let serif = "Source Serif 4"

    /// Geist and Source Serif 4 from the site's own @fontsource packages.
    static func register(from fontsource: URL) {
        let files = [
            "geist/files/geist-latin-400-normal.woff2",
            "geist/files/geist-latin-500-normal.woff2",
            "geist/files/geist-latin-600-normal.woff2",
            "source-serif-4/files/source-serif-4-latin-500-italic.woff2",
        ]
        for file in files {
            let url = fontsource.appending(path: file)
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                print("couldn't register \(url.path): \(String(describing: error?.takeRetainedValue()))")
            }
        }
    }

    /// Text with the words between asterisks set in the serif italic, as the site's
    /// headings do.
    static func styled(_ text: String, size: CGFloat, weight: Font.Weight = .medium) -> AttributedString {
        var result = AttributedString()
        for (index, part) in text.split(separator: "*", omittingEmptySubsequences: false).enumerated() {
            var run = AttributedString(String(part))
            run.font = index % 2 == 1
                ? .custom(serif, size: size * 1.08).italic().weight(.medium)
                : .custom(sans, size: size).weight(weight)
            result += run
        }
        return result
    }
}

/// What the director changes and the stage draws.
@MainActor @Observable
final class StageState {
    var front: String?
    var showNotch = true
    /// The rings in the backdrop turn slowly; still for the hero, so its loop is seamless.
    var spin = true
    let start = Date()
}

@MainActor @Observable
final class OverlayState {
    struct Caption: Equatable {
        let text: String
        let id = UUID()
    }

    struct Keys: Equatable {
        let keys: [String]
        let id = UUID()
    }

    var curtain = 1.0
    var title = false
    var endCard = false
    var caption: Caption?
    var keys: Keys?
    var marker = false
    /// When the pointer last went down, for the pulse drawn under it.
    var click: Date?
}

/// A borderless window that never takes focus or activates the director.
final class StagePanel: NSPanel {
    init(frame: CGRect, level: NSWindow.Level) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = false
        hidesOnDeactivate = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovable = false
        animationBehavior = .none
        appearance = NSAppearance(named: .darkAqua)
        self.level = level
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

// MARK: - Backdrop

/// The site's hero art behind everything: three soft rings in the profile colours and a
/// blue glow, laid out on the film's frame (`frame`, in the view's own coordinates).
struct Backdrop: View {
    let stage: StageState
    let frame: CGRect

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: !stage.spin)) { context in
            let turn = stage.spin ? context.date.timeIntervalSince(stage.start) : 0
            art(turn: turn)
        }
        .background(.black)
    }

    private func art(turn: TimeInterval) -> some View {
        // The site's hero is about 1440 wide; the film's frame is 960.
        let k = frame.width / 1440
        return ZStack(alignment: .topLeading) {
            Color.black
            ZStack(alignment: .topLeading) {
                RadialGradient(colors: [Color(hex: 0x2F7BF5).opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: 260 * k * 1.5)
                    .frame(width: frame.width * 0.8, height: 520 * k)
                    .blur(radius: 40)
                    .offset(x: frame.width * 0.1, y: -200 * k)
                Orbit(
                    stops: [(0.18, 0), (0.38, 0x2F7BF5), (0.46, 0x9CC4FF), (0.54, 0x2F7BF5), (0.72, 0)],
                    from: 200, ring: 120 * k, blur: 6, angle: 150 + turn / 240 * 360
                )
                .frame(width: 1300 * k, height: 1300 * k)
                .offset(x: 0.38 * frame.width, y: -820 * k)
                Orbit(
                    stops: [(0.24, 0), (0.42, 0xF5822F), (0.48, 0xFFD2A8), (0.56, 0xF5822F), (0.70, 0)],
                    from: 90, ring: 80 * k, blur: 8, angle: 300 - turn / 320 * 360
                )
                .frame(width: 1000 * k, height: 1000 * k)
                .offset(x: 0.04 * frame.width, y: -560 * k)
                Orbit(
                    stops: [(0.30, 0), (0.46, 0x2FB36B), (0.52, 0xB6F5D0), (0.58, 0x2FB36B), (0.74, 0)],
                    from: 300, ring: 60 * k, blur: 5, angle: 60 + turn / 280 * 360
                )
                .frame(width: 760 * k, height: 760 * k)
                .offset(x: 0.56 * frame.width, y: -300 * k)
            }
            .frame(width: frame.width, height: frame.height, alignment: .topLeading)
            .opacity(0.5)
            .mask(LinearGradient(stops: [.init(color: .black, location: 0.55), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
            .offset(x: frame.minX, y: frame.minY)
        }
    }
}

/// One of the hero's rings: a conic gradient seen through a ring, blurred.
private struct Orbit: View {
    /// (location, colour); 0 is clear.
    let stops: [(Double, UInt32)]
    /// Where the gradient starts, in CSS degrees (0 at the top, clockwise).
    let from: Double
    let ring: CGFloat
    let blur: CGFloat
    let angle: Double

    var body: some View {
        let gradient = Gradient(stops: [Gradient.Stop(color: .clear, location: 0)] + stops.map {
            Gradient.Stop(color: $0.1 == 0 ? .clear : Color(hex: $0.1), location: $0.0)
        } + [Gradient.Stop(color: .clear, location: 1)])
        AngularGradient(gradient: gradient, center: .center, angle: .degrees(from - 90))
            .mask(Circle().strokeBorder(lineWidth: ring))
            .blur(radius: blur)
            .rotationEffect(.degrees(angle))
    }
}

/// Over the menu bar: the backdrop carries on through it, and the notch is drawn in where
/// the screen's cutout is, since a recording sees pixels, not the hardware.
struct MenuStrip: View {
    let stage: StageState
    let screen: CGSize
    let frame: CGRect
    /// The notch, in this view's coordinates.
    let notch: CGRect

    var body: some View {
        ZStack(alignment: .topLeading) {
            Backdrop(stage: stage, frame: frame)
                .frame(width: screen.width, height: screen.height)
            if stage.showNotch {
                NotchShape(flare: 0, bottomRadius: 9)
                    .fill(.black)
                    .frame(width: notch.width, height: notch.height)
                    .offset(x: notch.minX, y: notch.minY)
                    .transition(.opacity)
            }
        }
        .frame(width: screen.width, height: notch.height, alignment: .topLeading)
        .clipped()
        .animation(.smooth(duration: 0.4), value: stage.showNotch)
    }
}

// MARK: - A copy of Claude

/// A stand-in for one copy's window: its name and plan in the title bar, and a chat in
/// outline. Not Claude's own interface, just enough to read as "a copy of Claude, signed in".
struct CopyWindow: View {
    let letter: String
    let plan: String
    let stage: StageState

    var body: some View {
        let style = AccountStyle.of(letter)
        let front = stage.front == letter
        VStack(spacing: 0) {
            ZStack {
                HStack(spacing: 8) {
                    ForEach([0xFF5F57, 0xFEBC2E, 0x28C840] as [UInt32], id: \.self) { color in
                        Circle().fill(front ? Color(hex: color) : .white.opacity(0.16)).frame(width: 12, height: 12)
                    }
                    Spacer()
                    Tag(text: plan, color: front ? style.color : nil)
                }
                HStack(spacing: 7) {
                    Badge(letter: letter, color: style.color, size: 16)
                    Text("Claude \(letter)").font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(front ? 0.95 : 0.5))
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            Rectangle().fill(.white.opacity(0.06)).frame(height: 1)
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach([70, 54, 62, 40, 58], id: \.self) { width in
                        Capsule().fill(.white.opacity(0.07)).frame(width: CGFloat(width), height: 7)
                    }
                    Spacer()
                }
                .padding(16)
                .frame(width: 104, alignment: .leading)
                Rectangle().fill(.white.opacity(0.05)).frame(width: 1)
                VStack(alignment: .leading, spacing: 10) {
                    bubble(width: 150)
                    lines([236, 214, 168])
                    bubble(width: 110)
                    lines([226, 190])
                    Spacer()
                    HStack {
                        Capsule().fill(.white.opacity(0.08)).frame(width: 120, height: 7)
                        Spacer()
                        Circle().fill(style.color.opacity(front ? 0.9 : 0.4)).frame(width: 22, height: 22)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(.white.opacity(0.05)))
                    .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(.white.opacity(0.08)))
                }
                .padding(18)
            }
        }
        .background(Color(white: front ? 0.095 : 0.075))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.09)))
        .animation(.smooth(duration: 0.25), value: front)
    }

    private func bubble(width: CGFloat) -> some View {
        HStack {
            Spacer()
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.1)).frame(width: width, height: 30)
        }
    }

    private func lines(_ widths: [CGFloat]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(widths, id: \.self) { width in
                Capsule().fill(.white.opacity(0.075)).frame(width: width, height: 7)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Overlay

/// Above everything: a black curtain, the title, the captions, keycaps, the pointer, the end
/// card and the sync marker, laid out on the capture region (`frame` is the film's crop
/// inside it).
struct Overlay: View {
    let state: OverlayState
    /// The capture region in screen coordinates.
    let capture: CGRect
    let frame: CGRect

    private var size: CGSize { capture.size }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // A scrim under the captions, so they read over the windows.
            LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                .frame(width: frame.width, height: 170)
                .offset(x: frame.minX, y: frame.maxY - 170)
                .opacity(state.caption == nil ? 0 : 1)
                .animation(.smooth(duration: 0.5), value: state.caption == nil)
            ZStack {
                if let keys = state.keys {
                    Keycaps(keys: keys.keys)
                        .id(keys.id)
                        .transition(.asymmetric(insertion: .scale(scale: 0.92).combined(with: .opacity), removal: .opacity))
                }
            }
            .frame(width: frame.width, height: 48)
            .offset(x: frame.minX, y: frame.maxY - 128)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: state.keys)
            ZStack {
                if let caption = state.caption {
                    Text(Typeface.styled(caption.text, size: 22))
                        .tracking(-0.4)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .id(caption.id)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 8)),
                            removal: .opacity.combined(with: .offset(y: -4))
                        ))
                }
            }
            .frame(width: frame.width - 120, height: 60)
            .offset(x: frame.minX + 60, y: frame.maxY - 74)
            .animation(.smooth(duration: 0.45), value: state.caption)

            DrawnPointer(state: state, capture: capture)

            Color.black.opacity(state.curtain)
                .frame(width: size.width, height: size.height)
                .allowsHitTesting(false)

            Group {
                if state.title { Title().transition(.opacity.combined(with: .offset(y: 10))) }
                if state.endCard { EndCard().transition(.opacity.combined(with: .offset(y: 10))) }
            }
            .frame(width: frame.width, height: frame.height)
            .offset(x: frame.minX, y: frame.minY)
            .animation(.smooth(duration: 0.7), value: state.title)
            .animation(.smooth(duration: 0.7), value: state.endCard)

            // Outside the film's crop: the edit finds the take's cue points by it.
            Rectangle().fill(.white)
                .frame(width: 20, height: 20)
                .offset(x: 6, y: size.height - 26)
                .opacity(state.marker ? 1 : 0)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .environment(\.colorScheme, .dark)
    }
}

/// The pointer, drawn where the real one is: screen recording leaves the real one out. A
/// little larger than life so it reads on a web page, with a soft ring when it clicks.
private struct DrawnPointer: View {
    let state: OverlayState
    let capture: CGRect

    private let cursor = NSCursor.arrow
    private let scale = 1.2

    var body: some View {
        TimelineView(.animation) { context in
            let mouse = NSEvent.mouseLocation
            let tip = CGPoint(x: mouse.x - capture.minX, y: capture.maxY - mouse.y)
            let since = state.click.map { context.date.timeIntervalSince($0) } ?? .infinity
            ZStack(alignment: .topLeading) {
                if since < 0.55 {
                    let t = since / 0.55
                    let d = 12 + 30 * (1 - pow(1 - t, 3))
                    Circle()
                        .strokeBorder(.white.opacity(0.7 * (1 - t)), lineWidth: 2)
                        .background(Circle().fill(.white.opacity(0.18 * (1 - t))))
                        .frame(width: d, height: d)
                        .offset(x: tip.x - d / 2, y: tip.y - d / 2)
                }
                Image(nsImage: cursor.image)
                    .resizable()
                    .frame(width: cursor.image.size.width * scale, height: cursor.image.size.height * scale)
                    .scaleEffect(since < 0.12 ? 0.9 : 1, anchor: UnitPoint(
                        x: cursor.hotSpot.x / cursor.image.size.width, y: cursor.hotSpot.y / cursor.image.size.height
                    ))
                    .offset(x: tip.x - cursor.hotSpot.x * scale, y: tip.y - cursor.hotSpot.y * scale)
            }
            .frame(width: capture.width, height: capture.height, alignment: .topLeading)
        }
        .allowsHitTesting(false)
    }
}

private struct Keycaps: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                Text(key)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.white.opacity(0.1)))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.white.opacity(0.25)))
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.black.opacity(0.6)))
            }
        }
    }
}

private struct Title: View {
    var body: some View {
        Text(Typeface.styled("Sign in once. Run every Claude account *side by side.*", size: 50))
            .tracking(-2)
            .lineSpacing(6)
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .frame(width: 700)
    }
}

private struct EndCard: View {
    var body: some View {
        VStack(spacing: 26) {
            HStack(spacing: 14) {
                ForEach(Array(zip(["A", "B", "C"], [0.62, 0.38, 0.8]).enumerated()), id: \.offset) { _, pair in
                    BigRing(color: AccountStyle.of(pair.0).color, fiveHour: pair.1, weekly: pair.1 * 0.7)
                }
            }
            Text(Typeface.styled("Claude Notch", size: 52))
                .tracking(-2)
                .foregroundStyle(.white)
            Text(Typeface.styled("Every Claude account, *signed in at once.*", size: 24, weight: .regular))
                .tracking(-0.4)
                .foregroundStyle(.white.opacity(0.8))
            Text("Free for macOS 26")
                .font(.custom(Typeface.sans, size: 14).weight(.medium))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 14)
                .frame(height: 30)
                .overlay(Capsule().strokeBorder(.white.opacity(0.15)))
                .padding(.top, 4)
        }
    }
}

/// The app's double ring, drawn large for the end card.
private struct BigRing: View {
    let color: Color
    let fiveHour: Double
    let weekly: Double

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.28), lineWidth: 6)
            Circle().trim(from: 0, to: fiveHour).stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
            Circle().stroke(color.opacity(0.22), lineWidth: 4.5).padding(11.5)
            Circle().trim(from: 0, to: weekly).stroke(color.opacity(0.85), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                .rotationEffect(.degrees(-90)).padding(11.5)
        }
        .frame(width: 44, height: 44)
    }
}
