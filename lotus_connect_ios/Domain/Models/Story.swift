//
//  Story.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 30/9/26.
//
import SwiftUI

nonisolated public struct StorySticker: Codable, Sendable, Equatable {
    public let lat: Double?
    public let lng: Double?
    public let name: String?
    public let type: String
    
    public init(lat: Double? = nil, lng: Double? = nil, name: String? = nil, type: String) {
        self.lat = lat
        self.lng = lng
        self.name = name
        self.type = type
    }
}

nonisolated public struct StoryMetadata: Codable, Sendable, Equatable {
    public let stickers: [StorySticker]?
    
    public init(stickers: [StorySticker]? = nil) {
        self.stickers = stickers
    }
}

nonisolated public struct Story: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let author: Author
    public let mediaType: String
    public let mediaUrl: String
    public let thumbnailUrl: String?
    public let caption: String?
    public let duration: Double
    public let visibility: String
    public let backgroundColor: String?
    public let metadata: StoryMetadata?
    public let createdAt: String
    public let expiresAt: String
    public let viewCount: Int
    public let hasViewed: Bool
    public let viewerReaction: String?
    public let isCloseFriend: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, author, mediaType, mediaUrl, thumbnailUrl, caption
        case duration, visibility, backgroundColor, metadata
        case createdAt, expiresAt, viewCount, hasViewed, viewerReaction, isCloseFriend
    }
    
    public var isVideo: Bool {
        mediaType.lowercased() == "video"
    }
    
    public var locationName: String? {
        metadata?.stickers?.first(where: { $0.type.lowercased() == "location" })?.name
    }
    
    public var backgroundColors: [Color] {
        if let hex = backgroundColor, !hex.isEmpty {
            let color = Color(hex: hex)
            return [color, color.opacity(0.85)]
        }
        return StoryColors.avatarGradient(for: author.username)
    }
    
    public var timeAgo: String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = isoFormatter.date(from: createdAt) ?? ISO8601DateFormatter().date(from: createdAt)
        guard let validDate = date else { return "" }
        
        let seconds = Int(Date().timeIntervalSince(validDate))
        if seconds < 60 { return "Just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        let days = hours / 24
        return "\(days)d"
    }
}


nonisolated public struct UserStory: Codable, Sendable, Equatable, Identifiable {
    public var id: String { user.id }
    public let user: Author
    public var stories: [Story]
    public var hasUnseen: Bool
    public let totalStories: Int
    public let latestStoryCreatedAt: String
    public let hasCloseFriendsStory: Bool
    public let isSelf: Bool
    
    public var isSeen: Bool {
        get { !hasUnseen }
        set { hasUnseen = !newValue }
    }
    
    enum CodingKeys: String, CodingKey {
        case user, stories, hasUnseen, totalStories, latestStoryCreatedAt
        case hasCloseFriendsStory, hasCloseFriendStory, isSelf
    }
    
    public init(
        user: Author,
        stories: [Story] = [],
        hasUnseen: Bool = false,
        totalStories: Int = 0,
        latestStoryCreatedAt: String = "",
        hasCloseFriendsStory: Bool = false,
        isSelf: Bool = false
    ) {
        self.user = user
        self.stories = stories
        self.hasUnseen = hasUnseen
        self.totalStories = totalStories
        self.latestStoryCreatedAt = latestStoryCreatedAt
        self.hasCloseFriendsStory = hasCloseFriendsStory
        self.isSelf = isSelf
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.user = try container.decode(Author.self, forKey: .user)
        self.stories = try container.decodeIfPresent([Story].self, forKey: .stories) ?? []
        self.hasUnseen = try container.decodeIfPresent(Bool.self, forKey: .hasUnseen) ?? false
        self.totalStories = try container.decodeIfPresent(Int.self, forKey: .totalStories) ?? self.stories.count
        self.latestStoryCreatedAt = try container.decodeIfPresent(String.self, forKey: .latestStoryCreatedAt) ?? ""
        self.hasCloseFriendsStory = try container.decodeIfPresent(Bool.self, forKey: .hasCloseFriendsStory)
            ?? container.decodeIfPresent(Bool.self, forKey: .hasCloseFriendStory)
            ?? false
        self.isSelf = try container.decodeIfPresent(Bool.self, forKey: .isSelf) ?? false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(user, forKey: .user)
        try container.encode(stories, forKey: .stories)
        try container.encode(hasUnseen, forKey: .hasUnseen)
        try container.encode(totalStories, forKey: .totalStories)
        try container.encode(latestStoryCreatedAt, forKey: .latestStoryCreatedAt)
        try container.encode(hasCloseFriendsStory, forKey: .hasCloseFriendsStory)
        try container.encode(isSelf, forKey: .isSelf)
    }
}
