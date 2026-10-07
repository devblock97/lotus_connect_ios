//
//  CallLog.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 6/10/26.
//
import Foundation

nonisolated public struct CallLog: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let hostId: String
    public let channelId: String
    public let isVideo: Bool
    public let status: String
    public let createdAt: Date
    public let conversationid: String?
    public let endedAt: Date?
    public let hostName: String?
    public let username: String?
    
    public init(
        id: String,
        hostId: String,
        channelId: String,
        isVideo: Bool,
        status: String,
        createdAt: Date = Date(),
        conversationId: String? = nil,
        endedAt: Date? = nil,
        hostName: String? = nil,
        username: String? = nil
    ) {
        self.id = id
        self.hostId = hostId
        self.channelId = channelId
        self.isVideo = isVideo
        self.status = status
        self.createdAt = createdAt
        self.conversationid = conversationId
        self.endedAt = endedAt
        self.hostName = hostName
        self.username = username
    }
    
    public var durationSeconds: Int {
        guard let endedAt = endedAt else { return 0 }
        return max(0, Int(endedAt.timeIntervalSince(createdAt)))
    }
    
    public var isMissed: Bool {
        status == "missed" || status == "rejected"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case hostId
        case host_id
        case channelId
        case isVideo
        case is_video
        case status
        case createdAt
        case created_at
        case conversationId
        case conversation_id
        case endedAt
        case ended_at
        case hostName
        case host_name
        case username
    }
    
    nonisolated public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.hostId = try container.decodeIfPresent(String.self, forKey: .hostId) ?? container.decodeIfPresent(String.self, forKey: .hostId) ?? ""
        self.channelId = try container.decodeIfPresent(String.self, forKey: .channelId) ?? container.decodeIfPresent(String.self, forKey: .channelId) ?? ""
        self.isVideo = try container.decodeIfPresent(Bool.self, forKey: .isVideo) ?? container.decodeIfPresent(Bool.self, forKey: .isVideo) ?? container.decodeIfPresent(Bool.self, forKey: .is_video) ?? false
        self.status = try container.decodeIfPresent(String.self, forKey: .status) ?? "completed"
        
        // Date parsing
        if let createdStr = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? container.decodeIfPresent(String.self, forKey: .created_at) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            self.createdAt = formatter.date(from: createdStr) ?? ISO8601DateFormatter().date(from: createdStr) ?? Date()
        } else {
            self.createdAt = Date()
        }
        
        if let endedStr = try container.decodeIfPresent(String.self, forKey: .endedAt) ?? container.decodeIfPresent(String.self, forKey: .ended_at) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            self.endedAt = formatter.date(from: endedStr) ?? ISO8601DateFormatter().date(from: endedStr)
        } else {
            self.endedAt = nil
        }
        
        self.conversationid = try container.decodeIfPresent(String.self, forKey: .conversationId) ?? container.decodeIfPresent(String.self, forKey: .conversation_id)
        self.hostName = try container.decodeIfPresent(String.self, forKey: .hostName) ?? container.decodeIfPresent(String.self, forKey: .host_name)
        self.username = try container.decodeIfPresent(String.self, forKey: .username)
    }
    
    nonisolated public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(hostId, forKey: .hostId)
        try container.encode(channelId, forKey: .channelId)
        try container.encode(isVideo, forKey: .isVideo)
        try container.encode(status, forKey: .status)
        try container.encode(ISO8601DateFormatter().string(from: createdAt), forKey: .createdAt)
        if let endedAt = endedAt {
            try container.encode(ISO8601DateFormatter().string(from: endedAt), forKey: .endedAt)
        }
        try container.encodeIfPresent(conversationid, forKey: .conversationId)
        try container.encodeIfPresent(hostName, forKey: .hostName)
        try container.encodeIfPresent(username, forKey: .username)
    }
}


