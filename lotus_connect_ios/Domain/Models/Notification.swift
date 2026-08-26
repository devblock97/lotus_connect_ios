//
//  Notification.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 28/8/26.
//
import Foundation
import SwiftUI

public enum NotificationType: String, Codable, Sendable {
    case chat
    case missedCall = "missed_call"
    case friendRequest = "friend_request"
    case friendAccept = "friend_accept"
    case unknown
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = NotificationType(rawValue: raw) ?? .unknown
    }
}

public struct NotificationData: Hashable, Equatable, Codable, Sendable {
    public let type: NotificationType?
    public let conversationId: String?
    public let messageId: String?
    public let callId: String?
    public let callerId: String?
    public let senderId: String?
    
    public init(
        type: NotificationType? = nil,
        conversationId: String? = nil,
        messageId: String? = nil,
        callId: String? = nil,
        callerId: String? = nil,
        senderId: String? = nil
    ) {
        self.type = type
        self.conversationId = conversationId
        self.messageId = messageId
        self.callId = callId
        self.callerId = callerId
        self.senderId = senderId
    }
}

nonisolated public struct AppNotification: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let userId: String
    public var title: String
    public var body: String
    public var isRead: Bool
    public var createdAt: Date
    public var data: NotificationData?
    
    public init (
        id: String = UUID().uuidString,
        userId: String = "",
        title: String,
        body: String,
        isRead: Bool = false,
        createdAt: Date = Date(),
        data: NotificationData? = nil
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.body = body
        self.isRead = isRead
        self.createdAt = createdAt
        self.data = data
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case body
        case data
        case isRead = "is_read"
        case createdAt = "created_at"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(String.self, forKey: .id)
        self.userId = try container.decodeIfPresent(String.self, forKey: .userId) ?? ""
        self.title = try container.decode(String.self, forKey: .title)
        self.body = try container.decode(String.self, forKey: .body)
        self.isRead = try container.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
        self.data = try container.decodeIfPresent(NotificationData.self, forKey: .data)
        
        let dateString = try container.decode(String.self, forKey: .createdAt)
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = isoFormatter.date(from: dateString) {
            self.createdAt = date
        } else {
            let standardFormatter = DateFormatter()
            self.createdAt = standardFormatter.date(from: dateString) ?? Date()
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(title, forKey: .title)
        try container.encode(body, forKey: .body)
        try container.encode(isRead, forKey: .isRead)
        try container.encode(data, forKey: .data)
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try container.encode(formatter.string(from: createdAt), forKey: .createdAt)
    }
}

extension AppNotification {
    public var iconName: String {
        switch data?.type {
        case .chat:
            return "bubble.left.fill"
        case .missedCall:
            return "phone.down.left.fill"
        case .friendRequest:
            return "person.badge.plus.fill"
        case .friendAccept:
            return "person.badge.shield.checkmark.fill"
        case .unknown, .none:
            return "bell.fill"
        }
    }
    
    public var iconColor: Color {
        switch data?.type {
        case .chat:
            return .blue
        case .missedCall:
            return .red
        case .friendRequest:
            return .purple
        case .friendAccept:
            return .green
        case .unknown, .none:
            return .orange
        }
    }
}
