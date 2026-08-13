//
//  ConversationClient.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 13/8/26.
//

import Dependencies
import DependenciesMacros
import Foundation

nonisolated private struct CreateConversationDTO: Encodable, Sendable {
    let peerId: String
    let title: String
}

nonisolated private struct ConversationResponseDTO: Decodable, Sendable {
    let id: String
    let title: String?
    let createdAt: String?
    let updatedAt: String?
    let isPinned: Bool?
    let isFavourite: Bool?
    let modelName: String?
    let draftMessage: String?
    let isGroup: Bool?
    let isUserToUser: Bool?
    let peerId: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isPinned = "is_pinned"
        case isFavourite = "is_favourite"
        case modelName = "model_name"
        case draftMessage = "draft_message"
        case isGroup = "is_group"
        case isUserToUser = "is_user_to_user"
        case peerId = "peer_id"
        
    }
    
    func toDomain() -> Conversation {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let created = formatter.date(from: createdAt ?? "") ?? ISO8601DateFormatter().date(from: createdAt ?? "") ?? Date()
        let updated = formatter.date(from: updatedAt ?? "") ?? ISO8601DateFormatter().date(from: updatedAt ?? "") ?? Date()
        
        let groupFlag = isGroup ?? false
        let resolvedIsUserToUser = isUserToUser ?? (!groupFlag)
        
        return Conversation(
            id: id,
            title: title ?? "",
            createdAt: created,
            updatedAt: updated,
            isPinned: isPinned ?? false,
            isFavourite: isFavourite ?? false,
            modelName: modelName ?? "gemini-1.5-flash",
            draftMessage: draftMessage,
            systemPrompt: nil,
            isUserToUser: isUserToUser ?? false,
            peerId: peerId ?? ""
        )
    }
}

nonisolated private struct CreatePrivateDTO: Encodable, Sendable {
    let friendId: String
}

nonisolated private struct EmptyResponseDTO: Decodable, Sendable {}

@DependencyClient
public struct ConversationClient: Sendable {
    public var fetchConversations: @Sendable () async throws -> [Conversation]
    public var createConversation: @Sendable (_ peerId: String, _ title: String) async throws -> Conversation
    public var deleteConversation: @Sendable (_ id: String) async throws -> Void
    public var togglePin: @Sendable (_ id: String, _ isPinned: Bool) async throws -> Void
}

extension ConversationClient: DependencyKey {
    public static let liveValue: ConversationClient = {
        @Dependency(\.httpClient) var httpClient
        
        return ConversationClient(
            fetchConversations: {
                let dtos: [ConversationResponseDTO] = try await httpClient.request("/chats", .get, nil, nil)
                return dtos.map { $0.toDomain() }
            },
            createConversation: { peerId, title in
                let dto = CreateConversationDTO(peerId: peerId, title: title)
                return try await httpClient.request("/chats/private", .post, dto, nil)
            },
            deleteConversation: { id in
                let _: EmptyResponseDTO = try await httpClient.request("/chats/\(id)", .delete, nil, nil)
            },
            togglePin: { id, isPinned in
                let _: EmptyResponseDTO = try await httpClient.request("/chats/\(id)/pin?isPinned=\(isPinned)", .put, nil, nil)
            }
        )

    }()
}

extension DependencyValues {
    public var conversationClient: ConversationClient {
        get { self[ConversationClient.self] }
        set { self[ConversationClient.self] = newValue }
    }
}
