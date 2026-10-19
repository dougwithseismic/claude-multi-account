import Foundation
import UsageCore

extension AccountsModel {
    /// What's shared with `claude-usage --cached` and the status line: for each copy, the
    /// organization it's working in, with its profile's name and colour. The plan's name
    /// ("Team"), never the organization's, and never an email or a token.
    func sharedSnapshot(updatedAt: Date, styles: [ProfileStyle]? = nil) -> SharedSnapshot {
        let styles = styles ?? AccountStyle.styles
        return SharedSnapshot(updatedAt: updatedAt, copies: copies.map { copy in
            let style = ProfileStyle.of(copy.id, in: styles)
            let account = copy.active
            return SharedSnapshot.Copy(
                letter: copy.id, label: style.label, color: style.color, plan: account?.plan,
                inFront: lastUsed == copy.id,
                state: account.map { SharedSnapshot.State(error: $0.error, report: $0.report) } ?? .unavailable,
                readAt: account?.reportAt,
                windows: account?.report?.windows.map(SharedSnapshot.Window.init) ?? []
            )
        })
    }

    /// Each copy's organization in use, as `BestCopy` takes them.
    var candidates: [BestCopy.Candidate] {
        copies.map { BestCopy.Candidate(letter: $0.id, report: $0.active?.report, readAt: $0.active?.reportAt) }
    }

    /// The copy with the most room, from what was last read: what ⌥⌘0 switches to.
    func mostRoom(now: Date = Date()) -> BestCopy.Choice { BestCopy.choose(candidates, now: now) }
}
