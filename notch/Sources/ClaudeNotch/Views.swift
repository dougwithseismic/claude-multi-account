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
        let f = flare, b = min(bottomRadius, rect.height - f)
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

// MARK: - Collapsed: one ring per copy

/// The outer ring is the 5-hour window, the inner one the fullest weekly window, both for
/// the organization the copy is working in. A cross replaces the inner ring when a weekly
/// window is at 100%: out for the week.
struct RingView: View {
    let letter: String
    let account: AccountsModel.Account?

    var body: some View {
        let style = AccountStyle.of(letter)
        let report = account?.report
        let fiveHour = (report?.fiveHour?.percentUsed ?? 0) / 100
        let weekly = (report?.weeklyPeak?.percentUsed ?? 0) / 100
        let outerColor = fiveHour >= 0.9 ? AccountStyle.limitRed : style.color
        let dim = report == nil || account?.isStale == true
        ZStack {
            Circle().stroke(style.color.opacity(0.28), lineWidth: 2.2)
            Circle().trim(from: 0, to: min(fiveHour, 1))
                .stroke(outerColor, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if weekly >= 1 {
                Image(systemName: "xmark").font(.system(size: 6.5, weight: .heavy)).foregroundStyle(AccountStyle.limitRed)
            } else {
                Circle().stroke(style.color.opacity(0.22), lineWidth: 1.6).padding(4.2)
                Circle().trim(from: 0, to: weekly)
                    .stroke(style.color.opacity(0.85), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(4.2)
            }
        }
        .frame(width: NotchLayout.ringSize - 2, height: NotchLayout.ringSize - 2)
        .frame(width: NotchLayout.ringSize, height: NotchLayout.ringSize)
        .opacity(dim ? 0.45 : 1)
    }
}

struct RingsView: View {
    let model: AccountsModel
    let hasNotch: Bool

    var body: some View {
        let rings = HStack(spacing: NotchLayout.ringSpacing) {
            ForEach(model.copies) { RingView(letter: $0.id, account: $0.active) }
        }
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

// MARK: - Open: one row per copy

struct PanelView: View {
    static let width: CGFloat = 460

    let model: AccountsModel
    /// Space left empty behind the notch.
    let topInset: CGFloat
    let open: (String) -> Void
    let quit: () -> Void
    var footerExtras: AnyView? = nil

    var body: some View {
        TimelineView(.periodic(from: .now, by: 20)) { context in
            VStack(alignment: .leading, spacing: 0) {
                Color.clear.frame(height: topInset)
                VStack(alignment: .leading, spacing: 4) {
                    if let problem = model.keychainProblem { KeychainBanner(problem: problem, retry: model.retryKeychain) }
                    if model.profiles.isEmpty {
                        Text("No Claude profiles in ~/Library/Application Support")
                            .font(.system(size: 12)).foregroundStyle(.secondary).padding(.vertical, 10)
                    }
                    ForEach(model.copies) { copy in
                        Button { open(copy.id) } label: { CopyRow(copy: copy, now: context.date) }
                            .buttonStyle(RowButtonStyle())
                    }
                    footer(now: context.date)
                }
                .padding(.horizontal, NotchLayout.flare + 12)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .frame(width: Self.width, alignment: .leading)
            .background(NotchShape().fill(.black))
        }
        .environment(\.colorScheme, .dark)
    }

    func footer(now: Date) -> some View {
        HStack(spacing: 12) {
            if let oldest = model.accounts.compactMap(\.reportAt).min() {
                Text("Updated \(age(oldest, now: now))")
            }
            if let lastUsed = model.lastUsed { Text("Links go to Claude \(lastUsed)") }
            Spacer()
            if let footerExtras { footerExtras }
            Button("Quit", action: quit).buttonStyle(.plain)
        }
        .font(.system(size: 10))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }
}

struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10).fill(.white.opacity(configuration.isPressed ? 0.12 : 0.0001))
            )
            .contentShape(Rectangle())
    }
}

struct KeychainBanner: View {
    let problem: UsageError
    let retry: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "key.fill").foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 1) {
                Text("Allow Keychain access to read usage").font(.system(size: 12, weight: .semibold))
                Text(problem.description).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Retry", action: retry).controlSize(.small)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.08)))
        .padding(.bottom, 4)
    }
}

/// One copy: its badge and email, the organization it's working in, and below that any
/// other organization the same login belongs to (a personal Max plan beside a Team, say).
struct CopyRow: View {
    let copy: AccountsModel.Copy
    let now: Date

    var body: some View {
        let style = AccountStyle.of(copy.id)
        HStack(alignment: .top, spacing: 10) {
            Text(copy.id)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .frame(width: 20, height: 20)
                .background(Circle().fill(style.color))
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(copy.active?.email ?? style.label).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    if let label = copy.active?.planLabel {
                        Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    if let status = copy.active?.status(now: now) {
                        Text(status).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                if let active = copy.active {
                    AccountDetail(account: active, color: style.color, now: now)
                } else {
                    Text("Reading…").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                ForEach(copy.others) { OtherAccount(account: $0, color: style.color, now: now) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// An organization the copy isn't working in: switch to it in that Claude to use it.
struct OtherAccount: View {
    let account: AccountsModel.Account
    let color: Color
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(account.planLabel ?? "Other organization").font(.system(size: 11, weight: .semibold))
                Text("not in use").font(.system(size: 10)).foregroundStyle(.tertiary)
                Spacer(minLength: 4)
                if let status = account.status(now: now) {
                    Text(status).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .foregroundStyle(.secondary)
            AccountDetail(account: account, color: color, now: now)
        }
        .padding(.top, 6)
        .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
        .opacity(0.8)
    }
}

/// One organization's bars, or what to say instead of them.
struct AccountDetail: View {
    let account: AccountsModel.Account
    let color: Color
    let now: Date

    var body: some View {
        if let report = account.report {
            VStack(alignment: .leading, spacing: 4) {
                if report.windows.isEmpty {
                    Text("No usage limits on this plan").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                ForEach(report.windows, id: \.label) { WindowRow(window: $0, color: color, now: now) }
            }
            .opacity(account.isStale ? 0.4 : 1)
        }
        if let message = account.message {
            Text(message).font(.system(size: 11)).foregroundStyle(account.report == nil ? .secondary : .primary)
        }
    }
}

struct WindowRow: View {
    let window: UsageWindow
    let color: Color
    let now: Date

    var body: some View {
        let percent = window.percentUsed
        let full = percent >= 100
        HStack(spacing: 8) {
            Text(window.label.replacingOccurrences(of: " · all models", with: ""))
                .frame(width: 92, alignment: .leading)
                .foregroundStyle(.secondary)
            UsageBar(fraction: percent / 100, color: full || percent >= 90 ? AccountStyle.limitRed : color)
            Text("\(Int(percent.rounded()))%")
                .monospacedDigit()
                .frame(width: 36, alignment: .trailing)
                .foregroundStyle(full ? AccountStyle.limitRed : .primary)
            Text(resetText(window, now: now))
                .monospacedDigit()
                .frame(width: 128, alignment: .trailing)
                .foregroundStyle(full ? AccountStyle.limitRed : .secondary)
        }
        .font(.system(size: 11))
        .lineLimit(1)
    }
}

struct UsageBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.12))
                Capsule().fill(color).frame(width: geometry.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 5)
    }
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

func age(_ date: Date, now: Date) -> String {
    let seconds = now.timeIntervalSince(date)
    return seconds < 60 ? "just now" : "\(UsageFormat.duration(seconds)) ago"
}

extension AccountsModel.Account {
    /// "Team · Acme", "Max 20x · Personal".
    var planLabel: String? { PlanName.label(plan: plan, organization: organizationLabel) }

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
