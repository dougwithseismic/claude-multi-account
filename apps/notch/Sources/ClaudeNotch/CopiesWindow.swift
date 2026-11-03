import AppKit
import SwiftUI
import UsageCore

/// The Copies window: each copy's name, colour and ⌥⌘ key, and adding and removing copies.
/// A window of its own, as typing needs a key window and the notch's panel never is one.
@MainActor
final class CopiesWindow {
    private let window: NSWindow

    init(editor: CopiesEditor) {
        let hosting = NSHostingController(rootView: CopiesView(editor: editor))
        hosting.sizingOptions = [.preferredContentSize]
        window = NSWindow(contentViewController: hosting)
        window.title = "Copies"
        window.styleMask = [.titled, .closable, .resizable]
        window.isReleasedWhenClosed = false
        window.center()
    }

    /// Brings the window forward; with no Dock icon, the app has to activate itself first.
    /// Nothing starts focused, so a key pressed by chance doesn't rename Claude A.
    func show() {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(nil)
    }
}

/// What the Copies window shows and does: profiles.json's copies, how each one is doing,
/// and making and removing them with claude-copy.sh, as install.sh does.
@MainActor @Observable
final class CopiesEditor {
    enum Status: Equatable {
        /// Listed, with no launcher: added by hand, or install.sh hasn't run since.
        case notMade
        /// A launcher, but no data folder until it's opened.
        case notOpened
        case signedOut
        case reading
        case signedIn(plan: String?)
        case problem(String)
    }

    let file: ProfilesFile
    let model: AccountsModel
    /// Brings a copy to the front, or starts it.
    let open: (String) -> Void
    /// What's being done ("Making Claude F…"); the buttons that change copies wait for it.
    private(set) var working: String?
    /// What went wrong last.
    private(set) var failure: String?

    init(file: ProfilesFile, model: AccountsModel, open: @escaping (String) -> Void) {
        self.file = file
        self.model = model
        self.open = open
    }

    var styles: [ProfileStyle] { file.styles }
    /// The copy Add would make.
    var next: ProfileStyle? { ProfileStyle.next(after: file.styles) }

    func status(of letter: String) -> Status {
        guard let copy = model.copies.first(where: { $0.id == letter }) else {
            return Launcher.exists(letter) ? .notOpened : .notMade
        }
        guard let account = copy.active else { return .reading }
        switch account.error {
        case .notSignedIn?: return .signedOut
        case nil: return account.lastAttempt == nil ? .reading : .signedIn(plan: account.plan)
        case let error?: return account.report == nil ? .problem(error.description) : .signedIn(plan: account.plan)
        }
    }

    /// The keys `letter` can have: those no other copy has.
    func keys(for letter: String) -> [String] {
        let taken = Set(file.styles.filter { $0.letter != letter }.compactMap(\.hotkey))
        return ProfileStyle.keys.filter { !taken.contains($0) }
    }

    func update(_ letter: String, _ change: (inout ProfileStyle) -> Void) {
        do { try file.update(letter, change) } catch { failure = "Couldn't save profiles.json: \(error.localizedDescription)" }
    }

    /// Makes the next copy's data folder and launcher, then lists it in profiles.json, which
    /// puts its ring by the notch.
    func add() async {
        guard let new = next else { return }
        await work("Making Claude \(new.letter)…") {
            try await CopyScript.make(new.letter)
            try self.file.write(self.file.styles + [new])
        }
    }

    /// Makes the data folder and launcher of a copy profiles.json lists without them.
    func make(_ letter: String) async {
        await work("Making Claude \(letter)…") {
            try await CopyScript.make(letter)
            self.model.discover()
        }
    }

    /// Removes a copy's launcher and takes it out of profiles.json; with `data`, deletes its
    /// data folder too, which signs it out.
    func remove(_ letter: String, data: Bool) async {
        await work("Removing Claude \(letter)…") {
            try await CopyScript.remove(letter, data: data)
            try self.file.write(self.file.styles.filter { $0.letter != letter })
        }
    }

    private func work(_ what: String, _ job: () async throws -> Void) async {
        guard working == nil else { return }
        working = what
        failure = nil
        defer { working = nil }
        do { try await job() } catch { failure = error.localizedDescription }
    }
}

struct CopiesView: View {
    let editor: CopiesEditor

    var body: some View {
        Form {
            Section {
                ForEach(editor.styles, id: \.letter) { style in
                    CopyEditorRow(style: style, editor: editor)
                }
            } footer: {
                Text("Each copy is its own Claude app with its own login, and uses about 0.5–1 GB of memory while it's open. The list is ~/.config/claude-multi-account/profiles.json, which also applies when it's saved by hand.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .frame(width: 620)
        .frame(minHeight: 300, idealHeight: 480)
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            if let working = editor.working {
                ProgressView().controlSize(.small)
                Text(working).foregroundStyle(.secondary)
            } else if let failure = editor.failure {
                Label(failure, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .lineLimit(3)
            }
            Spacer(minLength: 12)
            Button {
                Task { await editor.add() }
            } label: {
                Label(editor.next.map { "Add Claude \($0.letter)" } ?? "Every letter is used", systemImage: "plus")
            }
            .disabled(editor.next == nil || editor.working != nil)
        }
        .font(.callout)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }
}

/// One copy: its badge, name and how it's doing; Make, Sign in or Open; its colour and key;
/// and removing it. Typing and the colour are saved once they settle.
private struct CopyEditorRow: View {
    let style: ProfileStyle
    let editor: CopiesEditor
    @State private var label: String
    @State private var hex: String
    @State private var removing = false

    init(style: ProfileStyle, editor: CopiesEditor) {
        self.style = style
        self.editor = editor
        _label = State(initialValue: style.label)
        _hex = State(initialValue: Self.normalized(style.color))
    }

    var body: some View {
        let status = editor.status(of: style.letter)
        HStack(spacing: 12) {
            Badge(letter: style.letter, color: Color(hex: hex), size: 26)
            VStack(alignment: .leading, spacing: 2) {
                TextField("Name", text: $label, prompt: Text("Claude \(style.letter)"))
                    .labelsHidden()
                    .textFieldStyle(.plain)
                    .font(.body.weight(.medium))
                Text(Self.text(status)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            action(status)
            ColorPicker("Colour", selection: color, supportsOpacity: false).labelsHidden()
            Picker("Key", selection: hotkey) {
                Text("No key").tag(String?.none)
                ForEach(editor.keys(for: style.letter), id: \.self) { key in Text("⌥⌘\(key)").tag(Optional(key)) }
            }
            .labelsHidden()
            .frame(width: 92)
            Button { removing = true } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .disabled(style.letter == "A" || editor.working != nil)
                .help(style.letter == "A" ? "Claude A is Claude itself, so it stays" : "Remove Claude \(style.letter)")
        }
        .padding(.vertical, 3)
        .task(id: label) {
            try? await Task.sleep(for: .milliseconds(600))
            let name = label.trimmingCharacters(in: .whitespaces)
            guard !Task.isCancelled, !name.isEmpty, name != style.label else { return }
            editor.update(style.letter) { $0.label = name }
        }
        .task(id: hex) {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, hex != Self.normalized(style.color) else { return }
            editor.update(style.letter) { $0.color = hex }
        }
        // profiles.json saved by hand.
        .onChange(of: style.label) { _, new in if new != label.trimmingCharacters(in: .whitespaces) { label = new } }
        .onChange(of: style.color) { _, new in if Self.normalized(new) != hex { hex = Self.normalized(new) } }
        .confirmationDialog("Remove Claude \(style.letter)?", isPresented: $removing) {
            Button("Remove") { Task { await editor.remove(style.letter, data: false) } }
            Button("Remove and delete its data", role: .destructive) { Task { await editor.remove(style.letter, data: true) } }
        } message: {
            Text("Its ring, launcher and ⌥⌘ key go. Its data folder stays, so it's still signed in if you add Claude \(style.letter) again. Deleting the data signs it out and deletes its settings.")
        }
    }

    @ViewBuilder private func action(_ status: CopiesEditor.Status) -> some View {
        switch status {
        case .notMade:
            Button { Task { await editor.make(style.letter) } } label: { Self.button("Make") }.disabled(editor.working != nil)
        case .signedOut:
            Button { editor.open(style.letter) } label: { Self.button("Sign in") }
        default:
            Button { editor.open(style.letter) } label: { Self.button("Open") }
        }
    }

    /// One width for Make, Sign in and Open, so the rows line up.
    private static func button(_ title: String) -> some View { Text(title).frame(minWidth: 52) }

    private var color: Binding<Color> {
        Binding(get: { Color(hex: hex) }, set: { hex = Self.hex($0) })
    }

    private var hotkey: Binding<String?> {
        Binding(get: { style.hotkey }, set: { key in editor.update(style.letter) { $0.hotkey = key } })
    }

    static func text(_ status: CopiesEditor.Status) -> String {
        switch status {
        case .notMade: "Not made yet"
        case .notOpened: "Not opened yet"
        case .signedOut: "Not signed in"
        case .reading: "Reading…"
        case .signedIn(let plan): plan.map { "Signed in · \($0)" } ?? "Signed in"
        case .problem(let text): text
        }
    }

    /// "#2F7BF5", in sRGB.
    static func hex(_ color: Color) -> String {
        let c = NSColor(color).usingColorSpace(.sRGB) ?? .gray
        func byte(_ v: CGFloat) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(c.redComponent), byte(c.greenComponent), byte(c.blueComponent))
    }

    /// profiles.json's colour as `hex` writes it: "2f7bf5" is "#2F7BF5".
    static func normalized(_ color: String) -> String { hex(Color(hex: color)) }
}
