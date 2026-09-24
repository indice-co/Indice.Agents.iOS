import Foundation
import Testing
import AgentsModels
@testable import IndiceAgents

@Suite(.timeLimit(.minutes(1)))
struct StreamingBufferTests {
    @Test(arguments: [false, true])
    func fullQueueSuspendsProducerUntilSpaceIsAvailable(limitBytes: Bool) async throws {
        let channel = SSEEventChannel<Int>(capacity: limitBytes ? 10 : 1, maximumBufferedBytes: 10)
        try await channel.send(1, bytes: 6)
        let progress = Progress()
        let producer = Task {
            await progress.start()
            try await channel.send(2, bytes: 6)
            await progress.finish()
        }
        await progress.waitForStart()
        try await Task.sleep(for: .milliseconds(20))
        #expect(await !progress.finished)
        #expect(try await channel.next() == 1)
        try await producer.value
        #expect(await progress.finished)
        await channel.finish()
        #expect(try await channel.next() == 2)
        #expect(try await channel.next() == nil)
    }

    @Test func oversizedFrameCanPassWithoutDeadlock() async throws {
        let channel = SSEEventChannel<Int>(capacity: 2, maximumBufferedBytes: 10)
        try await channel.send(1, bytes: 100)
        let producer = Task {
            try await channel.send(2, bytes: 100)
            await channel.finish()
        }
        #expect(try await channel.next() == 1)
        #expect(try await channel.next() == 2)
        #expect(try await channel.next() == nil)
        try await producer.value
    }

    @Test func burstIsLosslessAndDrainsBeforeTransportFailure() async throws {
        let channel = SSEEventChannel<Int>(capacity: 3)
        let producer = Task {
            for value in 0..<2_000 { try await channel.send(value, bytes: 1) }
            await channel.finish(throwing: SSEError.invalidUTF8)
        }
        var received: [Int] = []
        do {
            while let value = try await channel.next() {
                received.append(value)
                if value.isMultiple(of: 100) { try await Task.sleep(for: .milliseconds(1)) }
            }
            Issue.record("Expected the transport error after queued values")
        } catch SSEError.invalidUTF8 { }
        try await producer.value
        #expect(received == Array(0..<2_000))
    }

    @Test func cancellingBlockedProducerDiscardsQueueAndUnblocksConsumer() async throws {
        let channel = SSEEventChannel<Int>(capacity: 1)
        try await channel.send(1, bytes: 1)
        let progress = Progress()
        let producer = Task {
            await progress.start()
            try await channel.send(2, bytes: 1)
        }
        await progress.waitForStart()
        try await Task.sleep(for: .milliseconds(20))
        producer.cancel()
        await #expect(throws: CancellationError.self) { try await producer.value }
        await #expect(throws: CancellationError.self) { try await channel.next() }
        await channel.finish()
        await channel.cancel() // Repeated cleanup must not resume a waiter twice.
    }

    @Test func cancellingBlockedConsumerUnblocksProducer() async throws {
        let channel = SSEEventChannel<Int>()
        let progress = Progress()
        let consumer = Task {
            await progress.start()
            return try await channel.next()
        }
        await progress.waitForStart()
        try await Task.sleep(for: .milliseconds(20))
        consumer.cancel()
        await #expect(throws: CancellationError.self) { try await consumer.value }
        await #expect(throws: CancellationError.self) { try await channel.send(1, bytes: 1) }
    }

    @Test func accumulatorPreservesChangesUntilPublicationIsAcknowledged() async throws {
        let accumulator = ChatStreamAccumulator()
        for frame in try TurnFixture.frames().prefix(6) { _ = try await accumulator.consume(frame) }
        let first = try await accumulator.snapshot()
        #expect(first.response?.text == "Γεια ")
        // Obtaining a snapshot alone must not lose unpublished content on cancel.
        #expect(try await accumulator.snapshot().response == first.response)
        _ = try await accumulator.consume(.delta(.init(value: .string("👋"))))
        await accumulator.didPublish(first) // Main actor finished an older snapshot.
        let latest = try await accumulator.snapshot()
        #expect(latest.response?.text == "Γεια 👋")
        await accumulator.didPublish(latest)
        #expect(try await accumulator.snapshot().response == nil)
        #expect(try await accumulator.snapshot().status == nil)
    }

    private actor Progress {
        private var started = false
        private(set) var finished = false
        func start() { started = true }
        func finish() { finished = true }
        func waitForStart() async {
            while !started { await Task.yield() }
        }
    }
}
