//
//  Post.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 22/9/26.
//

import Foundation

nonisolated public struct Post: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let author: Author
    public let content: String
    public let mediaItems: [MediaItem]
    public let visibility: String
    public let likeCount: Int
    public let commentCount: Int
    public let userHasLiked: Bool
    public let userReaction: String?
    public let createdAt: String
    public let updatedAt: String

    public init(
        id: String,
        author: Author,
        content: String,
        mediaItems: [MediaItem] = [],
        visibility: String = "public",
        likeCount: Int = 0,
        commentCount: Int = 0,
        userHasLiked: Bool = false,
        userReaction: String? = nil,
        createdAt: String = "",
        updatedAt: String = ""
    ) {
        self.id = id
        self.author = author
        self.content = content
        self.mediaItems = mediaItems
        self.visibility = visibility
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.userHasLiked = userHasLiked
        self.userReaction = userReaction
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case author
        case content
        case mediaItems
        case visibility
        case likeCount
        case commentCount
        case userHasLiked
        case userReaction
        case createdAt
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.author = try container.decode(Author.self, forKey: .author)
        self.content = try container.decode(String.self, forKey: .content)
        self.mediaItems = try container.decodeIfPresent([MediaItem].self, forKey: .mediaItems) ?? []
        self.visibility = try container.decodeIfPresent(String.self, forKey: .visibility) ?? "public"
        self.likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        self.commentCount = try container.decodeIfPresent(Int.self, forKey: .commentCount) ?? 0
        self.userHasLiked = try container.decodeIfPresent(Bool.self, forKey: .userHasLiked) ?? false
        self.userReaction = try container.decodeIfPresent(String.self, forKey: .userReaction)
        self.createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        self.updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
    }
}
