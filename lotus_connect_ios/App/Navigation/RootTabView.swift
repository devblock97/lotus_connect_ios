//
//  RootTabView.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 12/8/26.
//

import SwiftUI
import ComposableArchitecture

public struct RootTabView: View {
    @Bindable var store: StoreOf<RootTabFeature>
    
    public init(store: StoreOf<RootTabFeature>) {
        self.store = store
    }
    
    public var body: some View {
        TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
            // Chats Screen
            NavigationStack {
                ChatListView(store: store.scope(state: \.chatList, action: \.chatList))
            }
            .tabItem {
                Label(MainTab.chats.title, systemImage: MainTab.chats.iconName)
            }
            .badge(store.unreadCount > 0 ? "\(store.unreadCount)" : nil)
            .tag(MainTab.chats)
            // Chatbot Screen
            NavigationStack {
                ChatbotView(store: store.scope(state: \.chatbot, action: \.chatbot))
            }
            .tabItem {
                Label(MainTab.chats.title, systemImage: MainTab.chats.iconName)
            }
            .tag(MainTab.chatbot)
            // Contacts Screen
            NavigationStack {
                ContactsView(store: store.scope(state: \.contacts, action: \.contacts))
            }
            .tabItem {
                Label(MainTab.contacts.title, systemImage: MainTab.contacts.iconName)
            }
            .tag(MainTab.contacts)
            // Calls Screen
            NavigationStack {
                NotificationsView(store: store.scope(state: \.notifications, action: \.notifications))
            }
            .tabItem {
                Label(MainTab.calls.title, systemImage: MainTab.calls.iconName)
            }
            .tag(MainTab.calls)
            // Settings Screen
            NavigationStack {
                SettingsView(store: store.scope(state: \.settings, action: \.settings))
            }
            .tabItem {
                Label(MainTab.settings.title, systemImage: MainTab.settings.iconName)
            }
            .tag(MainTab.settings)
        }
        .tint(.blue)
    }
}
