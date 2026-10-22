//
//  PersistentTokenStorage.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 29/9/26.
//

import Foundation
import IdentityClient
import NetworkClient
import AgentsModels
import AgentsClient


public extension Decodable {
    
    nonisolated
    static func fromJson(_ value: String) throws -> Self? {
        guard let data = value.data(using: .utf8) else {
            return nil
        }
        
        return try fromJson(data)
    }

    nonisolated
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
    var refreshToken: TokenType? { lock.withLock {
        KeychainItem.refreshToken.map { .refreshToken(value: $0) }
    } }

    func parse(_ response: TokenResponse) {
        lock.withLock {
            storedIDToken = response.id_token
            storedAccessToken = .accessToken(value: response.access_token)
            storedTokenType = response.token_type
            expirationDate = .now.addingTimeInterval(TimeInterval(response.expires_in - 5))
            
            // A refresh response may omit an unchanged refresh token.
            if let refresh = response.refresh_token {
                KeychainItem.refreshToken = refresh
            }
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

nonisolated struct KeychainItem {
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

nonisolated extension KeychainItem {
    
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

