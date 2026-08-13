//
//  Conversation.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 13/8/26.
//

import Foundation

nonisolated public struct Conversation: Identifiable, Equatable, Codable, Sendable {
    
    public let id: String
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public var isPinned: Bool
    public var isFavourite: Bool
    public var modelName: String
    public var draftMessage: String?
    public var systemPrompt: String?
    public var isUserToUser: Bool
    public var peerId: String
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isPinned: Bool = false,
        isFavourite: Bool = false,
        modelName: String = "gemini-1.5-flash",
        draftMessage: String? = nil,
        systemPrompt: String? = nil,
        isUserToUser: Bool = false,
        peerId: String = ""
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
        self.isFavourite = isFavourite
        self.modelName = modelName
        self.draftMessage = draftMessage
        self.systemPrompt = systemPrompt
        self.isUserToUser = isUserToUser
        self.peerId = peerId
    }
    
}
