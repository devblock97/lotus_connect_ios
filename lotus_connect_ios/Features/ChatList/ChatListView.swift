//
//  ChatListView.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 13/8/26.
//

import ComposableArchitecture
import SwiftUI

public struct ChatListView: View {
    @Bindable var store: StoreOf<ChatListFeature>
    
    public init(store: StoreOf<ChatListFeature>) {
        self.store = store
    }
    
    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            ZStack {
                if store.isLoading && store.conversations.isEmpty {
                    ProgressView("Loading chats...")
                } else if store.conversations.isEmpty {
                    ContentUnavailableView("No Conversations", systemImage: "bubble.left.and.bubble.right", description: Text("Your active messages will appear here."))
                } else {
                    List {
                        // MARK: - PINNED SECTION
                        if !store.pinnedConversations.isEmpty {
                            Section("Pinned") {
                                ForEach(store.pinnedConversations) { conversation in
                                    ConversationRow(
                                        conversation: conversation,
                                        displayTitle: store.state.displayTitle(for: conversation)
                                    ) {
                                        store.send(.conversationTapped(conversation))
                                    }
                                }
                            }
                        }
                        
                        // MARK: - RECENT SECTION
                        Section(!store.pinnedConversations.isEmpty ? "RECENT" : "MESSAGES") {
                            ForEach(store.unpinnedConversations) { conversation in
                                    ConversationRow(
                                        conversation: conversation,
                                        displayTitle: store.state.displayTitle(for: conversation)
                                    ) {
                                        store.send(.conversationTapped(conversation))
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            store.send(.togglePinTapped(conversation.id))
                                        } label: {
                                            Label("Unpin", systemImage: "pin.slash.fill")
                                        }
                                        .tint(.orange)
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            store.send(.deleteConversationTapped(conversation.id))
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable {
                        await store.send(.refreshPulled).finish()
                    }
                }
            }
            .navigationTitle("Chats")
            .searchable(text: $store.searchText, prompt: "Search conversations...")
            .onAppear { store.send(.onAppear) }
        } destination: { store in
            PrivateChatDetailView(store: store)
        }
    }
}


struct ConversationRow: View {
    let conversation: Conversation
    let displayTitle: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Text(String(displayTitle.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(displayTitle)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(conversation.updatedAt, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(conversation.draftMessage ?? "Tap to start chatting")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
