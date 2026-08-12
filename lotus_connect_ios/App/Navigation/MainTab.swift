//
//  MainTab.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 12/8/26.
//

import SwiftUI

public enum MainTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case chats
    case chatbot
    case contacts
    case calls
    case settings
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .chats: return "Chats"
        case .chatbot: return "AI"
        case .contacts: return "Contacts"
        case .calls: return "Calls"
        case .settings: return "Settings"
        }
    }
    
    public var iconName: String {
        switch self {
        case .chats: return "bubble.left.and.bubble.right.fill"
        case .chatbot: return "sparkles"
        case .contacts: return "person.2.fill"
        case .calls: return "phone.fill"
        case .settings: return "gearshape.fill"
        }
    }
}
