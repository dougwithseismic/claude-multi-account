import SwiftUI
import UsageCore

// MARK: - Shapes

/// Black that reads as part of the notch: concave curves where it meets the top edge of
/// the screen, rounded bottom corners.
struct NotchShape: Shape {
    var flare: CGFloat = NotchLayout.flare
    var bottomRadius: CGFloat = 18
    /// Off for the rings' backing, whose left edge is hidden inside the notch.
    var leftSide = true

    func path(in rect: CGRect) -> Path {
        let f = min(flare, rect.width / 4), b = max(min(bottomRadius, rect.height - f, rect.width / 2 - f), 0)
        var p = Path()
        if leftSide {
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addQuadCurve(to: CGPoint(x: rect.minX + f, y: rect.minY + f), control: CGPoint(x: rect.minX + f, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX + f, y: rect.maxY - b))
            p.addQuadCurve(to: CGPoint(x: rect.minX + f + b, y: rect.maxY), control: CGPoint(x: rect.minX + f, y: rect.maxY))
        } else {
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        p.addLine(to: CGPoint(x: rect.maxX - f - b, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - f, y: rect.maxY - b), control: CGPoint(x: rect.maxX - f, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - f, y: rect.minY + f))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.maxX - f, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

/// The notch shape over a rect that animates: the panel and the peek grow out of the
/// notch and fold back into it as one shape, its corners rounding as it grows.
struct MorphShape: Shape {
    var rect: CGRect
    var radius: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat>> {
        get { AnimatablePair(AnimatablePair(rect.minX, rect.minY), AnimatablePair(AnimatablePair(rect.width, rect.height), radius)) }
        set {
            rect = CGRect(
                x: newValue.first.first, y: newValue.first.second,
                width: max(newValue.second.first.first, 0), height: max(newValue.second.first.second, 0)
            )
            radius = newValue.second.second
        }
    }

    func path(in _: CGRect) -> Path { NotchShape(bottomRadius: radius).path(in: rect) }
}

// MARK: - Collapsed: one ring per copy

/// The outer ring is the 5-hour window, the inner one the fullest weekly window, both for
/// the organization the copy is working in. At 100% the outer ring turns into the wait:
/// red, unwinding to the reset. A cross replaces the inner ring when a weekly window is at
/// 100%: out for the week.
struct RingView: View {
    let letter: String
    let account: AccountsModel.Account?
    var now = Date()

    var body: some View {
        let report = account?.report
        let wait = report?.fiveHour.flatMap { waitFraction($0, now: now) }
        RingGlyph(
            color: AccountStyle.of(letter).color,
            fiveHour: wait ?? (report?.fiveHour?.percentUsed ?? 0) / 100,
            fiveHourOut: wait != nil,
            weekly: (report?.weeklyPeak?.percentUsed ?? 0) / 100,
            dim: report == nil || account?.isStale == true
        )
    }
}

struct RingGlyph: View {
    let color: Color
    /// Used, or with `fiveHourOut` the wait left.
    let fiveHour: Double
    var fiveHourOut = false
    let weekly: Double
    var dim = false

    var body: some View {
        let outerColor = fiveHourOut || fiveHour >= 0.9 ? AccountStyle.limitRed : color
        ZStack {
            Circle().stroke(color.opacity(0.28), lineWidth: 2.2)
            Circle().trim(from: 0, to: min(fiveHour, 1))
                .stroke(outerColor, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if weekly >= 1 {
                Image(systemName: "xmark").font(.system(size: 6.5, weight: .heavy)).foregroundStyle(AccountStyle.limitRed)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Circle().stroke(color.opacity(0.22), lineWidth: 1.6).padding(4.2)
                Circle().trim(from: 0, to: weekly)
                    .stroke(color.opacity(0.85), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(4.2)
            }
        }
        .frame(width: NotchLayout.ringSize - 2, height: NotchLayout.ringSize - 2)
        .frame(width: NotchLayout.ringSize, height: NotchLayout.ringSize)
        .opacity(dim ? 0.45 : 1)
        .animation(.spring(response: 0.8, dampingFraction: 0.85), value: fiveHour)
        .animation(.spring(response: 0.8, dampingFraction: 0.85), value: weekly)
        .animation(.smooth(duration: 0.3), value: dim)
    }
}

/// The rings beside the notch, with a dot under the copy in front (or used last) that
/// slides to the next one on a switch. When every copy is out, the one back first and how
/// long it has left sit beside them, while the notch is closed.
struct RingsView: View {
    let model: AccountsModel
    let hasNotch: Bool
    /// Nil draws the notch closed.
    var state: NotchState?
    @Namespace private var namespace

    var body: some View {
        // Often enough for an unwinding ring; a countdown in its last minutes keeps its own time.
        TimelineView(.periodic(from: .now, by: 30)) { context in
            content(now: context.date)
        }
    }

    @ViewBuilder private func content(now: Date) -> some View {
        let closed = state.map { !$0.isOpen && !$0.peekShown } ?? true
        let back = closed ? model.soonestBack : nil
        let line = HStack(spacing: 8) {
            HStack(spacing: NotchLayout.ringSpacing) {
                ForEach(model.copies) { copy in
                    RingView(letter: copy.id, account: copy.active, now: now)
                        .overlay(alignment: .bottom) {
                            // A pill is too short for the dot.
                            if hasNotch, model.lastUsed == copy.id {
                                Circle().fill(AccountStyle.of(copy.id).color)
                                    .frame(width: 3, height: 3)
                                    .matchedGeometryEffect(id: "current", in: namespace)
                                    .offset(y: 6)
                            }
                        }
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.72), value: model.lastUsed)
            if let back {
                SoonestBack(letter: back.letter, at: back.at, now: now)
                    .transition(.opacity.combined(with: .offset(x: -6)))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: back?.letter)
        if hasNotch {
            line
                .padding(.leading, NotchLayout.overlap + NotchLayout.ringPadding)
                .padding(.trailing, NotchLayout.ringPadding + NotchLayout.flare)
                .frame(maxHeight: .infinity)
                .background(NotchShape(bottomRadius: 10, leftSide: false).fill(.black))
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            line
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(NotchShape(bottomRadius: 10).fill(.black))
        }
    }
}

/// "C 4:12": the copy back first when every copy is out, and how long until it is.
struct SoonestBack: View {
    let letter: String
    let at: Date
    let now: Date

    var body: some View {
        HStack(spacing: 4) {
            Text(letter).foregroundStyle(AccountStyle.of(letter).color)
            Countdown(target: at, now: now) { date in
                let text = countdown(at.timeIntervalSince(date))
                Text(text)
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.smooth(duration: 0.2), value: text)
            }
            .foregroundStyle(.white.opacity(0.9))
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .lineLimit(1)
        .fixedSize()
    }
}

extension AccountsModel {
    /// Every copy is out in the organization it works in: the one back first, and when.
    /// Nil while any copy can still be used, or isn't read yet.
    var soonestBack: (letter: String, at: Date)? {
        var soonest: (letter: String, at: Date)?
        for copy in copies {
            guard let report = copy.active?.report, report.isOut else { return nil }
            guard let at = report.backAt else { continue }
            if soonest.map({ at < $0.at }) ?? true { soonest = (copy.id, at) }
        }
        return soonest
    }
}

/// A copy's letter on its colour.
struct Badge: View {
    let letter: String
    let color: Color
    var size: CGFloat = 22

    var body: some View {
        Text(letter)
            .font(.system(size: size * 0.5, weight: .bold, design: .rounded))
            .foregroundStyle(.black.opacity(0.82))
            .frame(width: size, height: size)
            .background(Circle().fill(color.gradient))
    }
}

// MARK: - Opening

extension EnvironmentValues {
    /// The panel is open: rows slide in one after another and bars fill from empty.
    @Entry var revealed = true
    /// The pointer is over the row a view is in.
    @Entry var rowHovered = false
}

/// Slides a view in as the panel opens, a little after the one above it.
struct Reveal: ViewModifier {
    @Environment(\.revealed) private var revealed
    let index: Int

    func body(content: Content) -> some View {
        content
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : -8)
            .animation(
                revealed ? .spring(response: 0.42, dampingFraction: 0.82).delay(Self.delay(index)) : .easeIn(duration: 0.08),
                value: revealed
            )
    }

    static func delay(_ index: Int) -> Double { 0.05 + 0.035 * Double(min(index, 10)) }
}

// MARK: - Wording

/// "back in 2h 41m" at 100%, "resets in 3d 4h" below it; by the clock instead ("back at
/// 16:19", "resets Mon 09:00") when `clock` is set, as it is while the row is hovered.
/// A 5-hour window that hasn't started has no reset time.
func resetText(_ window: UsageWindow, now: Date, clock: Bool = false) -> String {
    guard let reset = window.resetsAt else {
        return window.label == "5-hour" && window.percentUsed == 0 ? "not started" : ""
    }
    let verb = window.percentUsed >= 100 ? "back" : "resets"
    if clock { return "\(verb) \(clockText(reset, now: now, atToday: true))" }
    let left = reset.timeIntervalSince(now)
    // Past the reset, before the next read has caught up with it.
    return left > 0 ? "\(verb) in \(countdown(left))" : "\(verb) now"
}

/// Time left: "2d 4h", "2h 41m", "41m", then minutes and seconds ("4:12") for the last
/// ten minutes, when it's worth watching.
func countdown(_ seconds: TimeInterval) -> String {
    guard seconds > 0 else { return "now" }
    guard seconds < countdownSecondsFrom else { return UsageFormat.duration(seconds) }
    let s = Int(seconds)
    return "\(s / 60):" + String(format: "%02d", s % 60)
}

/// Under this many seconds left, a countdown shows seconds and ticks every second.
let countdownSecondsFrom: TimeInterval = 10 * 60

/// A reset by the clock: "16:19" today ("at 16:19" with `atToday`), "tomorrow 09:00", "Mon
/// 09:00" within the week, "26 Oct 09:00" beyond. A weekday a week out would read as today's.
func clockText(_ date: Date, now: Date, atToday: Bool = false, calendar: Calendar = .current) -> String {
    let time = date.formatted(.dateTime.hour().minute())
    let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
    switch days {
    case ...0: return atToday ? "at \(time)" : time
    case 1: return "tomorrow \(time)"
    case 2...6: return "\(date.formatted(.dateTime.weekday(.abbreviated))) \(time)"
    default: return "\(date.formatted(.dateTime.day().month(.abbreviated))) \(time)"
    }
}

/// "Weekly" for the all-models window; the others keep their model.
func shortLabel(_ window: UsageWindow) -> String {
    window.label.replacingOccurrences(of: " · all models", with: "")
}

/// How long a window lasts, when it's known.
func windowLength(_ window: UsageWindow) -> TimeInterval? { PaceProjection.windowLength(window) }

/// How far through its window a limit is, 0–1: where the pace tick sits.
func elapsedFraction(_ window: UsageWindow, now: Date) -> Double? { PaceProjection.elapsedFraction(window, now: now) }

/// How much of the wait is left for a window at 100%, 1 down to 0 at its reset: its bar
/// and ring drain as the time passes. Nil below 100%, or when the wait can't be told.
func waitFraction(_ window: UsageWindow, now: Date) -> Double? {
    guard window.percentUsed >= 100, let reset = window.resetsAt, let length = windowLength(window) else { return nil }
    return min(max(reset.timeIntervalSince(now) / length, 0), 1)
}

/// The countdown and the clock together, for a peek, which can't be hovered: "back in
/// 2h 41m · 16:19".
func resetTextWithClock(_ window: UsageWindow, now: Date) -> String {
    let text = resetText(window, now: now)
    guard let reset = window.resetsAt else { return text }
    return "\(text) · \(clockText(reset, now: now))"
}

/// Text that counts down to `target`: redrawn every second from ten minutes out, when its
/// countdown shows seconds; otherwise with the view around it.
struct Countdown<Content: View>: View {
    let target: Date?
    let now: Date
    @ViewBuilder let content: (Date) -> Content

    var body: some View {
        if let target, target.timeIntervalSince(now) < countdownSecondsFrom + 60, target.timeIntervalSince(now) > -5 {
            // On the target's own seconds, a hair before each one turns, so every second shows once.
            TimelineView(.periodic(from: target.addingTimeInterval(-(countdownSecondsFrom + 60.02)), by: 1)) { context in
                content(context.date)
            }
        } else {
            content(now)
        }
    }
}

func age(_ date: Date, now: Date) -> String {
    let seconds = now.timeIntervalSince(date)
    return seconds < 60 ? "just now" : "\(UsageFormat.duration(seconds)) ago"
}

extension AccountsModel.Account {
    /// "Team · Acme", "Max 20x · Personal".
    var planLabel: String? { PlanName.label(plan: plan, organization: organizationLabel) }

    /// The plan alone ("Team") unless details show, so a Team's name stays private.
    func planText(showsDetails: Bool) -> String? { showsDetails ? planLabel : plan }

    /// The login has expired or was revoked: the numbers are old until that copy renews it.
    var isStale: Bool {
        switch error {
        case .tokenExpired, .unauthorized, .noLogin: true
        default: false
        }
    }

    /// Small text at the right of the header: how old the numbers are when they aren't fresh.
    func status(now: Date) -> String? {
        guard error != nil, let reportAt else { return nil }
        if case .rateLimited = error {
            return "retrying in \(UsageFormat.duration(nextPoll.timeIntervalSince(now))) · \(age(reportAt, now: now))"
        }
        return age(reportAt, now: now)
    }

    /// What to say instead of, or under, the numbers. Names the launcher ("Claude B"), not
    /// the label in profiles.json, which may be an email.
    var message: String? {
        let label = "Claude \(letter)"
        switch error {
        case nil: return report == nil ? "Reading…" : nil
        // Claude renews only the login of the organization it's working in.
        case .tokenExpired, .unauthorized:
            return isActive ? "Open \(label) to update" : "Switch \(label) to this organization to update"
        case .noLogin: return "No login for this organization yet"
        case .notSignedIn: return "Sign in to \(label)"
        case .otherAccount: return nil
        case .rateLimited: return report == nil ? "Rate-limited; retrying later" : nil
        case .keychain, .keychainItemMissing: return report == nil ? "Waiting for Keychain access" : nil
        case .network: return report == nil ? "Offline; retrying" : nil
        case .unexpectedResponse, .http, .unknownEncryption, .unreadableTokenCache, .unreadableConfig:
            return report == nil ? "Usage unavailable" : nil
        }
    }
}
