import Foundation

/// Transport metadata is deliberately separate from the JSON payload. `event:` is
/// not the API's `type` discriminator, and the server's OpenAPI SseItem schema is
/// not a JSON wrapper that appears on the wire.
public struct ServerSentEvent<Value: Sendable>: Sendable {
    public let data: Value
    public let eventType: String
    public let eventID: String?
    public let retryMilliseconds: Int?
}

public enum SSEError: Error, LocalizedError, Sendable {
    case invalidResponse
    case http(statusCode: Int, body: Data)
    case unexpectedContentType(String?)
    case invalidUTF8
    case frameTooLarge
    case bufferOverflow // Retained for compatibility; a full queue now suspends the producer.

    public var errorDescription: String? {
        switch self {
        case .invalidResponse: "The stream did not return an HTTP response."
        case .http(let status, _): "The streaming request failed (HTTP \(status))."
        case .unexpectedContentType(let value): "Expected text/event-stream, received \(value ?? "no content type")."
        case .invalidUTF8: "The stream contains invalid UTF-8."
        case .frameTooLarge: "A server-sent event exceeded the supported size."
        case .bufferOverflow: "The stream consumer could not keep up with the response."
        }
    }
}

/// Owns a single connection. Cancel explicitly when stopping before EOF; releasing
/// the last copy also cancels it. This prevents a producer from living forever if
/// a consumer breaks out of its loop while the server is still sending events.
public struct ServerSentEventStream<Value: Sendable>: AsyncSequence, Sendable {
    public typealias Element = ServerSentEvent<Value>
    
    public struct AsyncIterator: AsyncIteratorProtocol {
        
        private let events: SSEEventChannel<Element>
        // Retain ownership even for `for await ... in makeStream()` expressions,
        // where the sequence itself may be released after creating the iterator.
        private let lifetime: StreamLifetime

        fileprivate init(events: SSEEventChannel<Element>, lifetime: StreamLifetime) {
            self.events = events
            self.lifetime = lifetime
        }

        @concurrent public mutating func next() async throws -> Element? {
            let lifetime = lifetime
            return try await withTaskCancellationHandler {
                try lifetime.checkCancellation()
                let event = try await events.next()
                try lifetime.checkCancellation()
                return event
            } onCancel: {
                lifetime.cancel()
            }
        }
    }

    private let events: SSEEventChannel<Element>
    private let lifetime: StreamLifetime

    init(events: SSEEventChannel<Element>, producer: Task<Void, Never>, connection: URLSessionTask) {
        self.events = events
        self.lifetime = StreamLifetime(producer: producer, connection: connection,
                                       cancelEvents: { Task { await events.cancel() } })
    }

    public func makeAsyncIterator() -> AsyncIterator { .init(events: events, lifetime: lifetime) }
    public func cancel() { lifetime.cancel() }
}

// Handles are immutable; the explicit-cancellation flag is protected by a lock.
fileprivate final class StreamLifetime: @unchecked Sendable {
    let producer: Task<Void, Never>
    let connection: URLSessionTask
    let cancelEvents: @Sendable () -> Void
    private let lock = NSLock()
    private var isCancelled = false

    init(producer: Task<Void, Never>, connection: URLSessionTask, cancelEvents: @escaping @Sendable () -> Void) {
        self.producer = producer
        self.connection = connection
        self.cancelEvents = cancelEvents
    }

    func cancel() {
        let shouldCancel = lock.withLock {
            guard !isCancelled else { return false }
            isCancelled = true
            return true
        }
        guard shouldCancel else { return }
        producer.cancel()
        connection.cancel()
        cancelEvents()
    }

    func checkCancellation() throws {
        // Actor cleanup is asynchronous, but cancel() must stop delivery as soon
        // as it returns, even when a decoded event is already in the queue.
        if lock.withLock({ isCancelled }) { throw CancellationError() }
    }

    deinit { cancel() }
}
