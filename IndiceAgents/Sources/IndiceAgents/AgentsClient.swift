//
//  AgentsClient.swift
//  IndiceAgents
//
//  Created by Nikolas Konstantakopoulos on 7/7/26.
//

import Foundation
import AgentsModels
import NetworkClient
import IdentityClient


public final class AgentsClient: @unchecked Sendable {
    
    public struct Configuration {
        let authURL: URL
        let agentsURL: URL
        
        let clientID: String
        let clientSecret: String?
        
        public init(authURL: URL, agentsURL: URL, clientID: String, clientSecret: String?) {
            self.authURL = authURL
            self.agentsURL = agentsURL
            self.clientID = clientID
            self.clientSecret = clientSecret
        }
    }
    
    private let servicesLock = ReentrantSectionLock()
    private let identityClientURLS: IdentityClient::Client.Urls = .init(commonForRedirectScheme: "indice.mobile")
    
    private let configuration: Configuration
    

    /// Opt into the administrative document scope only when the identity client
    /// registration and the signed-in user are allowed to ingest/clear documents.
    public init(requestIngestionScope: Bool = false, configuration: Configuration) {
        self.configuration = configuration
        self.requestIngestionScope = requestIngestionScope
    }
    
    
    
    private let requestIngestionScope: Bool
    private let tokenStorage = PersistentTokenStorage()
    private var identityInstance: IdentityClient!
    internal var identityClient: IdentityClient {
        servicesLock.withLock {
            if identityInstance == nil {
                let clientBuilder: @Sendable () -> NetworkClient = { [unowned self] in
                    let refreshInterceptor = RefreshTokenInterceptor(auth:   { self.identityClient.authService })
                    let headersInterceptor = HeadersInterceptor     (tokens: { self.identityClient.tokens      })
                    
                    return NetworkClient(
                        interceptors       : [refreshInterceptor, headersInterceptor],
                        decoder: AgentsResponseDecoder().handlingOptionalResponses,
                        logging: .default)
                }
                
                identityInstance = IdentityClient(
                    client: .init(
                        id: configuration.clientID,
                        secret: configuration.clientSecret,
                        userScope: .defaultUserScopes + ["agents", "chat"] + (requestIngestionScope ? ["ingest"] : []),
                        appScope: [.identity],
                        urls: identityClientURLS),
                    configuration: .init(baseUrl: self.configuration.authURL),
                    currentDeviceInfoProvider: CurrentDeviceInfo(),
                    valueStorage: UserDefaults.standard,
                    tokenStorage: tokenStorage,
                    networkOptions: .init(
                        errorParser: .identityErrorParser,
                        processorBuilder: clientBuilder))
            }
            return identityInstance!
        }
    }
    
    var networkClient: NetworkClient {
        identityClient.requestProcessor as! NetworkClient
    }
    
    
    private var chatsServiceInstance: ChatService?
    public var chatsService: ChatService {
        servicesLock.withLock {
            if let chatsServiceInstance { return chatsServiceInstance }
            let identity = identityClient
            let storage = tokenStorage
            let authorization = StreamAuthorization(
                credentials: { storage.streamCredentials },
                refresh: { try await identity.authService.refreshTokens() })
            let service = ChatService(repository: .init(endpoint: self.configuration.agentsURL, client: networkClient,
                                                        streamAuthorization: authorization))
            chatsServiceInstance = service
            return service
        }
    }

    private var agentsServiceInstance: AgentsService?
    public var agentsService: AgentsService {
        servicesLock.withLock {
            if let agentsServiceInstance { return agentsServiceInstance }
            let service = AgentsService(repository: .init(endpoint: self.configuration.agentsURL, client: networkClient))
            agentsServiceInstance = service
            return service
        }
    }

    private var profileServiceInstance: ProfileService?
    public var profileService: ProfileService {
        servicesLock.withLock {
            if let profileServiceInstance { return profileServiceInstance }
            let service = ProfileService(repository: .init(endpoint: self.configuration.agentsURL, client: networkClient))
            profileServiceInstance = service
            return service
        }
    }

    private var documentsServiceInstance: DocumentsService?
    public var documentsService: DocumentsService {
        servicesLock.withLock {
            if let documentsServiceInstance { return documentsServiceInstance }
            let service = DocumentsService(repository: .init(endpoint: self.configuration.agentsURL, client: networkClient))
            documentsServiceInstance = service
            return service
        }
    }

    private var sourcesServiceInstance: SourcesService?
    public var sourcesService: SourcesService {
        servicesLock.withLock {
            if let sourcesServiceInstance { return sourcesServiceInstance }
            let service = SourcesService(repository: .init(endpoint: self.configuration.agentsURL, client: networkClient))
            sourcesServiceInstance = service
            return service
        }
    }

    public var canQuickLogin: Bool {
        tokenStorage.refreshToken != nil
    }
    
    public func refreshLogin() async throws {
        try await identityClient.authService.refreshTokens()
    }
    
    public func createLoginURL(for pkce: PKCE) -> URL {
        try! identityClient
            .authService
            .authorizationUrl(withPkce: pkce)
            .appending(queryItems: [.init(name: "acr_values", value: AcrValues.microsoft.value)])
    }
    
    public func login(code: String, verifier: String) async throws {
        try await identityClient.authService.login(withGrant: .authCode(
            code: code,
            codeVerifier: verifier,
            redirectUri: identityClientURLS.authorization!))
    }
}

typealias RequestInterceptor = NetworkClient.Interceptor

extension NetworkClient: @retroactive RequestProcessor {
    public func process(request: URLRequest) async throws {
        try await self.fetch(request: request).item
    }
    
    public func process<T>(request: URLRequest) async throws -> T where T : Decodable, T : Sendable {
        try await self.fetch(request: request).item
    }
}

final class RefreshTokenInterceptor: RequestInterceptor {
    
    private let auth: @Sendable () -> IdentityClient.Authorization?
    
    init(auth: @escaping @Sendable () -> IdentityClient.Authorization?) {
        self.auth = auth
    }
    
    private func process<T: Sendable>(request: URLRequest, next: @concurrent @Sendable (URLRequest) async throws -> T) async throws -> T {
        do {
            return try await next(request)
        } catch {
            guard
                (error as? NetworkClient.Error)?.statusCode == 401,
                let authService = self.auth()
            else { throw error }
            
            try await authService.refreshTokens()
            
            return try await next(request)
        }
    }
    
    func process(_ request: URLRequest, next: @concurrent @Sendable (URLRequest) async throws -> NetworkClient.ChainResult) async throws -> NetworkClient.ChainResult {
        try await self.process(request: request, next: next)
    }
    
}


final class HeadersInterceptor: RequestInterceptor {
    
    private let tokens: @Sendable () -> IdentityClient::TokenStorageAccessor?
    
    init(tokens: @Sendable @escaping () -> IdentityClient::TokenStorageAccessor?) {
        self.tokens = tokens
    }
    
    private func process<T: Sendable>(request: URLRequest, next: @concurrent @Sendable (URLRequest) async throws -> T) async throws -> T {
        if let authorization = tokens()?.authorization {
            try await next(request.setting(header: .authorisation(auth: authorization)))
        } else {
            try await next(request)
        }
    }
    
    func process(_ request: URLRequest, next: @concurrent @Sendable (URLRequest) async throws -> NetworkClient.ChainResult) async throws -> NetworkClient.ChainResult {
        try await self.process(request: request, next: next)
    }
    
    
}



private final class CurrentDeviceInfo: IdentityClient::CurrentDeviceInfoProvider {
    let name: String = "dummy"
    let model: String = "dummy"
    let osVersion: String = "dummy"
}


public extension Decodable {
    
    static func fromJson(_ value: String) throws -> Self? {
        guard let data = value.data(using: .utf8) else {
            return nil
        }
        
        return try fromJson(data)
    }

    static func fromJson(_ value: Data) throws -> Self {
        try APIJSON.decoder().decode(Self.self, from: value)
    }
}



public extension Encodable {
    
    func toJson() -> Data? {
        try? APIJSON.encoder().encode(self)
    }

    func toJsonString() -> String? {
        guard let value = toJson() else {
            return nil
        }
        
        return .init(data: value, encoding: .utf8)
    }
}


extension ErrorParser {
    static let identityErrorParser: ErrorParser = {
        .init(map: { error in
            guard case .apiError(let response, let data) = (error as? NetworkClient.Error) else {
                return nil
            }
            
            return .init(statusCode: response.statusCode, details: try? .fromJson(data))
        })
    }()
}



/// IdentityClient and stream authorization can read credentials concurrently.
/// The lock protects whole token snapshots, not just individual property writes.
final class PersistentTokenStorage: TokenStorage, @unchecked Sendable {
    private let lock = ReentrantSectionLock()
    private var storedIDToken: String?
    private var storedAccessToken: TokenType?
    private var storedTokenType: String?
    private var expirationDate: Date?

    var idToken: String? { lock.withLock { storedIDToken } }
    var accessToken: TokenType? { lock.withLock { storedAccessToken } }
    var tokenType: String? { lock.withLock { storedTokenType } }
    var refreshToken: TokenType? { lock.withLock { KeychainItem.refreshToken.map { .refreshToken(value: $0) } } }

    var streamCredentials: (header: String?, expired: Bool) {
        lock.withLock {
            let header = storedAccessToken.flatMap { token in storedTokenType.map { "\($0) \(token.value)" } }
            return (header, expirationDate.map { $0 < .now } ?? false)
        }
    }

    func parse(_ response: TokenResponse) {
        lock.withLock {
            storedIDToken = response.id_token
            storedAccessToken = .accessToken(value: response.access_token)
            storedTokenType = response.token_type
            expirationDate = .now.addingTimeInterval(TimeInterval(response.expires_in - 5))
            // A refresh response may omit an unchanged refresh token.
            if let refresh = response.refresh_token { KeychainItem.refreshToken = refresh }
        }
    }

    func clearTokens() {
        lock.withLock {
            storedIDToken = nil
            storedAccessToken = nil
            storedTokenType = nil
            expirationDate = nil
            KeychainItem.refreshToken = nil
        }
    }
}

struct KeychainItem {
    // MARK: Types
    
    enum KeychainError: Error {
        case noPassword
        case unexpectedPasswordData
        case unexpectedItemData
        case unhandledError
    }
    
    // MARK: Properties
    
    let service: String
    
    private(set) var account: String
    
    let accessGroup: String?
    
    // MARK: Initialisation
    
    init(service: String, account: String, accessGroup: String? = nil) {
        self.service = service
        self.account = account
        self.accessGroup = accessGroup
    }
    
    // MARK: Keychain access
    
    func readItem() throws -> String {
        /*
         Build a query to find the item that matches the service, account and
         access group.
         */
        var query = KeychainItem.keychainQuery(withService: service, account: account, accessGroup: accessGroup)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnAttributes as String] = kCFBooleanTrue
        query[kSecReturnData as String] = kCFBooleanTrue
        
        // Try to fetch the existing keychain item that matches the query.
        var queryResult: AnyObject?
        let status = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }
        
        // Check the return status and throw an error if appropriate.
        guard status != errSecItemNotFound else { throw KeychainError.noPassword }
        guard status == noErr else { throw KeychainError.unhandledError }
        
        // Parse the password string from the query result.
        guard let existingItem = queryResult as? [String: AnyObject],
              let passwordData = existingItem[kSecValueData as String] as? Data,
              let password = String(data: passwordData, encoding: String.Encoding.utf8)
        else {
            throw KeychainError.unexpectedPasswordData
        }
        
        return password
    }
    
    func saveItem(_ password: String) throws {
        // Encode the password into a Data object.
        let encodedPassword = password.data(using: String.Encoding.utf8)!
        
        do {
            // Check for an existing item in the keychain.
            try _ = readItem()
            
            // Update the existing item with the new password.
            var attributesToUpdate = [String: AnyObject]()
            attributesToUpdate[kSecValueData as String] = encodedPassword as AnyObject?
            
            let query = KeychainItem.keychainQuery(withService: service, account: account, accessGroup: accessGroup)
            let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            
            // Throw an error if an unexpected status was returned.
            guard status == noErr else { throw KeychainError.unhandledError }
        } catch KeychainError.noPassword {
            /*
             No password was found in the keychain. Create a dictionary to save
             as a new keychain item.
             */
            var newItem = KeychainItem.keychainQuery(withService: service, account: account, accessGroup: accessGroup)
            newItem[kSecValueData as String] = encodedPassword as AnyObject?
            
            // Add a the new item to the keychain.
            let status = SecItemAdd(newItem as CFDictionary, nil)
            
            // Throw an error if an unexpected status was returned.
            guard status == noErr else { throw KeychainError.unhandledError }
        }
    }
    
    func deleteItem() throws {
        // Delete the existing item from the keychain.
        let query = KeychainItem.keychainQuery(withService: service, account: account, accessGroup: accessGroup)
        let status = SecItemDelete(query as CFDictionary)
        
        // Throw an error if an unexpected status was returned.
        guard status == noErr || status == errSecItemNotFound else { throw KeychainError.unhandledError }
    }
    
    // MARK: Convenience
    
    private static func keychainQuery(withService service: String, account: String? = nil, accessGroup: String? = nil) -> [String: AnyObject] {
        var query = [String: AnyObject]()
        query[kSecClass as String] = kSecClassGenericPassword
        query[kSecAttrService as String] = service as AnyObject?
        
        if let account = account {
            query[kSecAttrAccount as String] = account as AnyObject?
        }
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup as AnyObject?
        }
        
        return query
    }
    
    fileprivate static func saveInKeychain(_ value: String?, for identifier: String) {
        do {
            if let value = value {
                try KeychainItem(service: Bundle.main.bundleIdentifier!, account: identifier).saveItem(value)
            } else {
                try KeychainItem(service: Bundle.main.bundleIdentifier!, account: identifier).deleteItem()
            }
        } catch {
            #if DEBUG
            print("Unable to \(value == nil ? "delete" : "save") userIdentifier \(identifier) to keychain.")
            #endif
        }
    }
}

extension KeychainItem {
    
    private enum Key: String {
        case deviceId     = "deviceId"
        case refreshToken = "refreshTokenID"
        case pnsHandle    = "notificationsTokenID"
    }
    
    private static func saveInKeychain(_ value: String?, for key: Key) {
        saveInKeychain(value, for: key.rawValue)
    }
    
    private static func getValue(for key: Key) -> String? {
        try? KeychainItem(service: Bundle.main.bundleIdentifier!, account: key.rawValue).readItem()
    }
    
    static var refreshToken: String? {
        get { getValue(for: .refreshToken) }
        set { saveInKeychain(newValue, for: .refreshToken) }
    }
    
    static var pnsHandle: String? {
        get { getValue(for: .pnsHandle) }
        set { saveInKeychain(newValue, for: .pnsHandle) }
    }
    
    static var deviceId: String? {
        get { getValue(for: .deviceId) }
        set { saveInKeychain(newValue, for: .deviceId) }
    }
    
}

