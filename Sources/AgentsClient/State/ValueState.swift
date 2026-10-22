//
//  ValueState.swift
//  Indice.Agents
//
//  Created by Nikolas Konstantakopoulos on 30/9/26.
//

import Foundation

public class ValueState<T: Sendable>: @unchecked Sendable {
    
    private class Holder: @unchecked Sendable {
        private var lock = CriticalSectionLock()
        private var continuations: [UUID: AsyncStream<T>.Continuation] = [:]
        
        func add(withId id: UUID, _ continuation: AsyncStream<T>.Continuation) {
            lock.withLock {
                continuations[id] = continuation
            }
        }
        
        func remove(_ id: UUID) {
            lock.withLock {
                _ = continuations.removeValue(forKey: id)
            }
        }
        
        func yieldAll(_ value: T) {
            lock.withLock {
                continuations
                    .values
                    .forEach { $0.yield(value) }
            }
        }
    }
    
    private let holder = Holder()
    
    public
    private(set) var value: T

    init(_ initial: T) { self.value = initial }

    convenience init<V>(
        _ value: V? = nil
    ) where T == Optional<V> {
        self.init(value)
    }
    
    @discardableResult
    func set(_ newValue: T) -> T {
        value = newValue
        holder.yieldAll(value)
        
        return newValue
    }
        
    func stream() -> AsyncStream<T> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            continuation.yield(value)
            let id = UUID()
            holder.add(withId: id, continuation)
            continuation.onTermination = { /* reason */ [weak holder] _ in
                holder?.remove(id)
            }
        }
    }
}



import Combine

public extension ValueState {
    func hasValue<V>() -> Bool where T == Optional<V> {
        value != nil
    }
}

public extension ValueState {
    
    @MainActor
    func publisher(
        on scheduler: some Scheduler = RunLoop.main
    ) -> AnyPublisher<T, Never> {
        publisher(on: scheduler, transformation: { $0 })
    }
    
    @MainActor
    func publisher<V: Sendable>(
        on scheduler: some Scheduler = RunLoop.main,
        transformation: @escaping @Sendable (T) -> V
    ) -> AnyPublisher<V, Never> {
        let stream = self
            .stream()
            .map(transformation)
        
        let subject: CurrentValueSubject<V, Never>
            = .init(transformation(value))
        
        let task = Task {
            for await value in stream {
                subject.send(value)
            }
            
            subject.send(completion: .finished)
        }
        
        return subject
            .handleEvents(
                receiveCancel: { task.cancel() })
            .receive(on: scheduler)
            .eraseToAnyPublisher()
    }

}
