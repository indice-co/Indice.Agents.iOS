import Foundation

/// A lossless queue for one producer and one consumer. A full queue suspends
/// send() instead of dropping an event. Cancellation ends both sides.
actor SSEEventChannel<Element: Sendable> {
    private struct Entry {
        let value: Element
        let bytes: Int
    }

    private let capacity: Int
    private let maximumBufferedBytes: Int
    private var queue: [Entry] = []
    private var bufferedBytes = 0
    private var sender: (Entry, CheckedContinuation<Void, Error>)?
    private var receiver: CheckedContinuation<Element?, Error>?
    private var termination: Result<Void, Error>?

    init(capacity: Int = 32, maximumBufferedBytes: Int = 512 * 1024) {
        precondition(capacity > 0 && maximumBufferedBytes > 0)
        self.capacity = capacity
        self.maximumBufferedBytes = maximumBufferedBytes
    }

    func send(_ value: Element, bytes: Int) async throws {
        try Task.checkCancellation()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                if let termination {
                    continuation.resume(throwing: termination.failure ?? CancellationError())
                    return
                }
                let entry = Entry(value: value, bytes: max(0, bytes))
                if let receiver {
                    self.receiver = nil
                    receiver.resume(returning: value)
                    continuation.resume()
                } else if fits(entry) {
                    enqueue(entry)
                    continuation.resume()
                } else {
                    precondition(sender == nil, "SSE requires a single producer")
                    sender = (entry, continuation)
                }
            }
        } onCancel: {
            Task { await self.cancel() }
        }
        try Task.checkCancellation()
    }

    func next() async throws -> Element? {
        try Task.checkCancellation()
        let value = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Element?, Error>) in
                if !queue.isEmpty {
                    let entry = queue.removeFirst()
                    bufferedBytes -= entry.bytes
                    if let (pending, sender) = sender, fits(pending) {
                        self.sender = nil
                        enqueue(pending)
                        sender.resume()
                    }
                    continuation.resume(returning: entry.value)
                } else if let termination {
                    continuation.resume(with: termination.map { nil })
                } else {
                    precondition(receiver == nil, "SSE requires a single consumer")
                    receiver = continuation
                }
            }
        } onCancel: {
            Task { await self.cancel() }
        }
        try Task.checkCancellation()
        return value
    }

    /// EOF and transport errors drain already accepted events before terminating.
    func finish(throwing error: Error? = nil) {
        guard termination == nil else { return }
        let result: Result<Void, Error> = error.map { .failure($0) } ?? .success(())
        termination = result
        sender?.1.resume(throwing: error ?? CancellationError())
        sender = nil
        receiver?.resume(with: result.map { nil })
        receiver = nil
    }

    /// Explicit cancellation discards queued events and unblocks both waiters,
    /// including when EOF was already received while events remained buffered.
    func cancel() {
        queue.removeAll()
        bufferedBytes = 0
        termination = .failure(CancellationError())
        sender?.1.resume(throwing: CancellationError())
        sender = nil
        receiver?.resume(throwing: CancellationError())
        receiver = nil
    }

    private func fits(_ entry: Entry) -> Bool {
        // Allow one oversized frame so a valid frame cannot deadlock the queue.
        // SSEParser separately limits each frame to 8 MiB. The producer may also
        // retain one pending frame; URLSession has its own networking buffers.
        queue.isEmpty || (queue.count < capacity && entry.bytes <= maximumBufferedBytes - bufferedBytes)
    }

    private func enqueue(_ entry: Entry) {
        queue.append(entry)
        bufferedBytes += entry.bytes
    }
}

private extension Result where Success == Void, Failure == Error {
    var failure: Error? {
        if case .failure(let error) = self { error } else { nil }
    }
}
