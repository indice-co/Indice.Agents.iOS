//
//  ViewModel.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 9/7/26.
//

import Foundation
import Combine

@MainActor
class ViewModel: ObservableObject {
    
    
    let asyncState = AsyncState()
    
    private var tasks: [(id: UUID, task: Task<Void, Never>)] = []
    
    @Published
    private(set)
    var errors: [UIError] = []
    
    @Published
    private(set)
    var isLoading = false
    
    init() {
        asyncState
            .$errors
            .map { $0.map(\.1) }
            .receive(on: RunLoop.main)
            .assign(to: &$errors)
        
        asyncState
            .$loaders
            .map { !$0.isEmpty }
            .receive(on: RunLoop.main)
            .assign(to: &$isLoading)
    }
    
    deinit { tasks.forEach { $0.task.cancel() } }
    
    private var tokens: Set<AnyCancellable> = []
    
    func removeObservation(_ token: AnyCancellable?) {
        guard let token else {
            return
        }
        
        tokens.remove(token)
    }
    
    @discardableResult
    func createObservation(_ builder: () -> AnyCancellable) -> AnyCancellable {
        let token = builder()
        tokens.insert(token)
        return token
    }
    
    func addError(_ string: String, operationId: UUID = .init()) {
        self.addError(UIError(message: string, actions: []), operationId: operationId)
    }
    
    func addError(_ error: UIError, operationId: UUID = .init(), onClose: ((UIError) -> Void)? = nil) {
        var error = error
        error.markErrorHandled = { [weak self] in
            self?.asyncState.removeError(id: operationId)
            onClose?(error)
        }
        
        self.asyncState.addError(error, withId: operationId)
    }
    
    /// Allows only __non-throwing__ request. All exceptions must be handling in the request.
    /// Just an alternative to help make sure no throwing path exists, when not needed.
    fileprivate func performAsyncOperationSafe<T>(_ request: @escaping () async -> T, onSuccess: @escaping (T) -> Void) {
        performAsyncOperation(with: .init(onSuccess: onSuccess), request)
    }
    
    fileprivate func performAsyncOperation<T>(_ request: @escaping () async throws -> T, onSuccess: @escaping (T) -> Void) {
        performAsyncOperation(with: .init(onSuccess: onSuccess), request)
    }
    
    fileprivate func performAsyncOperation<T>(_ request: @escaping () async throws -> T, with options: AsyncOptions<T>?) {
        performAsyncOperation(with: options, request)
    }
    
    fileprivate func performAsyncOperation<T>(with options: AsyncOptions<T>? = nil, _ request: @escaping () async throws -> T) {
        
        let options = options ?? .default
        let operationId = options.id
        
        if !options.loadSilently {
            // ApplicationActions.resignFirstResponder()
            asyncState.addLoader(id: options.id)
        }
        
        let task = Task { [weak self] in
            defer { self?
                .tasks
                .removeAll(where: { $0.id == operationId }) }
            
            defer { self?
                .asyncState
                .removeLoader(id: operationId)
            }
            
            do {
                let result = try await request()
                
                await MainActor.run {
                    options.onSuccess?(result)
                    options.onFinally?(result)
                }
            } catch let error {
                
                // if error is OtpInterceptor.CancelError {
                //     return
                // }
                
                if !options.failSilent {
                    let failureHandle = await MainActor.run {
                        options.onFailure?(error)
                        ?? .continueSavingState(defaultErrorMap(_:))
                    }
                    
                    switch failureHandle {
                    case .handledByConsumer: break
                    case .continueSavingState(let transformation, let closure):
                        let error = transformation?(error) ?? defaultErrorMap(error)
                        self?.addError(error, operationId: operationId, onClose: closure)
                    }
                }
                
                await MainActor.run {
                    options.onFinally?(nil)
                }
            }
        }
        
        tasks.append((operationId, task))
    }
}

extension ViewModel {
    
    struct AsyncOptions<T> {
        enum Failure {
            case handledByConsumer
            case continueSavingState(
                _ transformation: ((Error) -> UIError)?,
                errorClosure: ((UIError) -> Void)? = nil)
            
            static var continueSavingState: Failure {
                .continueSavingState(defaultErrorMap(_:))
            }
        }
        
        let id = UUID()
        
        var loadSilently: Bool = false
        var failSilent: Bool = false
        
        var onSuccess: ((T) -> Void)?
        var onFailure: ((Error) -> Failure)?
        var onFinally: ((T?) -> Void)?
        
        static var `default`: AsyncOptions<T> { .init() }
    }
    
}

@MainActor
final class AsyncState: ObservableObject {
    
    struct ErrorState {
        struct Info: Identifiable {
            let value: Error
            let callback: (() -> ())?
            var id: String { String(describing: self) }
        }
    }
    
    @Published
    fileprivate(set)
    var loaders: [UUID] = []
    
    var isLoading: Bool { !loaders.isEmpty }
    
    
    @Published
    fileprivate(set)
    var errors: [(UUID, UIError)] = []
    
    var hasError: Bool { !errors.isEmpty }
    
    func addLoader(id: UUID) {
        loaders.append(id)
    }
    
    func removeLoader(id: UUID) {
        loaders.removeAll(where: { $0 == id })
    }
    
    func addError(_ error: UIError, withId id: UUID) {
        errors.append((id, error))
    }
    
    func removeError(id: UUID) {
        errors.removeAll(where: { $0.0 == id })
    }
}


struct UIError: Hashable {
    
    struct Action: Hashable, Identifiable {
        enum Style: Hashable {
            case `default`
            case secondary
            case destructive
        }
        
        var id: UUID = UUID()
        var title: String
        var style: Style = .default
        var closure: () -> Void
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(title)
            hasher.combine(style)
        }
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    static func == (lhs: UIError, rhs: UIError) -> Bool {
        lhs.title == rhs.title
        && lhs.message == rhs.message
        && lhs.devInfo == rhs.devInfo
        && lhs.actions.count == rhs.actions.count
        && lhs.actions == rhs.actions
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(statusCode)
        hasher.combine(title)
        hasher.combine(message)
        hasher.combine(devInfo)
        hasher.combine(actions)
    }
    
    
    var statusCode: Int? = nil
    var title: String?
    var message: String
    var devInfo: String?
    
    var actions: [Action]
    
    fileprivate(set)
    var markErrorHandled: (() -> Void)!
}

extension UIError {
    init(
        statusCode: Int? = nil,
        title: String?,
        message: String,
        devInfo: String?,
        action: Action,
    ) {
        self.statusCode = statusCode
        self.title = title
        self.message = message
        self.devInfo = devInfo
        self.actions = [action]
    }
}


protocol AsyncOptionsBuilder: ViewModel { }
extension AsyncOptionsBuilder {
    func asyncOptions<T>(_ builder: (Self?) -> AsyncOptions<T>) -> AsyncOptions<T> {
        weak let selfReference: Self? = self
        return builder(selfReference)
    }
}

extension ViewModel: AsyncOptionsBuilder {}


protocol LoadAsyncExecutor: ViewModel {}
extension ViewModel: LoadAsyncExecutor {}

enum LifecycleException: Error {
    case lifecycleDeallocated(_ message: String? = nil)
    
    static func lifecycleDeallocated<P: ViewModel>(_ type: P.Type) -> LifecycleException {
        .lifecycleDeallocated("Used while deallocated: \(type)")
    }
}

extension LoadAsyncExecutor {
    
    func loadAsyncSafe<T>(_ request: @escaping (Self) async -> T, onSuccess: @escaping (T) -> Void) {
        loadAsync(with: .init(onSuccess: onSuccess), request)
    }

//    func loadAsyncSafe<T>(_ request: @escaping (Self) async -> T, with options: AsyncOptions<T>? = nil) {
//        loadAsync(with: options, request)
//    }

    
    func loadAsync<T>(
        _ request: @escaping (Self) async throws -> T,
        onSuccess: @escaping (T) -> Void,
        onFailure: ((Error) -> AsyncOptions<T>.Failure)? = nil
    ) {
        loadAsync(with: .init(
            onSuccess: onSuccess,
            onFailure: { onFailure?($0) ?? .continueSavingState }
        ), request)
    }
    
    func loadAsync<T>(_ request: @escaping (Self) async throws -> T, with options: AsyncOptions<T>?) {
        loadAsync(with: options, request)
    }
    
    func loadAsync<T>(with options: AsyncOptions<T>? = nil, _ request: @escaping (Self) async throws -> T) {
        self.performAsyncOperation(with: options) { [weak self] in
            guard let self else {
                throw LifecycleException.lifecycleDeallocated(Self.self)
            }
            
            return try await request(self)
        }
    }
}

