import Foundation

/// Incremental SSE framing only: no JSON, authentication, or chat semantics.
///
/// Migration note: this parser and NetworkClient+SSE can move to NetworkClient.
/// The chat patch assembler should stay in IndiceAgents. A separate parser also
/// lets us test network fragmentation without timing-dependent HTTP tests.
struct SSEParser {
    struct Frame: Sendable {
        let data: Data
        let eventType: String
        let eventID: String?
        let retryMilliseconds: Int?
    }

    private var line = Data()
    private var dataLines: [String] = []
    private var eventType = ""
    private var lastEventID: String?
    private var retryMilliseconds: Int?
    private var skipLF = false
    private var firstLine = true
    private var dataByteCount = 0
    private let maximumFrameBytes: Int

    init(maximumFrameBytes: Int = 8 * 1024 * 1024) {
        self.maximumFrameBytes = maximumFrameBytes
    }

    /// CR, LF, and CRLF are all line endings. Remember a CR across calls so an LF
    /// in the next network chunk does not accidentally become a second newline.
    /// Decode UTF-8 only after a complete line: a multi-byte character may span
    /// any number of reads from URLSession.AsyncBytes.
    mutating func consume(_ byte: UInt8) throws -> Frame? {
        if skipLF {
            skipLF = false
            if byte == 10 { return nil }
        }
        if byte == 13 || byte == 10 {
            skipLF = byte == 13
            return try finishLine()
        }
        line.append(byte)
        guard line.count + dataByteCount <= maximumFrameBytes else { throw SSEError.frameTooLarge }
        return nil
    }

    private mutating func finishLine() throws -> Frame? {
        guard var text = String(data: line, encoding: .utf8) else { throw SSEError.invalidUTF8 }
        line.removeAll(keepingCapacity: true)
        if firstLine {
            firstLine = false
            if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        }

        // Only a blank line commits an event. An unterminated event at EOF must
        // not be dispatched: the chat service will report an incomplete turn if
        // no complete `done` event was received.
        if text.isEmpty {
            defer {
                dataLines.removeAll(keepingCapacity: true)
                dataByteCount = 0
                eventType = ""
            }
            guard !dataLines.isEmpty else { return nil }
            return Frame(data: Data(dataLines.joined(separator: "\n").utf8),
                         eventType: eventType.isEmpty ? "message" : eventType,
                         eventID: lastEventID, retryMilliseconds: retryMilliseconds)
        }
        if text.hasPrefix(":") { return nil } // Heartbeat/comment, not an event.

        let colon = text.firstIndex(of: ":")
        let field = colon.map { String(text[..<$0]) } ?? text
        var value = colon.map { String(text[text.index(after: $0)...]) } ?? ""
        // SSE removes exactly ONE optional space, not all leading whitespace.
        // JSON strings, indentation and appended text must survive unchanged.
        if value.hasPrefix(" ") { value.removeFirst() }
        switch field {
        case "data":
            dataByteCount += value.utf8.count + 1
            guard dataByteCount <= maximumFrameBytes else { throw SSEError.frameTooLarge }
            dataLines.append(value)
        case "event": eventType = value
        case "id":
            if !value.contains("\0") { lastEventID = value }
        case "retry":
            if !value.isEmpty, value.utf8.allSatisfy({ (48...57).contains($0) }), let milliseconds = Int(value) {
                retryMilliseconds = milliseconds
            }
        default: break // Unknown SSE fields are allowed by the protocol.
        }
        return nil
    }
}
