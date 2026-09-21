//
//  MainTab.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 12/8/26.
//

import SwiftUI
import Symbols

public enum MainTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case chats
    case home
    case contacts
    case calls
    case settings
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .home: return "Home"
        case .chats: return "Chats"
        case .contacts: return "Contacts"
        case .calls: return "Alert"
        case .settings: return "Settings"
        }
    }
    
    public var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .chats: return "bubble.left.and.bubble.right.fill"
        case .contacts: return "person.2.fill"
        case .calls: return "bell"
        case .settings: return "gearshape.fill"
        }
    }
}
