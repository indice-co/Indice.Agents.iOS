//
//  AsyncProcessor.swift
//  Indice.Agents
//
//  Created by Nikolas Konstantakopoulos on 2/10/26.
//

import Foundation

protocol AsyncProcessor: ProcessorObject {
    var isLoading: Bool { get }
    var errors: [Error]? { get }
}

extension AsyncProcessor {
    func execute<T>(
        id operationId: UUID = .init(),
        _ operation: @escaping (Self) async throws -> T,
        onSuccess: ((Self, T) -> Void)? = nil
    ) {
        tasks[operationId] = Task { [weak self] in
            guard let self else { return } // throw something?
            
            func set(loading: Bool) async {
                await MainActor.run { self.isLoading = loading }
            }
            
            await set(loading: true)
            
            defer { await set(loading: false) }
            defer { self.tasks[operationId] = nil }
            
            do {
                let result = try await operation(self)
                
                await MainActor.run { onSuccess?(self, result) }
            } catch {
                await MainActor.run { self.errors = [error] + (self.errors ?? []) }
            }
        }
    }
}



@MainActor
class ProcessorObject: ObservableObject, AsyncProcessor {
    
    fileprivate var tasks: [UUID: Task<Void, Never>] = [:]
    
    @Published
    fileprivate(set)
    var isLoading = false
    
    @Published
    fileprivate(set)
    var errors: [Error]?
}
