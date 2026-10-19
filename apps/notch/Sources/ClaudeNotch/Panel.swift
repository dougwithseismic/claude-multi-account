import SwiftUI
import UsageCore

/// What the panel's buttons do; the controller and the app fill these in.
struct PanelActions {
    var open: (String) -> Void = { _ in }
    var refresh: () -> Void = {}
    var editProfiles: () -> Void = {}
    var reloadProfiles: () -> Void = {}
    var quit: () -> Void = {}
    /// The welcome page's Got it.
    var finishWelcome: () -> Void = {}
    /// Settings' "Show the welcome page again".
    var showWelcome: () -> Void = {}
}

// MARK: - The window's content

/// The open panel inside its black shape. The shape grows out of the notch (or the peek
/// showing) on a spring and folds back into it; the rows slide in after it, one by one.
/// The content always has its open size, so the window can be sized before it moves.
struct PanelStage: View {
    let model: AccountsModel
    let state: NotchState
    let preferences: Preferences
    let actions: PanelActions

    var body: some View {
        let open = state.isOpen
        let radius: CGFloat = open ? 22 : state.openedFromPeek ? 16 : 10
        PanelContent(model: model, state: state, preferences: preferences, actions: actions)
            .environment(\.revealed, open)
            .allowsHitTesting(open)
            .onGeometryChange(for: CGSize.self, of: \.size) { size in state.onResize?(size) }
            .mask { GeometryReader { MorphShape(rect: shape(in: $0.size), radius: radius) } }
            .background {
                GeometryReader { geometry in
                    MorphShape(rect: shape(in: geometry.size), radius: radius)
                        .fill(.black)
                        .shadow(color: .black.opacity(open ? 0.5 : 0), radius: 18, y: 10)
                }
            }
            .padding(.horizontal, NotchLayout.margin)
            .padding(.bottom, NotchLayout.margin)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .environment(\.colorScheme, .dark)
    }

    private func shape(in size: CGSize) -> CGRect {
        if state.isOpen { return CGRect(origin: .zero, size: size) }
        return state.openedFromPeek ? state.peekInPanel : state.notchInPanel
    }
}

struct PanelContent: View {
    static let width: CGFloat = 460

    let model: AccountsModel
    let state: NotchState
    let preferences: Preferences
    let actions: PanelActions

    var body: some View {
        TimelineView(.periodic(from: .now, by: 20)) { context in
            VStack(alignment: .leading, spacing: 0) {
                TopBar(model: model, state: state, preferences: preferences, actions: actions)
                    .frame(width: max(state.notchInPanel.minX, 0), height: state.notchInPanel.height, alignment: .leading)
                    .modifier(Reveal(index: 0))
                ZStack(alignment: .top) {
                    switch state.page {
                    case .usage:
                        UsagePage(model: model, state: state, preferences: preferences, actions: actions, now: context.date)
                            .transition(.blurReplace)
                    case .settings:
                        SettingsPage(preferences: preferences, actions: actions)
                            .transition(.blurReplace)
                    case .welcome:
                        WelcomePage(model: model, preferences: preferences, actions: actions)
                            .transition(.blurReplace)
                    }
                }
                .padding(.horizontal, NotchLayout.flare + 10)
                .padding(.top, 6)
                .padding(.bottom, 12)
            }
            .frame(width: Self.width, alignment: .leading)
        }
    }
}

/// Buttons in the strip left of the notch, which would otherwise be empty black.
struct TopBar: View {
    let model: AccountsModel
    let state: NotchState
    let preferences: Preferences
    let actions: PanelActions

    var body: some View {
        let details = state.showsDetails(preferences)
        HStack(spacing: 2) {
            IconButton(symbol: state.page == .settings ? "chevron.backward" : "gearshape.fill", active: state.page == .settings) {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                    state.page = state.page == .settings ? .usage : .settings
                }
            }
            IconButton(symbol: details ? "eye.fill" : "eye.slash.fill", active: details) {
                withAnimation(.smooth(duration: 0.25)) { preferences.showDetails.toggle() }
            }
            IconButton(symbol: "arrow.clockwise", spinning: model.polling, action: actions.refresh)
            Spacer(minLength: 0)
        }
        .padding(.leading, NotchLayout.flare + 10)
    }
}

struct IconButton: View {
    let symbol: String
    var active = false
    var spinning = false
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11.5, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.rotate, options: .repeating, isActive: spinning)
                .foregroundStyle(.white.opacity(active || hovered ? 0.95 : 0.5))
                .frame(width: 28, height: 22)
                .background(Capsule().fill(.white.opacity(hovered ? 0.14 : active ? 0.08 : 0)))
                .contentShape(Capsule())
        }
        .buttonStyle(PressStyle())
        .onHover { hovered = $0 }
        .animation(.smooth(duration: 0.15), value: hovered)
    }
}

// MARK: - Usage

struct UsagePage: View {
    let model: AccountsModel
    let state: NotchState
    let preferences: Preferences
    let actions: PanelActions
    let now: Date

    var body: some View {
        let details = state.showsDetails(preferences)
        VStack(alignment: .leading, spacing: 6) {
            if let problem = model.keychainProblem {
                KeychainBanner(problem: problem, retry: model.retryKeychain).modifier(Reveal(index: 1))
            }
            if model.profiles.isEmpty {
                Text("No Claude profiles in ~/Library/Application Support")
                    .font(.system(size: 12)).foregroundStyle(.secondary).padding(10)
            }
            ForEach(Array(model.copies.enumerated()), id: \.element.id) { index, copy in
                Button { actions.open(copy.id) } label: {
                    CopyRow(copy: copy, now: now, isCurrent: model.lastUsed == copy.id, showsDetails: details, index: index + 1)
                }
                .buttonStyle(RowButtonStyle())
                .modifier(Reveal(index: index + 1))
            }
            Footer(model: model, state: state, preferences: preferences, now: now)
                .modifier(Reveal(index: model.copies.count + 1))
        }
    }
}

struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { Row(configuration: configuration) }

    private struct Row: View {
        let configuration: Configuration
        @State private var hovered = false

        var body: some View {
            configuration.label
                .environment(\.rowHovered, hovered)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white.opacity(configuration.isPressed ? 0.12 : hovered ? 0.075 : 0.035))
                )
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .scaleEffect(configuration.isPressed ? 0.985 : 1)
                .onHover { hovered = $0 }
                .animation(.smooth(duration: 0.15), value: hovered)
                .animation(.smooth(duration: 0.1), value: configuration.isPressed)
        }
    }
}

/// Shrinks a little while pressed.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.smooth(duration: 0.1), value: configuration.isPressed)
    }
}

/// A small capsule button: Retry, Edit, Quit. `prominent`, in the accent colour: Got it.
struct PillButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View { Pill(configuration: configuration, prominent: prominent) }

    private struct Pill: View {
        let configuration: Configuration
        let prominent: Bool
        @State private var hovered = false

        var body: some View {
            configuration.label
                .font(.system(size: 11, weight: prominent ? .semibold : .medium))
                .foregroundStyle(prominent ? .black : .primary)
                .padding(.horizontal, prominent ? 14 : 10)
                .frame(height: 22)
                .background(Capsule().fill(fill))
                .contentShape(Capsule())
                .onHover { hovered = $0 }
                .animation(.smooth(duration: 0.12), value: hovered)
        }

        private var fill: AnyShapeStyle {
            if prominent {
                return AnyShapeStyle(AccountStyle.accent.opacity(configuration.isPressed ? 0.75 : hovered ? 0.9 : 1))
            }
            return AnyShapeStyle(.white.opacity(configuration.isPressed ? 0.24 : hovered ? 0.17 : 0.1))
        }
    }
}

struct KeychainBanner: View {
    let problem: UsageError
    let retry: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "key.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 22, height: 22)
                .background(Circle().fill(.yellow.gradient))
            VStack(alignment: .leading, spacing: 1) {
                Text("Allow Keychain access to read usage").font(.system(size: 12, weight: .semibold))
                Text(problem.description).font(.system(size: 10.5)).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 8)
            Button("Retry", action: retry).buttonStyle(PillButtonStyle())
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.yellow.opacity(0.1)))
    }
}

/// One copy: its badge and name, the organization it's working in, and below that any
/// other organization the same login belongs to (a personal Max plan beside a Team, say).
/// The name is the profile's unless details show, when it's the login's email.
struct CopyRow: View {
    let copy: AccountsModel.Copy
    let now: Date
    let isCurrent: Bool
    let showsDetails: Bool
    /// Its place in the panel, for when its bars fill.
    let index: Int
    @Environment(\.rowHovered) private var hovered

    var body: some View {
        let style = AccountStyle.of(copy.id)
        let delay = Reveal.delay(index) + 0.08
        HStack(alignment: .top, spacing: 10) {
            Badge(letter: copy.id, color: style.color)
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text(showsDetails ? copy.active?.email ?? style.label : style.safeLabel)
                        .font(.system(size: 12.5, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .contentTransition(.opacity)
                    if let plan = copy.active?.planText(showsDetails: showsDetails) { Tag(text: plan) }
                    if isCurrent { Tag(text: "current", color: style.color) }
                    Spacer(minLength: 4)
                    if let status = copy.active?.status(now: now) {
                        Text(status).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    if hovered {
                        HStack(spacing: 4) {
                            if let key = style.hotkey { KeyHint(text: "⌥⌘\(key)") }
                            Image(systemName: "arrow.up.forward").font(.system(size: 9.5, weight: .bold)).foregroundStyle(.secondary)
                        }
                        .transition(.opacity.combined(with: .offset(x: 6)))
                    }
                }
                .frame(minHeight: 22)
                .animation(.smooth(duration: 0.15), value: hovered)
                if let active = copy.active {
                    AccountDetail(account: active, color: style.color, now: now, delay: delay)
                } else {
                    Text("Reading…").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                ForEach(copy.others) {
                    OtherAccount(account: $0, color: style.color, now: now, showsDetails: showsDetails, delay: delay + 0.1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Tag: View {
    let text: String
    var color: Color?

    var body: some View {
        Text(text)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(color ?? .white.opacity(0.6))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill((color ?? .white).opacity(color == nil ? 0.08 : 0.16)))
            .lineLimit(1)
            .contentTransition(.opacity)
    }
}

struct KeyHint: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(RoundedRectangle(cornerRadius: 4).strokeBorder(.white.opacity(0.25), lineWidth: 0.8))
    }
}

/// An organization the copy isn't working in: switch to it in that Claude to use it.
struct OtherAccount: View {
    let account: AccountsModel.Account
    let color: Color
    let now: Date
    let showsDetails: Bool
    let delay: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(account.planText(showsDetails: showsDetails) ?? "Other organization")
                    .font(.system(size: 11, weight: .semibold))
                    .contentTransition(.opacity)
                Text("not in use").font(.system(size: 10)).foregroundStyle(.tertiary)
                Spacer(minLength: 4)
                if let status = account.status(now: now) {
                    Text(status).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .foregroundStyle(.secondary)
            AccountDetail(account: account, color: color, now: now, delay: delay)
        }
        .padding(.top, 7)
        .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.07)).frame(height: 1) }
        .opacity(0.8)
    }
}

/// One organization's bars, or what to say instead of them.
struct AccountDetail: View {
    let account: AccountsModel.Account
    let color: Color
    let now: Date
    var delay: Double = 0

    var body: some View {
        if let report = account.report {
            VStack(alignment: .leading, spacing: 5) {
                if report.windows.isEmpty {
                    Text("No usage limits on this plan").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                ForEach(Array(report.windows.enumerated()), id: \.element.label) { index, window in
                    // Old numbers would understate the pace: no projection from them.
                    WindowRow(
                        window: window, color: color, now: now, delay: delay + 0.03 * Double(index),
                        projects: !account.isStale
                    )
                }
            }
            .opacity(account.isStale ? 0.4 : 1)
        }
        if let message = account.message {
            Text(message).font(.system(size: 11)).foregroundStyle(account.report == nil ? .secondary : .primary)
        }
    }
}

/// A window's bar, how much is used, and its reset as a countdown, or by the clock while
/// the row is hovered. At 100% the bar drains with the wait instead. Going fast enough to
/// run out before the reset, it says when instead, in orange; hovered, it's the reset again.
struct WindowRow: View {
    static let resetWidth: CGFloat = 140

    let window: UsageWindow
    let color: Color
    let now: Date
    var delay: Double = 0
    /// Projects from the current pace; off for numbers too old to say much about it.
    var projects = true
    @Environment(\.rowHovered) private var hovered

    var body: some View {
        let percent = window.percentUsed
        let full = percent >= 100
        let wait = waitFraction(window, now: now)
        let out = projects && !hovered ? PaceProjection.runsOut(window, now: now) : nil
        HStack(spacing: 8) {
            Text(shortLabel(window))
                .frame(width: 84, alignment: .leading)
                .foregroundStyle(.secondary)
            UsageBar(
                fraction: wait ?? percent / 100, color: percent >= 90 ? AccountStyle.limitRed : color,
                waiting: wait != nil, pace: full ? nil : elapsedFraction(window, now: now), delay: delay
            )
            Text("\(Int(percent.rounded()))%")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: percent))
                .frame(width: 36, alignment: .trailing)
                .foregroundStyle(full ? AccountStyle.limitRed : .primary)
            Group {
                if let out {
                    Text(paceText(out, now: now))
                        .monospacedDigit()
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(.orange)
                        .transition(.opacity)
                } else {
                    Countdown(target: window.resetsAt, now: now) { date in
                        let text = resetText(window, now: date, clock: hovered)
                        Text(text)
                            .monospacedDigit()
                            // "resets tomorrow 9:00 AM" shrinks a little rather than losing its end.
                            .minimumScaleFactor(0.85)
                            .contentTransition(.numericText(countsDown: true))
                            .animation(.smooth(duration: 0.2), value: text)
                    }
                    .transition(.opacity)
                }
            }
            .frame(width: Self.resetWidth, alignment: .trailing)
            .foregroundStyle(full ? AccountStyle.limitRed : .secondary)
            .animation(.smooth(duration: 0.15), value: out == nil)
        }
        .font(.system(size: 11))
        .lineLimit(1)
    }
}

/// How much of a window is used, filling from empty as the panel opens. The tick marks
/// how far through the window it is: a bar past its tick is going faster than an even pace.
/// `waiting`, it's the wait left at 100% instead, drawn fainter.
struct UsageBar: View {
    let fraction: Double
    let color: Color
    var waiting = false
    var pace: Double?
    var delay: Double = 0
    @Environment(\.revealed) private var revealed

    var body: some View {
        let shown = revealed ? min(max(fraction, 0), 1) : 0
        GeometryReader { geometry in
            let width = geometry.size.width, height = geometry.size.height
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.1))
                Capsule()
                    .fill(LinearGradient(
                        colors: waiting ? [color.opacity(0.3), color.opacity(0.6)] : [color.opacity(0.7), color],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: shown > 0 ? max(width * shown, height) : 0)
                if let pace {
                    Capsule()
                        .fill(.white.opacity(0.75))
                        .frame(width: 2, height: height + 5)
                        .offset(x: width * pace - 1)
                        .opacity(revealed ? 1 : 0)
                }
            }
        }
        .frame(height: 6)
        .animation(
            revealed ? .spring(response: 0.65, dampingFraction: 0.86).delay(delay) : .easeIn(duration: 0.08),
            value: shown
        )
    }
}

struct Footer: View {
    let model: AccountsModel
    let state: NotchState
    let preferences: Preferences
    let now: Date

    var body: some View {
        // Rows that failed show their own age; this is the age of the rest.
        let fresh = model.accounts.filter { $0.error == nil }.compactMap(\.reportAt).min()
        let updated = state.isDemo
            ? "Demo · made-up accounts, nothing is read"
            : (fresh ?? model.accounts.compactMap(\.reportAt).max()).map { "Updated \(age($0, now: now))" }
        let links = state.isDemo ? nil : model.lastUsed.map { "Links go to \(AccountStyle.of($0).safeLabel)" }
        let room = mostRoom
        // Short of room, the links go first (the row says "current"), then the ⌥ hint.
        ViewThatFits(in: .horizontal) {
            line([updated, links, room], hint: true)
            line([updated, room], hint: true)
            line([updated, room], hint: false)
            line([room ?? updated], hint: false)
        }
        .font(.system(size: 10))
        .foregroundStyle(.tertiary)
        .lineLimit(1)
        .padding(.horizontal, 8)
        .padding(.top, 3)
        .contentTransition(.opacity)
    }

    /// "Most room: Claude C", when there's more than one copy to choose from.
    private var mostRoom: String? {
        guard model.copies.count > 1, case .copy(let letter) = model.mostRoom(now: now) else { return nil }
        return "Most room: \(AccountStyle.of(letter).safeLabel)"
    }

    private func line(_ parts: [String?], hint: Bool) -> some View {
        HStack(spacing: 5) {
            Text(parts.compactMap(\.self).joined(separator: " · "))
            Spacer(minLength: 8)
            if hint {
                if state.revealHeld, !preferences.showDetails {
                    Label("Showing details", systemImage: "eye.fill")
                } else if !preferences.showDetails {
                    Text("Hold ⌥ to show emails")
                }
            }
        }
    }
}
