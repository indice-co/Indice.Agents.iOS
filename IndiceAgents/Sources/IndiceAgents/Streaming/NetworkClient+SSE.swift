import Foundation
import NetworkClient

public extension NetworkClient {
    /// Temporary standalone SSE transport. The receiver is only a convenient API
    /// namespace: none of NetworkClient's session, interceptors, task registry,
    /// logging, decoder, or error mapper is accessed here.
    ///
    /// Pass a fully authorized URLRequest. This function never refreshes tokens
    /// and never reconnects: replaying a POST can create a duplicate chat turn.
    /// `retry:` and `id:` are exposed as metadata for a future transport policy.
    ///
    /// Headers are awaited before returning, so callers can distinguish an HTTP
    /// 401 (safe to refresh and retry once) from failure after streaming begins.
    /// The returned sequence is intended for exactly one consumer.
    func openSSEStream<Value: Decodable & Sendable>(
        _ type: Value.Type,
        request: URLRequest,
        decoder: @escaping @Sendable () -> JSONDecoder = { JSONDecoder() }
    ) async throws -> ServerSentEventStream<Value> {
        try Task.checkCancellation()
        var request = request
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        // Ownership transfers to the returned sequence only after validation.
        // Any throw before that point must close the connection here.
        var handedOff = false
        defer { if !handedOff { bytes.task.cancel() } }
        guard let http = response as? HTTPURLResponse else { throw SSEError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            // An unauthorized response can have a slow/absent body. Return it
            // immediately so the caller's one-time credential refresh can run.
            if http.statusCode == 401 { throw SSEError.http(statusCode: 401, body: Data()) }
            var body = Data()
            for try await byte in bytes {
                body.append(byte)
                if body.count >= 64 * 1024 { break }
            }
            throw SSEError.http(statusCode: http.statusCode, body: body)
        }
        let contentType = http.value(forHTTPHeaderField: "Content-Type")
        guard contentType?.split(separator: ";", maxSplits: 1).first?
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "text/event-stream" else {
            throw SSEError.unexpectedContentType(contentType)
        }
        try Task.checkCancellation()

        let events = SSEEventChannel<ServerSentEvent<Value>>()
        let producer = Task.detached {
            defer { bytes.task.cancel() }
            do {
                var parser = SSEParser()
                let jsonDecoder = decoder() // One decoder, confined to this producer.
                for try await byte in bytes {
                    try Task.checkCancellation()
                    guard let frame = try parser.consume(byte) else { continue }
                    let payload = try jsonDecoder.decode(type, from: frame.data)
                    let event = ServerSentEvent(data: payload, eventType: frame.eventType,
                                                eventID: frame.eventID, retryMilliseconds: frame.retryMilliseconds)
                    try await events.send(event, bytes: frame.data.count)
                }
                try Task.checkCancellation()
                await events.finish()
            } catch {
                if Task.isCancelled { await events.cancel() }
                else { await events.finish(throwing: error) }
            }
        }
        handedOff = true
        return ServerSentEventStream(events: events, producer: producer, connection: bytes.task)
    }
}
