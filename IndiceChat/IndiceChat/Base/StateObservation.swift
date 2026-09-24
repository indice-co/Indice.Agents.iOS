//
//  StateObservation.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 9/7/26.
//


extension View {
    
    /// Propagate a `ViewModel`'s loading or error state, up the hierarchy chain
    /// Some ancestor `View` (generally a `FlowNavigationView`) should
    /// have the `.applyLoadingState()` and `.presentPropagatedErrors()` modifiers in order to actually present the states.
    func observeState(on stateHolder: ViewModel) -> some View {
        self
            .propagateLoadingState(stateHolder.isLoading)
            .propagateErrors(stateHolder.errors)
    }
    
}


// MARK: - GUTS

import SwiftUI


// MARK: Loading

private struct LoadingStatePropagatorKey: PreferenceKey {
    static var defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

private struct LoadingStatePropagatingModifier: ViewModifier {
    
    var backgroundIntensity: CGFloat = 1
    
    @State private var isLoading = false
    @State private var cancelable: Task<(), Never>? = nil
    
    private var animation: Animation {
        .easeInOut(duration: isLoading ? 0.15 : 0.25)
    }
    
    func body(content: Content) -> some View {
        content
            .blur(radius: isLoading ? 12 : 0)
            .overlay {
                Group {
                    if isLoading {
                        Color
                            .gray.opacity(0.25)
                            .ignoresSafeArea(.all)
                            .overlay { ProgressView() }
                    }
                }
                .animation(animation, value: isLoading)
            }
            .onPreferenceChange(LoadingStatePropagatorKey.self, perform: { value in
                if value {
                    cancelable?.cancel()
                    cancelable = nil
                    isLoading = true
                } else if isLoading {
                    cancelable?.cancel()
                    cancelable = Task(operation: {
                        try? await Task.sleep(
                            for: .milliseconds(750))
                        
                        if !Task.isCancelled {
                            await MainActor.run {
                                isLoading = false
                                cancelable = nil
                            }
                        }
                    })
                }
            })
            .onDisappear {
                cancelable?.cancel()
                cancelable = nil
            }
    }
}


extension View {
    func propagateLoadingState(_ state: Bool) -> some View {
        self
            .preference(
                key: LoadingStatePropagatorKey.self,
                value: state)
    }
    
    func applyLoadingState() -> some View {
        self.modifier(LoadingStatePropagatingModifier())
    }
}


// MARK: Errors

private struct ErrorStatePropagatorKey: PreferenceKey {
    static var defaultValue = [UIError]()
    static func reduce(value: inout [UIError], nextValue: () -> [UIError]) {
        value = value + nextValue()
    }
}



extension View {
    func propagateErrors(_ state: [UIError]) -> some View {
        self.preference(
            key: ErrorStatePropagatorKey.self,
            value: state)
    }
}

private struct ErrorStateViewModifier: ViewModifier {
    
    @State private var currentError: UIError? = nil
        
    func body(content: Content) -> some View {
        content
            .onPreferenceChange(ErrorStatePropagatorKey.self) { errors in
                currentError = errors.currentOrNext(self.currentError)
            }
            .transformPreference(ErrorStatePropagatorKey.self, { $0 = [] })
            .alert(
                currentError?.title ?? "Oops..",
                item: $currentError,
                actions: { error in
                    if error.actions.isEmpty {
                        Button(
                            action: error.markErrorHandled,
                            label: { Text("Close") }
                        )
                    } else {
                        ForEach(error.actions) { action in
                            Button(
                                role: action.buttonRole,
                                action: {
                                    error.markErrorHandled()
                                    action.closure()
                                },
                                label: { Text(action.title) })
                        }
                    }
                },
                message: { error in
                    Text(error.message)
                    
                    if let devInfo = error.devInfo {
                        Text(devInfo)
                            .font(.caption2)
                    }
                })
    }
    
    
}


extension View {
    
    func presentPropagatedErrors() -> some View {
        modifier(ErrorStateViewModifier())
    }
    
}


private extension Array where Element == UIError {
    func currentOrNext(_ current: UIError?) -> UIError? {
        guard let current else {
            return self.first
        }
        
        if self.contains(current) {
            return current
        }
        
        return self.first
    }
}

private extension UIError.Action {
    var buttonRole: ButtonRole? {
        switch self.style {
        case .destructive: .destructive
        case .secondary: .cancel
        case .default: nil
        }
    }
}

