import SwiftUI
import UsageCore

/// The gear's page: privacy, how the notch behaves, and the app itself. Its own switches
/// and choices rather than AppKit's, which want a key window this panel never is.
struct SettingsPage: View {
    @Bindable var preferences: Preferences
    let actions: PanelActions

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            section("Privacy") {
                SwitchRow(
                    title: "Show emails and team names",
                    detail: "Off, each row shows its profile name and plan, so the panel can open in front of anyone. Hold ⌥ over it to see them for a moment.",
                    isOn: $preferences.showDetails
                )
            }
            section("Notch") {
                ChoiceRow(
                    title: "Open the panel",
                    detail: preferences.openOn == .hover
                        ? "Rest the pointer on the notch. A click opens it at once."
                        : "Click the notch. It never opens by accident.",
                    selection: $preferences.openOn
                )
                SwitchRow(
                    title: "Alerts near limits",
                    detail: "Peeks out when a copy passes 90% of its 5-hour limit, runs out, or comes back.",
                    isOn: $preferences.limitAlerts
                )
                SwitchRow(title: "Show switches", detail: "Peeks out naming the copy \(hotkeys) switched to.", isOn: $preferences.switchPeeks)
                SwitchRow(title: "Haptic feedback", detail: "A tick on the trackpad as the panel opens.", isOn: $preferences.haptics)
            }
            section("General") {
                LoginItemRow()
                ProfilesRow(edit: actions.editProfiles, reload: actions.reloadProfiles)
            }
            section("Reading it") { Legend() }
            HStack {
                Text("Claude Notch \(Self.version)").font(.system(size: 10)).foregroundStyle(.tertiary)
                Spacer()
                Button("Quit", action: actions.quit).buttonStyle(PillButtonStyle())
            }
            .padding(.horizontal, 8)
        }
    }

    private var hotkeys: String {
        let keys = AccountStyle.styles.compactMap(\.hotkey)
        return keys.isEmpty ? "a hotkey" : "⌥⌘" + keys.joined(separator: ", ")
    }

    static var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev" }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 10)
            VStack(spacing: 0) { content() }
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.04)))
        }
    }
}

/// A setting's row: its name and what it does on the left, its control on the right.
private struct SettingLabel<Control: View>: View {
    let title: String
    let detail: String?
    @ViewBuilder let control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .medium))
                if let detail {
                    Text(detail)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.opacity)
                }
            }
            Spacer(minLength: 8)
            control
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The whole row toggles, with a highlight under the pointer.
private struct SettingRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { Row(configuration: configuration) }

    private struct Row: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled
        @State private var hovered = false

        var body: some View {
            configuration.label
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white.opacity(!isEnabled ? 0 : configuration.isPressed ? 0.08 : hovered ? 0.05 : 0))
                )
                .contentShape(Rectangle())
                .onHover { hovered = $0 }
                .animation(.smooth(duration: 0.12), value: hovered)
        }
    }
}

struct SwitchRow: View {
    let title: String
    let detail: String?
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) { isOn.toggle() }
        } label: {
            SettingLabel(title: title, detail: detail) { SwitchKnob(isOn: isOn) }
        }
        .buttonStyle(SettingRowStyle())
    }
}

struct SwitchKnob: View {
    let isOn: Bool

    var body: some View {
        Capsule()
            .fill(isOn ? AccountStyle.accent : .white.opacity(0.16))
            .frame(width: 30, height: 18)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle().fill(.white).padding(2).shadow(color: .black.opacity(0.3), radius: 1, y: 0.5)
            }
    }
}

/// Hover or click, with the selection sliding between them.
private struct ChoiceRow: View {
    let title: String
    let detail: String
    @Binding var selection: Preferences.OpenOn
    @Namespace private var namespace

    var body: some View {
        SettingLabel(title: title, detail: detail) {
            HStack(spacing: 0) {
                ForEach(Preferences.OpenOn.allCases, id: \.self) { option in
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) { selection = option }
                    } label: {
                        Text(option == .hover ? "Hover" : "Click")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(selection == option ? .black : .white.opacity(0.65))
                            .padding(.horizontal, 11)
                            .frame(height: 20)
                            .background {
                                if selection == option {
                                    Capsule().fill(.white).matchedGeometryEffect(id: "choice", in: namespace)
                                }
                            }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(Capsule().fill(.white.opacity(0.1)))
        }
    }
}

/// Only the app in an Applications folder can be a login item; a build elsewhere says so
/// rather than flicking its switch back.
private struct LoginItemRow: View {
    @State private var on = LoginItem.isEnabled
    private let available = LoginItem.isInstalled

    var body: some View {
        Button {
            let wanted = !on
            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) { on = wanted }
            let actual = LoginItem.set(wanted)
            if actual != wanted { withAnimation { on = actual } }
        } label: {
            SettingLabel(title: "Open at login", detail: available ? nil : "Only for the app in Applications.") {
                SwitchKnob(isOn: on).opacity(available ? 1 : 0.4)
            }
        }
        .buttonStyle(SettingRowStyle())
        .disabled(!available)
    }
}

private struct ProfilesRow: View {
    let edit: () -> Void
    let reload: () -> Void

    var body: some View {
        SettingLabel(title: "Profiles", detail: "Names, colours and ⌥⌘ keys, in ~/.config/claude-multi-account/profiles.json.") {
            HStack(spacing: 6) {
                Button("Edit", action: edit)
                Button("Reload", action: reload)
            }
            .buttonStyle(PillButtonStyle())
        }
    }
}

/// What the rings and bars mean.
private struct Legend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                RingGlyph(color: AccountStyle.of("A").color, fiveHour: 0.62, weekly: 0.35)
                    .scaleEffect(1.25)
                    .frame(width: 44)
                Text("Beside the notch, one ring per copy. Outer: the 5-hour window, which turns red and unwinds until it's back once it's used up. Inner: the fullest weekly window, a red cross when it's used up. The dot is the copy in front.")
            }
            HStack(alignment: .top, spacing: 12) {
                UsageBar(fraction: 0.55, color: AccountStyle.of("B").color, pace: 0.4)
                    .frame(width: 44)
                    .padding(.top, 5)
                Text("The tick on a bar marks how far through its window it is. A bar past its tick is going faster than an even pace. A used-up bar drains until it's back. Hover a row for the time it resets.")
            }
        }
        .font(.system(size: 10.5))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(10)
    }
}
