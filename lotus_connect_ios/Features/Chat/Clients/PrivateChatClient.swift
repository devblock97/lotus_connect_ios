//
//  PrivateChatClient.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 13/8/26.
//

import Dependencies
import DependenciesMacros
import Foundation

nonisolated private struct MediaItemDTO: Decodable, Sendable {
    let url: String
    let thumbnailUrl: String?
    let fileName: String?
    let fileSize: Int?
    let mimeType: String?
    let duration: Double?
    let width: Double?
    let height: Double?
    
    func toDomain() -> MediaItem {
        MediaItem(
            url: url,
            thumbnailUrl: thumbnailUrl,
            fileName: fileName,
            fileSize: fileSize,
            mimetype: mimeType,
            duration: duration,
            width: width,
            height: height
        )
    }
}

nonisolated private struct MessageReactionDTO: Decodable, Sendable {
    let reaction: String
    let count: Int
    let users: [String]
    
    func toDomain() -> MessageReaction {
        MessageReaction(reaction: reaction, count: count, users: users)
    }
}

nonisolated private struct MessageResponseDTO: Decodable, Sendable {
    let id: String
    let conversationId: String
    let senderId: String?
    let content: String?
    let messageType: String
    let replyToId: String?
    let mediaUrl: String?
    let thumbnailUrl: String?
    let fileSize: Int?
    let fileName: String?
    let mimeType: String?
    let duration: Double?
    let mediaItems: [MediaItemDTO]?
    let reactions: [MessageReactionDTO]?
    let isEdited: Bool?
    let createdAt: String
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, content, duration
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case messageType = "message_type"
        case replyToId = "reply_to_id"
        case isEdited = "is_edited"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case thumbnailUrl = "thumbnail_url"
        case mediaUrl = "media_url"
        case fileSize = "file_size"
        case fileName = "file_name"
        case mimeType = "mime_type"
        case mediaItems = "media_items" // Mapped to snake_case from JSON
        case reactions                  // Added missing key (width & height removed)
    }
    
    func toDomain(currentUserId: String) -> Message {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.date(from: createdAt)
            ?? ISO8601DateFormatter().date(from: createdAt)
            ?? Date()
        
        let role: MessageRole = (senderId == currentUserId) ? .user : .assistant
        
        return Message(
            id: id,
            conversationId: conversationId,
            role: role,
            content: content ?? "",
            timestamp: timestamp,
            isError: false,
            status: .sent,
            replyToId: replyToId,
            messageType: messageType,
            mediaUrl: mediaUrl,
            thumbnailUrl: thumbnailUrl,
            fileSize: fileSize,
            fileName: fileName,
            mimeType: mimeType,
            duration: duration,
            isEdited: isEdited ?? false,
            reactions: reactions?.map { $0.toDomain() } ?? [],
            mediasItems: mediaItems?.map { $0.toDomain() } ?? [],
        )
    }
}

nonisolated private struct SendMessageRequestDTO: Encodable, Sendable {
    let content: String
    let replyToId: String?
    
    enum CodingKeys: String, CodingKey {
        case content
        case replyToId = "reply_to_id"
    }
}

nonisolated private struct UpdateMessageRequestDTO: Encodable, Sendable {
    let content: String
}

nonisolated private struct EmptyResponseDTO: Decodable, Sendable {}

@DependencyClient
public struct PrivateChatClient: Sendable {
    public var fetchMessages: @Sendable (_ conversationId: String) async throws -> [Message]
    public var sendMessage: @Sendable (_ conversationId: String, _ content: String, _ replyToId: String?) async throws -> Message
    public var updateMessage: @Sendable (_ messageId: String, _ content: String) async throws -> Void
    public var deleteMessage: @Sendable (_ messageId: String) async throws -> Void
    public var sendTypingStatus: @Sendable (_ recipientId: String, _ isTyping: Bool) async throws -> Void
}

extension PrivateChatClient: DependencyKey {
    public static let liveValue: PrivateChatClient = {
        @Dependency(\.httpClient) var httpClient
        @Dependency(KeychainClient.self) var keychainClient
        
        return PrivateChatClient(
            fetchMessages: { conversationId in
                // Load current User ID for role resolution
                let currentUserId = (try? await keychainClient.loadSession())?.user.id ?? ""
                
                let dtos: [MessageResponseDTO] = try await httpClient.request(
                    "/chats/\(conversationId)/messages?litmit=100",
                    .get,
                    nil,
                    nil,
                )
                
                // Reverse so oldest messages are at top, newest at bottom
                return dtos.reversed().map { $0.toDomain(currentUserId: currentUserId) }
            },
            sendMessage: { conversationId, content, replyToId in
                let currentUserId = (try? await keychainClient.loadSession())?.user.id ?? ""
                let dto = SendMessageRequestDTO(content: content, replyToId: replyToId)
                
                let response: MessageResponseDTO = try await httpClient.request(
                    "/chats/\(conversationId)/messages",
                    .post,
                    dto,
                    nil
                )
                
                return response.toDomain(currentUserId: currentUserId)
            },
            updateMessage: { messageId, content in
                let dto = UpdateMessageRequestDTO(content: content)
                let _: EmptyResponseDTO = try await httpClient.request("/chats/messages/\(messageId)", .put, dto, nil)
            },
            deleteMessage: { messageId in
                let _: EmptyResponseDTO = try await httpClient.request("/chats/messages/\(messageId)", .delete, nil, nil)
            },
            sendTypingStatus: { recipientId, isTyping in
                    
            }
        )
    } ()
}

extension DependencyValues {
    public var privateChatClient: PrivateChatClient {
        get { self[PrivateChatClient.self] }
        set { self[PrivateChatClient.self] = newValue }
    }
}
