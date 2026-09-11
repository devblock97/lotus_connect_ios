//
//  PrivateChatDetailView.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 13/8/26.
//

import ComposableArchitecture
import SwiftUI

public struct PrivateChatDetailView: View {
    @Bindable var store: StoreOf<PrivateChatDetailFeature>
    
    public init(store: StoreOf<PrivateChatDetailFeature>) {
        self.store = store
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(store.messages.reversed()) { message in
                            PrivateMessageBubble(
                                message: message,
                                replyingToMessage: store.messages[id: message.replyToId ?? ""],
                                onReply: { store .send(.setReplyingToMessage(message))},
                                onEdit: { store.send(.setEditingMessage(message))},
                                onDelete: { store.send(.deleteMessageTapped(message.id))}
                            )
                            .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: store.messages.count) { _, _ in
                    if let lastid = store.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastid, anchor: .bottom)
                        }
                    }
                }
            }
            
            // MARK: - Typing Indicator Banner
            if store.isPeerTyping {
                HStack(spacing: 6) {
                    Text("\(store.conversation.title) is typing...")
                        .font(.caption)
                        .italic()
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
            
            // MARK: - Active Reply / Edit Bar Preview
            if let replyMsg = store.replyingToMessage {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Replying to:")
                            .font(.caption.bold())
                            .foregroundColor(.blue)
                        Text(replyMsg.content)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button {
                        store.send(.setReplyingToMessage(nil))
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
            }
            
            Divider()
            
            HStack(spacing: 8) {
                TextField("Message \(store.conversation.title)...", text: $store.inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)
                Button {
                    if let editingMsg = store.editingMessage {
                        store.send(.updateMessageSubmitted(editingMsg.id, store.inputText))
                    } else {
                        store.send(.sendButtonTapped)
                    }
                } label: {
                    Image(systemName: store.editingMessage != nil ? "checkmark.circle.fill" : "paperplane.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .disabled(store.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .navigationTitle(store.conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 36, height: 36)
                        Text(store.conversation.title.prefix(1))
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.conversation.title)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        // Handle later
                    } label: {
                         Image(systemName: "phone")
                    }
                    Button {
                        // Handle later
                    } label: {
                        Image(systemName: "video")
                    }
                }
            }
        }
        .onAppear { store.send(.onAppear) }
    }
}

struct ReplyBannerView: View {
    let sendername: String
    let content: String
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.blue)
                .frame(width: 4, height: 36)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Replying to \(sendername)")
                    .font(.caption.bold())
                    .foregroundColor(.blue)
                
                Text(content)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
}

struct PrivateMessageBubble: View {
    let message: Message
    let replyingToMessage: Message?
    let onReply: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var isUser: Bool { message.role == .user }
    
    var body: some View {
        HStack {
            if isUser { Spacer() }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                if let reply = replyingToMessage {
                    Text(reply.content)
                        .font(.caption)
                        .padding(8)
                        .background(Color.black.opacity(0.1))
                        .cornerRadius(8)
                        .lineLimit(2)
                }
                
                Text(message.content)
                    .padding(12)
                    .background(isUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(isUser ? .white : .primary)
                    .cornerRadius(16)
                
                HStack(spacing: 4) {
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if isUser {
                        switch message.status {
                        case .sending:
                            ProgressView().scaleEffect(0.6)
                        case .sent, .read:
                            Image(systemName: "checkmark").font(.caption2)
                        case .streaming:
                            EmptyView()
                        case .error:
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption2)
                        }
                    }
                }
            }
            .contextMenu {
                Button { onReply() } label: {
                    Label("Reply", systemImage: "arrowshape.turn.up.left")
                }
                if isUser {
                    Button { onEdit() } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) { onDelete() } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            
            if !isUser { Spacer() }
        }
    }
}
