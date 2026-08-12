//
//  AuthClient.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 12/8/26.
//
import Dependencies
import DependenciesMacros
import Foundation

nonisolated private struct LoginRequestDTO: Encodable, Sendable {
    let email: String
    let password: String
}

nonisolated private struct LoginResponseDTO: Decodable, Sendable {
    let user: User
    let accessToken: String
    let refreshToken: String
}

nonisolated private struct RegisterRequestDTO: Encodable, Sendable {
    let username: String
    let email: String
    let password: String
    let fullName: String?
}

nonisolated private struct LogoutRequestDTO: Encodable, Sendable {
    let refreshToken: String
}

nonisolated private struct EmptyResponseDTO: Decodable, Sendable {}

public struct AuthSession: Equatable, Sendable, Encodable, Decodable {
    public let user: User
    public let accessToken: String
    public let refreshToken: String
    
    public init(user: User, accessToken: String, refreshToken: String) {
        self.user = user
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}

@DependencyClient
public struct AuthClient: Sendable {
    public var login: @Sendable (_ email: String, _ password: String) async throws -> AuthSession
    public var register: @Sendable (_ username: String, _ email: String, _ password: String, _ fullName: String?) async throws -> Void
    public var logout: @Sendable (_ refreshToken: String) async throws -> Void
    public var restoreSession: @Sendable () async throws -> AuthSession?
}

extension AuthClient: DependencyKey {
    public static let liveValue: AuthClient = {
        @Dependency(\.httpClient) var httpClient
        @Dependency(KeychainClient.self) var keychainClient
        
        return Self(
            login: { email, password in
                let dto = LoginRequestDTO(email: email, password: password)
                let response: LoginResponseDTO = try await httpClient.request(
                    "/auth/login",
                    .post,
                    dto,
                    nil
                )
                
                let session = AuthSession(
                    user: response.user,
                    accessToken: response.accessToken,
                    refreshToken: response.refreshToken
                )
                
                // Save session securely to Keychain
                try await keychainClient.saveSession(session)
                
                return session
            },
            register: { username, email, password, fullName in
                    let dto = RegisterRequestDTO(
                        username: username,
                        email: email,
                        password: password,
                        fullName: fullName
                    )
                
                let _: EmptyResponseDTO = try await httpClient.request(
                    "/auth/register",
                    .post,
                    dto,
                    nil
                )
            },
            logout: { refreshToken in
                let dto = LogoutRequestDTO(refreshToken: refreshToken)
                let _: EmptyResponseDTO = try await httpClient.request(
                    "/auth/logout",
                    .post,
                    dto,
                    nil
                )
                
                // Clear session from Keychain on logout
                try await keychainClient.clearSession()
            },
            restoreSession: {
                // Auto-restore session from Keychain on app boot
                try await keychainClient.loadSession()
            }
        )
    }()
}
extension DependencyValues {
    public var authClient: AuthClient {
        get { self[AuthClient.self] }
        set {self[AuthClient.self] = newValue}
    }
}
