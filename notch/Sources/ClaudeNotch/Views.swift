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
/// the organization the copy is working in. A cross replaces the inner ring when a weekly
/// window is at 100%: out for the week.
struct RingView: View {
    let letter: String
    let account: AccountsModel.Account?

    var body: some View {
        let report = account?.report
        RingGlyph(
            color: AccountStyle.of(letter).color,
            fiveHour: (report?.fiveHour?.percentUsed ?? 0) / 100,
            weekly: (report?.weeklyPeak?.percentUsed ?? 0) / 100,
            dim: report == nil || account?.isStale == true
        )
    }
}

struct RingGlyph: View {
    let color: Color
    let fiveHour: Double
    let weekly: Double
    var dim = false

    var body: some View {
        let outerColor = fiveHour >= 0.9 ? AccountStyle.limitRed : color
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
/// slides to the next one on a switch.
struct RingsView: View {
    let model: AccountsModel
    let hasNotch: Bool
    @Namespace private var namespace

    var body: some View {
        let rings = HStack(spacing: NotchLayout.ringSpacing) {
            ForEach(model.copies) { copy in
                RingView(letter: copy.id, account: copy.active)
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
        if hasNotch {
            rings
                .padding(.leading, NotchLayout.overlap + NotchLayout.ringPadding)
                .padding(.trailing, NotchLayout.ringPadding + NotchLayout.flare)
                .frame(maxHeight: .infinity)
                .background(NotchShape(bottomRadius: 10, leftSide: false).fill(.black))
        } else {
            rings
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(NotchShape(bottomRadius: 10).fill(.black))
        }
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

/// "resets in 2h 10m" within a day, "resets Sat 14:00" beyond, "out until Sat 14:00" at
/// 100%. A 5-hour window that hasn't started has no reset time.
func resetText(_ window: UsageWindow, now: Date) -> String {
    guard let reset = window.resetsAt else {
        return window.label == "5-hour" && window.percentUsed == 0 ? "not started" : ""
    }
    let when = reset.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    if window.percentUsed >= 100 { return "out until \(when)" }
    let left = reset.timeIntervalSince(now)
    return left < 24 * 3600 ? "resets in \(UsageFormat.duration(left))" : "resets \(when)"
}

/// "Weekly" for the all-models window; the others keep their model.
func shortLabel(_ window: UsageWindow) -> String {
    window.label.replacingOccurrences(of: " · all models", with: "")
}

/// How far through its window a limit is, 0–1: where an even pace would have the bar.
/// Nil when the window hasn't started or its length isn't known.
func elapsedFraction(_ window: UsageWindow, now: Date) -> Double? {
    guard let reset = window.resetsAt else { return nil }
    let length: TimeInterval = window.label == "5-hour" ? 5 * 3600 : window.label.hasPrefix("Weekly") ? 7 * 86400 : 0
    let left = reset.timeIntervalSince(now)
    guard length > 0, left > 0, left <= length else { return nil }
    return 1 - left / length
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
