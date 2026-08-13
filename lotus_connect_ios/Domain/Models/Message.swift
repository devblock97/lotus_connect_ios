//
//  Message.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 13/8/26.
//

import Foundation

nonisolated public enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
    
    public var isUser: Bool { self == .user }
    public var isAssistant: Bool { self == .assistant }
    public var isSystem: Bool { self == .system }
}

/// Tracks delivery and streaming lifecycle status of a message.
nonisolated public enum MessageStatus: String, Codable, Sendable {
    case sending
    case sent
    case read
    case streaming
    case error
}


nonisolated public struct Message: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let conversationId: String
    public var role: MessageRole
    public var content: String
    public var timestamp: Date
    public var isError: Bool
    public var status: MessageStatus
    public var replyToId: String?
    
    public init (
        id: String = UUID().uuidString,
        conversationId: String,
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        isError: Bool = false,
        status: MessageStatus = .sent,
        replyToId: String? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isError = isError
        self.status = status
        self.replyToId = replyToId
    }
}
