//
//  UserProfile.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 26/8/26.
//

import Foundation

nonisolated public struct UserProfile: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public var username: String
    public var email: String
    public var fullName: String?
    public var bio: String?
    public var avatarUrl: String?
    public var phoneNumber: String?
    public var statusMessage: String?
    public var isOnline: Bool
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: String,
        username: String,
        email: String,
        fullName: String? = nil,
        bio: String? = nil,
        avatarUrl: String? = nil,
        phoneNumber: String? = nil,
        statusMessage: String? = nil,
        isOnline: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.fullName = fullName
        self.bio = bio
        self.avatarUrl = avatarUrl
        self.phoneNumber = phoneNumber
        self.statusMessage = statusMessage
        self.isOnline = isOnline
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

nonisolated public struct UpdateProfileRequestDTO: Encodable, Sendable {
    public let fullName: String?
    public let bio: String?
    public let phoneNumber: String?
    public let statusMessage: String?
    
    public init(fullName: String?, bio: String?, phoneNumber: String?, statusMessage: String?) {
        self.fullName = fullName
        self.bio = bio
        self.phoneNumber = phoneNumber
        self.statusMessage = statusMessage
    }
    
    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case bio
        case phoneNumber = "phone_number"
        case statusMessage = "status_message"
    }
}

nonisolated public struct AvatarUploadResponseDTO: Decodable, Sendable {
    public let avatarUrl: String
    
    enum CodingKeys: String, CodingKey {
        case avatarUrl = "avatar_url"
    }
}
