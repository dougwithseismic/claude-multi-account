import SwiftUI
import UsageCore

/// The peek's window: the notch widening and dropping a line for a few seconds. It never
/// takes clicks, so it can't get in the way of a tab or a title bar under it.
struct PeekStage: View {
    let model: AccountsModel
    let state: NotchState

    var body: some View {
        let shown = state.peekShown
        let rect = shown ? CGRect(origin: .zero, size: state.peekSize) : state.notchInPeek
        let radius: CGFloat = shown ? 16 : 10
        ZStack(alignment: .bottom) {
            if let peek = state.peek {
                PeekLine(peek: peek, model: model)
                    .frame(height: NotchLayout.peekLine)
                    .id(peek.id)
                    .transition(.blurReplace)
            }
        }
        .frame(width: state.peekSize.width, height: state.peekSize.height, alignment: .bottom)
        .opacity(shown ? 1 : 0)
        .animation(shown ? .smooth(duration: 0.25).delay(0.1) : .easeIn(duration: 0.08), value: shown)
        .mask { MorphShape(rect: rect, radius: radius) }
        .background {
            MorphShape(rect: rect, radius: radius)
                .fill(.black)
                .shadow(color: .black.opacity(shown ? 0.4 : 0), radius: 12, y: 6)
        }
        .padding(.horizontal, NotchLayout.margin)
        .padding(.bottom, NotchLayout.margin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.colorScheme, .dark)
    }
}

/// One line: which copy, and what happened. Names the profile, never the login's email.
struct PeekLine: View {
    let peek: Peek
    let model: AccountsModel
    var now = Date()

    var body: some View {
        let style = AccountStyle.of(peek.letter)
        HStack(spacing: 8) {
            Badge(letter: peek.letter, color: style.color, size: 17)
            Text(title(style)).font(.system(size: 12, weight: .semibold)).lineLimit(1)
            Spacer(minLength: 6)
            trailing(style)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 3)
    }

    private var account: AccountsModel.Account? { model.copies.first { $0.id == peek.letter }?.active }

    private func title(_ style: AccountStyle) -> String {
        switch peek.kind {
        case .switched: style.safeLabel
        case .alert(.near(let window)): "\(style.safeLabel) · \(window.label) at \(Int(window.percentUsed.rounded()))%"
        case .alert(.out(let window)): "\(style.safeLabel) · \(shortLabel(window)) used up"
        case .alert(.back(let window)): "\(style.safeLabel) · \(shortLabel(window)) reset"
        }
    }

    @ViewBuilder private func trailing(_ style: AccountStyle) -> some View {
        switch peek.kind {
        case .switched:
            if let report = account?.report {
                HStack(spacing: 7) {
                    if let fiveHour = report.fiveHour { Figure(label: "5h", percent: fiveHour.percentUsed) }
                    if let weekly = report.weeklyPeak { Figure(label: "week", percent: weekly.percentUsed) }
                    RingView(letter: peek.letter, account: account)
                }
            } else if let plan = account?.plan {
                Text(plan).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        case .alert(.near(let window)):
            Label(resetText(window, now: now), systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 11)).foregroundStyle(.orange)
        case .alert(.out(let window)):
            Label(resetText(window, now: now), systemImage: "xmark.octagon.fill")
                .font(.system(size: 11)).foregroundStyle(AccountStyle.limitRed)
        case .alert(.back):
            Label("ready again", systemImage: "checkmark.circle.fill")
                .font(.system(size: 11, weight: .medium)).foregroundStyle(AccountStyle.backGreen)
        }
    }
}

private struct Figure: View {
    let label: String
    let percent: Double

    var body: some View {
        HStack(spacing: 3) {
            Text(label).foregroundStyle(.secondary)
            Text("\(Int(percent.rounded()))%")
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(percent >= 90 ? AccountStyle.limitRed : .primary)
        }
        .font(.system(size: 11, design: .rounded))
    }
}
