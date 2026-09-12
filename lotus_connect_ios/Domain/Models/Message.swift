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

nonisolated public struct MediaItem: Identifiable, Equatable, Codable, Sendable {
    public var id: String { url }
    public let url: String
    public let thumbnail: String?
    public let fileName: String?
    public let fileSize: Int?
    public let mimeType: String?
    public let duration: Double?
    public let width: Double?
    public let height: Double?
    
    public var isVideo: Bool {
        if let mime = mimeType, mime.contains("video") { return true }
        return url.lowercased().hasSuffix(".mp4") || url.lowercased().hasSuffix(".mov")
    }
    
    public init(
        url: String,
        thumbnailUrl: String? = nil,
        fileName: String? = nil,
        fileSize: Int? = nil,
        mimetype: String? = nil,
        duration: Double? = nil,
        width: Double? = nil,
        height: Double? = nil
    ) {
        self.url = url
        self.thumbnail = thumbnailUrl
        self.fileName = fileName
        self.fileSize = fileSize
        self.mimeType = mimetype
        self.duration = duration
        self.width = width
        self.height = height
    }
}

nonisolated public struct MessageReaction: Equatable, Codable, Sendable {
    public let reaction: String
    public let count: Int
    public let users: [String]
    
    public init(reaction: String, count: Int, users: [String]) {
        self.reaction = reaction
        self.count = count
        self.users = users
    }
}


nonisolated public struct Message: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let conversationId: String
    public var role: MessageRole
    public var content: String
    public var messageType: String
    public var replyToId: String?
    public var mediaUrl: String?
    public var thumbnailUrl: String?
    public var fileSize: Int?
    public var fileName: String?
    public var mimeType: String?
    public var timestamp: Date
    public var isError: Bool
    public var status: MessageStatus
    public var duration: Double?
    public var isEdited: Bool
    public var reactions: [MessageReaction]
    public var mediasItems: [MediaItem]
    
    public var allMedia: [MediaItem] {
        if !mediasItems.isEmpty {
            return mediasItems
        } else if let url = mediaUrl, !url.isEmpty {
            return [
                MediaItem(
                    url: url,
                    thumbnailUrl: thumbnailUrl,
                    fileName: fileName,
                    fileSize: fileSize,
                    mimetype: mimeType,
                    duration: duration
                )
            ]
        }
        return []
    }
    
    public init (
        id: String = UUID().uuidString,
        conversationId: String,
        role: MessageRole,
        content: String?,
        timestamp: Date = Date(),
        isError: Bool = false,
        status: MessageStatus = .sent,
        replyToId: String? = nil,
        messageType: String = "text",
        mediaUrl: String? = nil,
        thumbnailUrl: String? = nil,
        fileSize: Int? = nil,
        fileName: String? = nil,
        mimeType: String? = nil,
        duration: Double? = nil,
        isEdited: Bool = false,
        reactions: [MessageReaction] = [],
        mediasItems: [MediaItem] = [],
    ) {
        self.id = id
        self.conversationId = conversationId
        self.role = role
        self.content = content ?? ""
        self.timestamp = timestamp
        self.isError = isError
        self.status = status
        self.replyToId = replyToId
        self.messageType = messageType
        self.mediaUrl = mediaUrl
        self.thumbnailUrl = thumbnailUrl
        self.fileSize = fileSize
        self.fileName = fileName
        self.mimeType = mimeType
        self.duration = duration
        self.isEdited = isEdited
        self.reactions = reactions
        self.mediasItems = mediasItems
        self.status = status
    }
}

