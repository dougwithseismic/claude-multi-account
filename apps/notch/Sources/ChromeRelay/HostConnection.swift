import Darwin
import Foundation

enum RelayError: Error, CustomStringConvertible {
    /// No native host is running: Chrome is closed, or the extension isn't installed.
    case noHost
    case unsafe(String)
    case io(String)
    /// The host closed the connection before answering.
    case closed
    case timedOut

    var description: String {
        switch self {
        case .noHost:
            "Chrome isn't reachable on this Mac. Ask the user to open Chrome with the Claude extension installed (the extension starts its local helper when Chrome starts), or to restart Chrome if it's already open, then retry."
        case .unsafe(let reason):
            "Refused to use Chrome's local helper: \(reason)"
        case .io(let reason):
            "Couldn't talk to Chrome's local helper: \(reason)"
        case .closed:
            "Chrome's local helper closed the connection before answering (Chrome quit or the extension reloaded). The action may have happened; check the page before repeating it."
        case .timedOut:
            "Chrome didn't answer in time. The action may still have happened; check the page (get_page_text or a screenshot) before repeating it."
        }
    }
}

/// The sockets Claude's Chrome native host listens on, one per running host:
/// /tmp/claude-mcp-browser-bridge-<user>/<pid>.sock. Chrome starts the host when the
/// extension loads, and any process of this Mac user may connect to it.
enum HostSocket {
    static let directory = "/tmp/claude-mcp-browser-bridge-\(NSUserName())"

    /// The sockets whose host is still running, newest first. Checks ownership and
    /// permissions the way Claude does before dialing.
    static func live() throws(RelayError) -> [String] {
        var info = stat()
        guard lstat(directory, &info) == 0 else { throw .noHost }
        guard info.st_mode & S_IFMT == S_IFDIR else { throw .unsafe("\(directory) is not a directory") }
        guard info.st_uid == getuid() else { throw .unsafe("\(directory) belongs to another user") }
        guard info.st_mode & 0o777 == 0o700 else { throw .unsafe("\(directory) is open to other users") }

        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []
        let sockets = names.compactMap { name -> (path: String, modified: Int)? in
            guard name.hasSuffix(".sock"), let pid = pid_t(name.dropLast(5)), isRunning(pid) else { return nil }
            let path = "\(directory)/\(name)"
            var info = stat()
            guard lstat(path, &info) == 0, info.st_mode & S_IFMT == S_IFSOCK, info.st_uid == getuid() else { return nil }
            return (path, info.st_mtimespec.tv_sec)
        }
        return sockets.sorted { $0.modified > $1.modified }.map(\.path)
    }

    static func isRunning(_ pid: pid_t) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }
}

/// One connection to the native host. The host tells the extension a client connected,
/// forwards each request to it and sends the answer back to this connection only.
final class HostConnection {
    private let socket: Int32
    private var buffer = Data()

    /// A throw after `socket` is set still runs deinit, which closes it.
    init(path: String) throws(RelayError) {
        socket = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard socket >= 0 else { throw .io(String(cString: strerror(errno))) }
        var on: Int32 = 1
        setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: address.sun_path) else { throw .io("socket path too long") }
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(socket, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else { throw .io("connecting to \(path): \(String(cString: strerror(errno)))") }
    }

    deinit {
        if socket >= 0 { Darwin.close(socket) }
    }

    /// False once the host has hung up. Reads anything it sent unasked into the buffer.
    var isOpen: Bool {
        poll(milliseconds: 0) <= 0 || readAvailable()
    }

    func send(_ body: Data) throws(RelayError) {
        let frame = Frame.encode(body)
        var sent = 0
        while sent < frame.count {
            let n = frame.withUnsafeBytes { Darwin.write(socket, $0.baseAddress! + sent, frame.count - sent) }
            guard n > 0 else {
                if n < 0, errno == EINTR { continue }
                throw n < 0 && errno != EPIPE ? .io(String(cString: strerror(errno))) : .closed
            }
            sent += n
        }
    }

    /// The next frame's body, waiting up to `timeout` seconds for it.
    func receive(timeout: TimeInterval) throws(RelayError) -> Data {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            if let body = Frame.take(from: &buffer) { return body }
            let left = deadline.timeIntervalSinceNow
            guard left > 0 else { throw .timedOut }
            let ready = poll(milliseconds: Int32(left * 1000))
            if ready < 0, errno != EINTR { throw .io(String(cString: strerror(errno))) }
            if ready > 0, !readAvailable() { throw .closed }
        }
    }

    private func poll(milliseconds: Int32) -> Int32 {
        var poller = pollfd(fd: socket, events: Int16(POLLIN), revents: 0)
        return Darwin.poll(&poller, 1, milliseconds)
    }

    /// Appends what's waiting to the buffer; false when the host hung up.
    private func readAvailable() -> Bool {
        var chunk = [UInt8](repeating: 0, count: 64 * 1024)
        let n = Darwin.read(socket, &chunk, chunk.count)
        if n > 0 {
            buffer.append(contentsOf: chunk[..<n])
            return true
        }
        return n < 0 && (errno == EINTR || errno == EAGAIN)
    }
}
