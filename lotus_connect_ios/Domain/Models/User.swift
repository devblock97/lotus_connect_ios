//
//  User.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 12/8/26.
//

import Foundation

public struct User: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public var username: String
    public var email: String
    public var fullName: String?
    public var friendshipStatus: String?
    public var friendshipSenderId: String?
    
    public init(
        id: String,
        username: String,
        email: String,
        fullName: String? = nil,
        friendshipStatus: String? = nil,
        friendshipSenderId: String? = nil,
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.fullName = fullName
        self.friendshipStatus = friendshipStatus
        self.friendshipSenderId = friendshipSenderId
    }
}
