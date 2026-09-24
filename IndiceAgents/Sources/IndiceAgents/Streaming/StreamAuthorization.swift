import Foundation

/// Authentication belongs to the Agents integration, not the temporary transport.
/// A separate actor coalesces refreshes when multiple conversations start together.
actor StreamAuthorization {
    private let credentials: @Sendable () -> (header: String?, expired: Bool)
    private let refresh: @Sendable () async throws -> Void
    private var refreshTask: Task<Void, Error>?

    init(credentials: @escaping @Sendable () -> (header: String?, expired: Bool),
         refresh: @escaping @Sendable () async throws -> Void) {
        self.credentials = credentials
        self.refresh = refresh
    }

    func authorize(_ request: URLRequest, rejectedHeader: String? = nil) async throws -> URLRequest {
        try Task.checkCancellation()
        let current = credentials()
        // An initial 401 can race with another stream's successful refresh. If
        // credentials already changed, use them instead of refreshing a second time.
        if current.expired || (rejectedHeader != nil && current.header == rejectedHeader) {
            if let refreshTask {
                try await refreshTask.value
            } else {
                let task = Task { try await refresh() }
                refreshTask = task
                defer { refreshTask = nil }
                try await task.value
            }
        } else if let refreshTask {
            try await refreshTask.value
        }
        try Task.checkCancellation()
        guard let header = credentials().header else { throw AgentsError.notSignedIn }
        var authorized = request
        authorized.setValue(header, forHTTPHeaderField: "Authorization")
        return authorized
    }
}
