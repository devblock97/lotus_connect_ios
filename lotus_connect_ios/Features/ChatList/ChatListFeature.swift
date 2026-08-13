//
//  ChatListFeature.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 13/8/26.
//

import ComposableArchitecture
import Foundation

@Reducer
public struct ChatListFeature {
    @ObservableState
    public struct State: Equatable {
        public var conversations: IdentifiedArrayOf<Conversation> = []
        public var friends: IdentifiedArrayOf<User> = []
        public var searchText: String = ""
        public var isLoading: Bool = false
        public var errorMessage: String?
        
        /// Navigation stack pwering push transitions to Chat Detail
        public var path = StackState<PrivateChatDetailFeature.State>()
        
        /// Filtered list based on search query
        public var filteredConversations: [Conversation] {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if query.isEmpty {
                return Array(conversations)
            } else {
                return conversations.filter { $0.title.localizedCaseInsensitiveContains(query) }
            }
        }
        
        public var pinnedConversations: [Conversation] {
            filteredConversations.filter { $0.isPinned }
        }
        
        public var unpinnedConversations: [Conversation] {
            filteredConversations.filter { !$0.isPinned }
        }
        
        public func displayTitle(for conversation: Conversation) -> String {
            if let friend = friends[id: conversation.peerId] {
                return friend.fullName ?? friend.username
            }
            let trimmed = conversation.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
            if !conversation.peerId.isEmpty {
                let shortId = String(conversation.peerId.prefix(8))
                return "User (\(shortId)"
            }
            
            return "Private Chat"
        }
        
        public init() {}
    }
    
    @CasePathable
    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppear
        case refreshPulled
        case conversationsLoaded(TaskResult<[Conversation]>)
        case friendsLoaded(TaskResult<[User]>)
        case conversationTapped(Conversation)
        case deleteConversationTapped(String)
        case togglePinTapped(String)
        
        /// Navigation path action for pushed child detail screens
        case path(StackAction<PrivateChatDetailFeature.State, PrivateChatDetailFeature.Action>)
    }
    
    @Dependency(\.conversationClient) var conversationClient
    @Dependency(\.httpClient) var httpClient
    
    public init() {}
    
    public var body: some Reducer<State, Action> {
            BindingReducer()
            Reduce { state, action in
                switch action {
                // MARK: - Load Conversations
                case .onAppear, .refreshPulled:
                    state.isLoading = true
                    return .run { send in
                        await send(.conversationsLoaded(TaskResult {
                            try await conversationClient.fetchConversations()
                        }))
                        // Optionally fetch friends list to resolve peer names
                        await send(.friendsLoaded(TaskResult {
                            let friends: [User] = (try? await httpClient.request("/users/friends", .get, nil, nil)) ?? []
                            return friends
                        }))
                    }
                case let .conversationsLoaded(.success(conversations)):
                    state.isLoading = false
                    state.conversations = IdentifiedArray(uniqueElements: conversations)
                    return .none
                case let .conversationsLoaded(.failure(error)):
                    state.isLoading = false
                    state.errorMessage = error.localizedDescription
                    return .none
                case let .friendsLoaded(.success(friends)):
                    state.friends = IdentifiedArray(uniqueElements: friends)
                    return .none
                case .friendsLoaded(.failure):
                    return .none
                // MARK: - Navigation to Detail
                case let .conversationTapped(conversation):
                    // Pushes Chat Detail screen onto NavigationStack
                    state.path.append(PrivateChatDetailFeature.State(conversation: conversation))
                    return .none
                // MARK: - Swipe Actions (Pin & Delete)
                case let .togglePinTapped(id):
                    if var conv = state.conversations[id: id] {
                        conv.isPinned.toggle()
                        state.conversations[id: id] = conv
                        let newPinnedState = conv.isPinned
                        return .run { _ in
                            try? await conversationClient.togglePin(id: id, isPinned: newPinnedState)
                        }
                    }
                    return .none
                case let .deleteConversationTapped(id):
                    state.conversations.remove(id: id)
                    return .run { _ in
                        try? await conversationClient.deleteConversation(id: id)
                    }
                case .path, .binding:
                    return .none
                }
            }
            .forEach(\.path, action: \.path) {
                PrivateChatDetailFeature()
            }
        }
}
