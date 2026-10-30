import Foundation

/// The native host's wire format: a 4-byte little-endian length, then that many bytes of JSON.
enum Frame {
    static func encode(_ body: Data) -> Data {
        var length = UInt32(body.count).littleEndian
        var frame = Data(bytes: &length, count: 4)
        frame.append(body)
        return frame
    }

    /// Removes the first whole frame from `buffer` and returns its body, or nil while it's
    /// still arriving.
    static func take(from buffer: inout Data) -> Data? {
        guard buffer.count >= 4 else { return nil }
        let start = buffer.startIndex
        let length = (0..<4).reduce(0) { $0 | Int(buffer[start + $1]) << (8 * $1) }
        guard buffer.count >= 4 + length else { return nil }
        let body = buffer.subdata(in: start + 4 ..< start + 4 + length)
        buffer.removeSubrange(start ..< start + 4 + length)
        return body
    }
}
