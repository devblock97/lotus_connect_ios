//
//  KeychainClient.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 12/8/26.
//

import Dependencies
import DependenciesMacros
import Foundation
import Security

@DependencyClient
public struct KeychainClient: Sendable {
    public var saveSession: @Sendable (AuthSession) async throws -> Void
    public var loadSession: @Sendable () async throws -> AuthSession?
    public var clearSession: @Sendable () async throws -> Void
}

extension KeychainClient: DependencyKey {
    public static let liveValue: KeychainClient = {
        let service = "lotusconnect.session"
        let account = "currentUserSession"
        
        return KeychainClient(
            saveSession: { session in
                    let data = try JSONEncoder().encode(session)
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: service,
                    kSecAttrAccount as String: account,
                    kSecValueData as String: data
                ]
                
                // Delete existing item before writing
                SecItemDelete(query as CFDictionary)
                SecItemAdd(query as CFDictionary, nil)
            },
            loadSession: {
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: service,
                    kSecAttrAccount as String: account,
                    kSecReturnData as String: true,
                    kSecMatchLimit as String: kSecMatchLimitOne
                ]
                
                var dataTypeRef: AnyObject?
                let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
                
                guard status == errSecSuccess, let data = dataTypeRef as? Data else {
                    return nil
                }
                
                return try? JSONDecoder().decode(AuthSession.self, from: data)
            },
            clearSession: {
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: service,
                    kSecAttrAccount as String: account
                ]
                SecItemDelete(query as CFDictionary)
            }
        )
    }()
}

extension DependencyValues {
    public var keychain: KeychainClient {
        get { self[KeychainClient.self] }
        set { self[KeychainClient.self] = newValue }
    }
}
