import Foundation
import AgentsModels

public enum AgentsError: Error, LocalizedError, Sendable {
    case notSignedIn
    case invalidRequest(String)
    case invalidStream(String)
    case streamFailed(String)
    case incompleteStream
    case turnInProgress
    case missingConversationID

    public var errorDescription: String? {
        switch self {
        case .notSignedIn: "Sign in before using the Agents API."
        case .invalidRequest(let reason), .invalidStream(let reason), .streamFailed(let reason): reason
        case .incompleteStream: "The connection ended before the reply was complete."
        case .turnInProgress: "Wait for the current reply or stop it before sending another message."
        case .missingConversationID: "The server did not supply a conversation ID."
        }
    }
}

/// Chat protocol only. This is deliberately independent of SSE and NetworkClient:
/// the same ordered JSON patches could arrive over another transport in future.
struct JSONPointerPatcher {
    private var previousPath: String?
    private var previousOperation: DexChatPatchOp?

    mutating func apply(_ patch: DexChatStreamDelta, to document: inout JSONValue) throws {
        // A missing/null path or op inherits its PREVIOUS effective value, even
        // across status frames. Empty string is the root pointer, not inheritance.
        // `value` never inherits: a missing/null operand means JSON null.
        guard let path = patch.path ?? previousPath,
              let operation = patch.op ?? previousOperation else {
            throw AgentsError.invalidStream("The first delta must include a path and operation.")
        }
        
        let segments = try Self.segments(path)
        try Self.modify(&document, at: segments[...], operation: operation, value: patch.value ?? .null)
        previousPath = path
        previousOperation = operation
    }

    private static func segments(_ path: String) throws -> [String] {
        if path.isEmpty { return [] }
        guard path.hasPrefix("/") else { throw AgentsError.invalidStream("Invalid JSON Pointer: \(path)") }
        return try path.dropFirst().split(separator: "/", omittingEmptySubsequences: false).map { part in
            var result = ""
            var iterator = part.makeIterator()
            while let character = iterator.next() {
                if character == "~" {
                    switch iterator.next() {
                    case "0": result.append("~")
                    case "1": result.append("/")
                    default: throw AgentsError.invalidStream("Invalid JSON Pointer escape.")
                    }
                } else { result.append(character) }
            }
            return result
        }
    }

    private static func modify(_ node: inout JSONValue, at path: ArraySlice<String>, operation: DexChatPatchOp, value: JSONValue) throws {
        guard let key = path.first else {
            switch operation {
            case .add, .replace: node = value
            case .append:
                guard case .string(let current) = node, case .string(let suffix) = value else {
                    throw AgentsError.invalidStream("append requires string operands.")
                }
                node = .string(current + suffix)
            }
            return
        }
        let tail = path.dropFirst()
        switch node {
        case .object(var object):
            if tail.isEmpty {
                if operation == .replace, object[key] == nil {
                    throw AgentsError.invalidStream("replace requires an existing target.")
                }
                var child = object[key] ?? (operation == .append ? .string("") : .null)
                try modify(&child, at: tail, operation: operation, value: value)
                object[key] = child
            } else {
                guard var child = object[key] else { throw AgentsError.invalidStream("Missing patch parent: \(key)") }
                try modify(&child, at: tail, operation: operation, value: value)
                object[key] = child
            }
            node = .object(object)
        case .array(var array):
            let index: Int
            if key == "-", tail.isEmpty, operation == .add { index = array.count }
            else {
                guard !key.isEmpty, key.utf8.allSatisfy({ (48...57).contains($0) }),
                      key == "0" || !key.hasPrefix("0"), let parsed = Int(key) else {
                    throw AgentsError.invalidStream("Invalid patch array index: \(key)")
                }
                index = parsed
            }
            if tail.isEmpty, operation == .add {
                guard index <= array.count else { throw AgentsError.invalidStream("Patch index is out of bounds.") }
                array.insert(value, at: index)
            } else {
                guard array.indices.contains(index) else { throw AgentsError.invalidStream("Patch index is out of bounds.") }
                try modify(&array[index], at: tail, operation: operation, value: value)
            }
            node = .array(array)
        default: throw AgentsError.invalidStream("A patch parent must be an object or array.")
        }
    }
}

/// One instance per turn: compaction state must never leak between conversations.
/// `start` supplies identity; `delta` builds the response; `done` commits it. A
/// socket EOF is not a successful commit and must never be treated as `done`.
struct ChatStreamAssembler {
    enum Update: Sendable {
        case started(UUID)
        case status(String)
        case changed
        case completed(DexChatResponse)
        case ignored
    }

    private var document: JSONValue = .object([:])
    private var patcher = JSONPointerPatcher()
    private var conversationID: UUID?
    private var guestSession: GuestSession?
    private(set) var isComplete = false
    private var hasTerminated = false

    mutating func consume(_ event: DexChatResponseUpdate) throws -> Update {
        guard !hasTerminated else {
            throw AgentsError.invalidStream("Received a frame after a terminal event.")
        }
        
        // Future discriminator values carry no semantics for this client. Do not
        // let an unknown frame change lifecycle or patch-inheritance state.
        if case .unknown = event { return .ignored }
        
        switch event {
        case .start(let frame):
            guard conversationID == nil, let id = frame.conversationId else {
                throw AgentsError.invalidStream("Expected one start frame with a conversation ID.")
            }
            conversationID = id
            guestSession = frame.guestSession
            return .started(id)
        case .error(let frame):
            hasTerminated = true
            document = .object([:]) // Failed answers are not persisted by the server.
            throw AgentsError.streamFailed(frame.reason)
        default:
            guard conversationID != nil else { throw AgentsError.invalidStream("Received a frame before start.") }
            switch event {
            case .status(let frame): return .status(frame.value)
            case .delta(let frame):
                try patcher.apply(frame, to: &document)
                return .changed
            case .done:
                let result = try response()
                guard let messages = result.messages, !messages.isEmpty else {
                    throw AgentsError.invalidStream("The completed response contains no messages.")
                }
                hasTerminated = true
                isComplete = true
                return .completed(result)
            default: return .ignored
            }
        }
    }

    func response() throws -> DexChatResponse {
        // Patches describe a partially populated DexChatResponse, whose fields
        // are optional in the schema. Decode snapshots with the same date and
        // number handling as REST. The projector omits computed `text`; derive
        // that convenience member just as the backend does for a REST response.
        let data = try APIJSON.encoder().encode(document)
        var response = try APIJSON.decoder().decode(DexChatResponse.self, from: data)
        if let id = response.conversationId, id != conversationID {
            throw AgentsError.invalidStream("The response changed conversation ID during a turn.")
        }
        response.conversationId = conversationID
        response.guestSession = guestSession
        response.text = (response.messages ?? []).flatMap { $0.content?.parts ?? [] }.compactMap(\.value).joined()
        return response
    }
}

/// Accumulation never waits for the UI. Only a presentation tick materializes a
/// response; intermediate deltas are already incorporated in the document.
actor ChatStreamAccumulator {
    struct Snapshot: Sendable {
        let response: DexChatResponse?
        let status: String?
        fileprivate let revision: UInt64
    }

    private var assembler = ChatStreamAssembler()
    private var responseChanged = false
    private var status: String?
    private var revision: UInt64 = 0

    func consume(_ event: DexChatResponseUpdate) throws -> ChatStreamAssembler.Update {
        let update = try assembler.consume(event)
        switch update {
        case .changed:
            responseChanged = true
            revision &+= 1
        case .status(let label):
            status = label
            revision &+= 1
        default: break
        }
        return update
    }

    func snapshot() throws -> Snapshot {
        let response = responseChanged ? try assembler.response() : nil
        return Snapshot(response: response, status: status, revision: revision)
    }

    func didPublish(_ snapshot: Snapshot) {
        // Changes received while the main actor was busy remain pending. Also
        // keep a snapshot pending if cancellation happens before publication.
        guard snapshot.revision == revision else { return }
        responseChanged = false
        status = nil
    }
}
