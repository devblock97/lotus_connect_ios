//
//  RootTabFeature.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 12/8/26.
//

import ComposableArchitecture
import Foundation

@Reducer
public struct RootTabFeature {
    @ObservableState
    public struct State: Equatable {
        public var selectedTab: MainTab = .chats
        
        public var unreadCount: Int = 3
        
        public var chatList = ChatListFeature.State()
        public var chatbot = ChatbotFeature.State()
        public var contacts = ContactsFeature.State()
        public var calls = CallsFeature.State()
        public var notifications = NotificationsFeature.State()
        public var settings = SettingsFeature.State()
        
        public init(selectedTab: MainTab = .chats) {
            self.selectedTab = selectedTab
        }
    }
    
    @CasePathable
    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case tabSelected(MainTab)
        
        case chatList(ChatListFeature.Action)
        case chatbot(ChatbotFeature.Action)
        case contacts(ContactsFeature.Action)
        case notifications(NotificationsFeature.Action)
        case calls(CallsFeature.Action)
        case settings(SettingsFeature.Action)
    }
    
    public init() {}
    
    public var body: some Reducer<State, Action> {
        BindingReducer()
        
        Scope(state: \.chatList, action: \.chatList) {
            ChatListFeature()
        }
        Scope(state: \.chatbot, action: \.chatbot) {
            ChatbotFeature()
        }
        Scope(state: \.contacts, action: \.contacts) {
            ContactsFeature()
        }
        Scope(state: \.notifications, action: \.notifications) {
            NotificationsFeature()
        }
        Scope(state: \.calls, action: \.calls) {
            CallsFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
        
        Reduce { state, action in
            switch action {
            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none
                
            case .binding, .chatList, .chatbot, .contacts, .calls, .settings, .notifications:
                return .none
            }
        }
    }
}
