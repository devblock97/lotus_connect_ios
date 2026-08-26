//
//  ContactsClient.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 26/8/26.
//

import Dependencies
import Foundation
import DependenciesMacros

nonisolated private struct EmptyDTO: Decodable, Sendable {
    
}

nonisolated private struct FriendRequestDTO: Encodable, Sendable {
    let targetUserId: String
    
    enum CodingKeys: String, CodingKey {
        case targetUserId = "friendId"
    }
}

@DependencyClient
public struct ContactsClient: Sendable {
    public var fetchContacts: @Sendable () async throws -> [User]
    public var fetchPendingRequests: @Sendable () async throws -> [User]
    public var removeFriend: @Sendable (_ userId: String) async throws -> Void
    public var acceptFriendRequest: @Sendable (_ userId: String) async throws -> Void
    public var rejectFriendRequest: @Sendable (_ userId: String) async throws -> Void
    public var searchUsers: @Sendable (_ query: String) async throws -> [User]
    public var sendFriendRequest: @Sendable (_ userId: String) async throws -> Void
}

extension ContactsClient: DependencyKey {
    public static let liveValue: ContactsClient = {
        @Dependency(\.httpClient) var httpClient
        
        return ContactsClient(
            fetchContacts: {
                let users: [User] = try await httpClient.request("/users/friends", .get, nil, nil)
                return users
            },
            fetchPendingRequests: {
                let pending: [User] = try await httpClient.request("/users/friends/requests", .get, nil, nil)
                return pending
            },
            removeFriend: { userId in
                let _: EmptyDTO = try await httpClient.request("/users/friends/\(userId)", .delete, nil, nil)
            },
            acceptFriendRequest: { userId in
                let dto = FriendRequestDTO(targetUserId: userId)
                let _: EmptyDTO = try await httpClient.request("/users/friends/accept", .post, dto, nil)
            },
            rejectFriendRequest: { userId in
                    let dto = FriendRequestDTO(targetUserId: userId)
                let _: EmptyDTO = try await httpClient.request("/users/friends/reject", .post, dto, nil)
            },
            searchUsers: { query in
                let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
                let results: [User] = try await httpClient.request("/users/search?q=\(encodedQuery)", .get, nil, nil)
                return results
            },
            sendFriendRequest: { userId in
                let dto = FriendRequestDTO(targetUserId: userId)
                let _: EmptyDTO = try await httpClient.request("/users/friends/request", .post, dto, nil)
            }
        )
    }()
}

extension DependencyValues {
    public var contactClient: ContactsClient {
        get { self[ContactsClient.self] }
        set { self[ContactsClient.self] = newValue }
    }
}
