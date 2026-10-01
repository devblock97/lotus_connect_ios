//
//  Author.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 30/9/26.
//

nonisolated public struct Author: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let username: String
    public let fullName: String?
    public let avatarUrl: String?

    public init(
        id: String,
        username: String,
        fullName: String? = nil,
        avatarUrl: String? = nil
    ) {
        self.id = id
        self.username = username
        self.fullName = fullName
        self.avatarUrl = avatarUrl
    }
}
