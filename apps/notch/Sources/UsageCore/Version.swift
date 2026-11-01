/// The release every part of Claude Notch reports: the app's Info.plist (build-app.sh reads
/// it from here), `claude-usage --version`, `claude-chrome-relay --version` and the relay's
/// MCP server info. `install.sh --doctor` compares the installed app against it.
public enum NotchVersion {
    public static let current = "1.0"
    /// The app's CFBundleVersion: one more for every release.
    public static let build = "6"
}
