import AppKit
import SwiftUI
import UsageCore

/// `--snapshot <file.png>`: once every account has been read (or after 30 seconds),
/// renders the notch in each of its states with the live numbers to a PNG and quits: the
/// rings (and every copy out), four peeks, the open panel and its settings page, and with
/// `--welcome` the welcome page. For checking the rows without screen-recording permission.
/// With `--demo` it also shows the panel with details, as holding ⌥ does; the live
/// numbers' emails stay out of the file.
@MainActor
enum Snapshot {
    nonisolated static func path(in arguments: [String]) -> String? {
        guard let i = arguments.firstIndex(of: "--snapshot"), i + 1 < arguments.count else { return nil }
        return arguments[i + 1]
    }

    static func write(
        _ model: AccountsModel, preferences: Preferences, to path: String, hasNotch: Bool = true,
        showDetails: Bool = false, welcome: Bool = false, deadline: Date = Date().addingTimeInterval(30)
    ) {
        guard model.isSettled || Date() > deadline else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                write(
                    model, preferences: preferences, to: path, hasNotch: hasNotch, showDetails: showDetails,
                    welcome: welcome, deadline: deadline
                )
            }
            return
        }
        let renderer = ImageRenderer(content: Board(
            model: model, preferences: preferences, hasNotch: hasNotch, showDetails: showDetails, welcome: welcome
        ))
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
        else {
            FileHandle.standardError.write(Data("ClaudeNotch: couldn't render the snapshot\n".utf8))
            exit(1)
        }
        do { try png.write(to: URL(filePath: path)) } catch {
            FileHandle.standardError.write(Data("ClaudeNotch: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
        exit(0)
    }
}

/// Every state side by side, laid out as on a 14-inch MacBook Pro (or a screen without a
/// notch), each hanging from its own strip of menu bar.
private struct Board: View {
    let model: AccountsModel
    let preferences: Preferences
    let hasNotch: Bool
    let showDetails: Bool
    var welcome = false

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            VStack(alignment: .leading, spacing: 28) {
                tile("Closed") { closed(model) }
                tile("Closed, every copy out") { closed(allOut) }
                if let letter = model.lastUsed ?? model.copies.first?.id {
                    tile("Peek after a ⌥⌘ switch") { peek(Peek(letter: letter, kind: .switched)) }
                }
                if let letter = model.copies.first?.id {
                    tile("Peek near a limit") { peek(Peek(letter: letter, kind: .alert(.near(Self.nearWindow)))) }
                    tile("Peek at a limit") { peek(Peek(letter: letter, kind: .alert(.out(Self.outWindow)))) }
                }
                if case .noRoom(let back) = allOut.mostRoom() {
                    tile("Peek after ⌥⌘0, every copy out") { peek(Peek(letter: back?.letter ?? "", kind: .noRoom(back))) }
                }
                tile("Open") { panel(state()) }
            }
            if showDetails {
                tile("Holding ⌥: emails and team names") { panel(state(revealHeld: true)) }
            }
            tile("Settings") { panel(state(page: .settings)) }
            if welcome {
                tile("Welcome, on the first run") { panel(state(page: .welcome)) }
            }
        }
        .padding(32)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x1F2A44), Color(hex: 0x4B3B63), Color(hex: 0x8A5A6A)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .environment(\.colorScheme, .dark)
    }

    private var layout: NotchLayout { NotchLayout.make(hasNotch ? Self.macBook : Self.display, ringCount: model.profiles.count) }
    /// Where the panel would sit; only its left edge matters here.
    private var panelRect: CGRect { layout.panelFrame(contentSize: CGSize(width: PanelContent.width, height: 100)) }

    private func tile<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
            content()
                .background(alignment: .top) {
                    // The menu bar the notch hangs from.
                    Rectangle().fill(.white.opacity(0.12)).frame(height: layout.notch.height)
                }
        }
    }

    private func state(page: NotchState.Page = .usage, revealHeld: Bool = false) -> NotchState {
        let state = NotchState()
        state.isOpen = true
        state.page = page
        state.revealHeld = revealHeld
        state.notchInPanel = NotchLayout.local(layout.notch, in: panelRect)
        state.peekInPanel = NotchLayout.local(layout.peek, in: panelRect)
        return state
    }

    private func rings(_ model: AccountsModel, state: NotchState? = nil) -> some View {
        RingsView(model: model, hasNotch: layout.hasNotch, state: state)
            .frame(width: layout.ringsWindow.width, height: layout.ringsWindow.height)
    }

    private func closed(_ model: AccountsModel) -> some View {
        let notch = NotchLayout.local(layout.notch, in: panelRect), ringsAt = NotchLayout.local(layout.rings, in: panelRect)
        return ZStack(alignment: .topLeading) {
            if layout.hasNotch {
                NotchShape(flare: 0, bottomRadius: 9).fill(.black).frame(width: notch.width, height: notch.height).offset(x: notch.minX)
            }
            rings(model).offset(x: ringsAt.minX)
        }
        .frame(width: PanelContent.width, height: notch.height, alignment: .topLeading)
        .padding(.horizontal, NotchLayout.margin)
    }

    private func peek(_ peek: Peek) -> some View {
        let state = NotchState()
        state.peek = peek
        state.peekShown = true
        state.peekSize = layout.peek.size
        state.notchInPeek = NotchLayout.local(layout.notch, in: layout.peek)
        let ringsAt = NotchLayout.local(layout.rings, in: layout.peek)
        return PeekStage(model: model, state: state)
            .frame(width: layout.peek.width + 2 * NotchLayout.margin, height: layout.peek.height + NotchLayout.margin)
            .overlay(alignment: .topLeading) { rings(model, state: state).offset(x: NotchLayout.margin + ringsAt.minX) }
    }

    private func panel(_ state: NotchState) -> some View {
        let ringsAt = NotchLayout.local(layout.rings, in: panelRect)
        return PanelStage(model: model, state: state, preferences: preferences, actions: PanelActions())
            .fixedSize()
            .overlay(alignment: .topLeading) { rings(model, state: state).offset(x: NotchLayout.margin + ringsAt.minX) }
    }

    /// The live copies, every one out of its 5-hour window and back one after another,
    /// the first in its last minutes.
    private var allOut: AccountsModel {
        let now = Date()
        let backIn: [TimeInterval] = [2 * 3600 + 41 * 60, 4 * 60 + 12, 3600 + 30 * 60]
        let accounts = model.profiles.enumerated().map { index, profile in
            var account = AccountsModel.Account(profile: profile, organization: "out")
            account.report = UsageReport(windows: [
                UsageWindow(label: "5-hour", percentUsed: 100, resetsAt: now.addingTimeInterval(backIn[index % backIn.count] + Double(index / backIn.count) * 600)),
                UsageWindow(label: "Weekly · all models", percentUsed: 48, resetsAt: now.addingTimeInterval(3 * 86400)),
            ], extraUsage: nil)
            return account
        }
        let out = AccountsModel(reader: nil)
        out.show(profiles: model.profiles, accounts: accounts)
        out.lastUsed = model.lastUsed
        return out
    }

    static let nearWindow = UsageWindow(label: "5-hour", percentUsed: 91, resetsAt: Date().addingTimeInterval(48 * 60))
    static let outWindow = UsageWindow(label: "5-hour", percentUsed: 100, resetsAt: Date().addingTimeInterval(2 * 3600 + 41 * 60))

    /// A 14-inch MacBook Pro: 1512×982 points, a 38pt notch.
    static let macBook = ScreenShape(
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 38,
        auxiliaryTopLeft: CGRect(x: 0, y: 944, width: 664, height: 38),
        auxiliaryTopRight: CGRect(x: 849, y: 944, width: 663, height: 38)
    )
    static let display = ScreenShape(
        frame: CGRect(x: 0, y: 0, width: 2560, height: 1440), safeAreaTop: 0, auxiliaryTopLeft: nil, auxiliaryTopRight: nil
    )
}
