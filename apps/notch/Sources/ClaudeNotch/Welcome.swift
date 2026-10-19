import SwiftUI
import UsageCore

/// What's left to set up, from what the app knows: the Keychain, and each copy signed in
/// or not.
struct WelcomeChecklist: Equatable {
    enum Keychain: Equatable {
        /// A copy's login was read, so the Keychain gave Claude's key.
        case allowed
        /// Not asked yet, or the answer isn't in.
        case waiting
        case refused(UsageError)
    }

    enum Copy: Equatable {
        case signedIn(plan: String?)
        case signedOut
        /// Not read yet, or something else first: what the row would say.
        case other(String)
    }

    let keychain: Keychain
    let copies: [Entry]

    struct Entry: Equatable {
        let letter: String
        let state: Copy
    }

    @MainActor init(_ model: AccountsModel) {
        // A login has an organization only once its token cache was decrypted with the key.
        if let problem = model.keychainProblem {
            keychain = .refused(problem)
        } else if model.accounts.contains(where: { $0.organization != nil }) {
            keychain = .allowed
        } else {
            keychain = .waiting
        }
        copies = model.copies.map { copy in
            guard let account = copy.active else { return Entry(letter: copy.id, state: .other("Reading…")) }
            if account.organization != nil { return Entry(letter: copy.id, state: .signedIn(plan: account.plan)) }
            if account.error == .notSignedIn { return Entry(letter: copy.id, state: .signedOut) }
            return Entry(letter: copy.id, state: .other(account.message ?? "Reading…"))
        }
    }
}

/// The first run's page: how to read the rings and bars, then what's left to set up.
/// It opens by itself; Got it folds it for good.
struct WelcomePage: View {
    let model: AccountsModel
    let preferences: Preferences
    let actions: PanelActions

    var body: some View {
        let checklist = WelcomeChecklist(model)
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Welcome to Claude Notch").font(.system(size: 14, weight: .semibold))
                Text("Each copy's 5-hour and weekly limits, beside the notch, read with that copy's own login, which is never changed.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 10)
            .modifier(Reveal(index: 1))
            PanelSection(title: "How to read it") { Legend() }
                .modifier(Reveal(index: 2))
            PanelSection(title: "Getting set up") {
                keychainRow(checklist.keychain)
                ForEach(checklist.copies, id: \.letter) { copyRow($0) }
                CheckRow(symbol: "command", tint: .secondary, title: "Hotkeys", detail: hotkeys)
            }
            .modifier(Reveal(index: 3))
            HStack {
                Text("It's under the gear later: “Show the welcome page again”.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Got it", action: actions.finishWelcome).buttonStyle(PillButtonStyle(prominent: true))
            }
            .padding(.horizontal, 8)
            .modifier(Reveal(index: 4))
        }
    }

    @ViewBuilder private func keychainRow(_ keychain: WelcomeChecklist.Keychain) -> some View {
        switch keychain {
        case .allowed:
            CheckRow(symbol: "checkmark.circle.fill", tint: AccountStyle.backGreen, title: "Keychain access allowed")
        case .waiting:
            CheckRow(
                symbol: "key.fill", tint: .yellow, title: "Allow Keychain access when macOS asks",
                detail: "Each copy's login is locked with Claude's own key. Choose Always Allow, once."
            )
        case .refused(let problem):
            CheckRow(
                symbol: "xmark.circle.fill", tint: AccountStyle.limitRed, title: "Keychain access refused",
                detail: problem == .keychainItemMissing ? problem.description : "Retry, then choose Always Allow when macOS asks."
            ) {
                Button("Retry", action: model.retryKeychain).buttonStyle(PillButtonStyle())
            }
        }
    }

    @ViewBuilder private func copyRow(_ entry: WelcomeChecklist.Entry) -> some View {
        let style = AccountStyle.of(entry.letter)
        switch entry.state {
        case .signedIn(let plan):
            CheckRow(
                symbol: "checkmark.circle.fill", tint: AccountStyle.backGreen, title: style.safeLabel,
                detail: plan.map { "Signed in · \($0)" } ?? "Signed in", badge: (entry.letter, style.color)
            )
        case .signedOut:
            CheckRow(
                symbol: "circle.dashed", tint: .secondary, title: style.safeLabel, detail: "Not signed in",
                badge: (entry.letter, style.color)
            ) {
                Button("Sign in") { actions.open(entry.letter) }.buttonStyle(PillButtonStyle())
            }
        case .other(let message):
            CheckRow(symbol: "circle.dashed", tint: .secondary, title: style.safeLabel, detail: message, badge: (entry.letter, style.color))
        }
    }

    /// "⌥⌘1 Claude A · ⌥⌘2 Claude B · ⌥⌘0 the most room".
    private var hotkeys: String {
        let plan = HotkeyPlan.bindings(AccountStyle.styles, mostRoom: preferences.mostRoomHotkey)
        guard !plan.isEmpty else { return "None set; add them in profiles.json." }
        return plan.map { binding in
            switch binding.target {
            case .copy(let letter): "⌥⌘\(binding.key) \(AccountStyle.of(letter).safeLabel)"
            case .mostRoom: "⌥⌘\(binding.key) the most room"
            }
        }
        .joined(separator: " · ")
    }
}

/// One line of the checklist: done or not, what, and a button when there's something to do.
private struct CheckRow<Trailing: View>: View {
    let symbol: String
    let tint: Color
    let title: String
    var detail: String?
    var badge: (letter: String, color: Color)?
    @ViewBuilder let trailing: Trailing

    init(
        symbol: String, tint: Color, title: String, detail: String? = nil, badge: (letter: String, color: Color)? = nil,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.symbol = symbol
        self.tint = tint
        self.title = title
        self.detail = detail
        self.badge = badge
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 16)
            if let badge { Badge(letter: badge.letter, color: badge.color, size: 18) }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                if let detail {
                    Text(detail)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
