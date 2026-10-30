import Darwin
import Foundation

/// Which copy of Claude a process belongs to, read from the kernel; readable for the
/// user's own processes without any permission.
public enum ClaudeProcess {
    /// "--user-data-dir=…/Claude-B" is B, "…/Claude" or no such argument is A, a folder
    /// named anything else is a copy this setup didn't start.
    public static func letter(fromArguments arguments: [String]) -> String? {
        let prefix = "--user-data-dir="
        guard let argument = arguments.last(where: { $0.hasPrefix(prefix) }) else { return "A" }
        let folder = URL(filePath: String(argument.dropFirst(prefix.count))).lastPathComponent
        return Profile.letter(forFolder: folder)
    }

    /// The copy `pid` runs under: Claude starts Code tab sessions, chats' MCP servers and
    /// whatever those start below itself, so it's the nearest ancestor that is Claude.
    public static func copy(of pid: pid_t = getpid()) -> String? {
        copy(amongAncestors: sequence(first: pid, next: parent(of:)).lazy.compactMap(arguments(of:)))
    }

    /// The letter of the first of `ancestors` (each one's arguments, nearest first) that is Claude.
    static func copy(amongAncestors ancestors: some Sequence<[String]>) -> String? {
        ancestors.first { $0.first?.hasSuffix("/Claude.app/Contents/MacOS/Claude") == true }.flatMap(letter(fromArguments:))
    }

    /// Another process's arguments, from the kernel.
    public static func arguments(of pid: pid_t) -> [String]? {
        var mib = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return nil }
        return parseArguments(Array(buffer.prefix(size)))
    }

    /// KERN_PROCARGS2 is argc, the executable's path, NUL padding, then argc NUL-terminated
    /// arguments (then the environment, which is skipped).
    static func parseArguments(_ bytes: [UInt8]) -> [String]? {
        guard bytes.count >= 4 else { return nil }
        let argc = Int(bytes.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) })
        var i = 4
        while i < bytes.count, bytes[i] != 0 { i += 1 }
        while i < bytes.count, bytes[i] == 0 { i += 1 }
        var arguments: [String] = []
        while arguments.count < argc, i < bytes.count {
            let start = i
            while i < bytes.count, bytes[i] != 0 { i += 1 }
            arguments.append(String(decoding: bytes[start..<i], as: UTF8.self))
            i += 1
        }
        return arguments.count == argc ? arguments : nil
    }

    /// The process that started `pid`, or nil at launchd.
    static func parent(of pid: pid_t) -> pid_t? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { return nil }
        let parent = info.kp_eproc.e_ppid
        return parent > 1 ? parent : nil
    }
}
