//
//  ChatbotView.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 12/8/26.
//

import ComposableArchitecture
import SwiftUI

public struct ChatbotView: View {
    @Bindable var store: StoreOf<ChatbotFeature>
    
    public init(store: StoreOf<ChatbotFeature>) {
        self.store = store
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if store.messages.isEmpty {
                            EmptyChatbotStateView(
                                onSelectQuickPrompt: { prompt in
                                store.send(.quickPromptSelected(prompt))
                            }, quickPrompts: store.quickPrompts)
                            .padding(.top, 40)
                        } else {
                            ForEach(store.messages) { message in
                                ChatbotMessageBubbleView(
                                    message: message,
                                    onRetry: { store.send(.retryTapped(message))}
                                )
                                .id(message.id)
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: store.messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: store.isGenerating) { _, isGenerating in
                    if isGenerating {
                        withAnimation {
                            proxy.scrollTo("generating_indicator", anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            HStack(spacing: 8) {
                TextField("Ask Lotus AI anything...", text: $store.inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)
                    .disabled(store.isGenerating)
                
                Button {
                    store.send(.sendButtonTapped)
                } label: {
                    if store.isGenerating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(width: 36, height: 36)
                            .background(Color.blue.opacity(0.6))
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                store.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.gray.opacity(0.4)
                                : Color.blue
                            )
                            .clipShape(Circle())
                    }
                }
                .disabled(store.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isGenerating)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .navigationTitle("Lotus AI")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !store.messages.isEmpty {
                    Button(role: .destructive) {
                        store.send(.clearHistoryTapped)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .alert("Error", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.send(.dismissError) } }
        )) {
            Button("OK", role: .cancel) { store.send(.dismissError) }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastId = store.messages.last?.id {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
}

struct EmptyChatbotStateView: View {
    let onSelectQuickPrompt: (String) -> Void
    let quickPrompts: [String]
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 72, height: 72)
                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 6) {
                Text("How can Lotus AI help you today?")
                    .font(.title3.bold())
                Text("Ask questions, summarize chats, or draft replies effortlessly.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Sugessted Prompts")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                
                ForEach(quickPrompts, id: \.self) { prompt in
                    Button {
                        onSelectQuickPrompt(prompt)
                    } label: {
                        HStack {
                            Image(systemName: "bubble.left.and.sparkles")
                                .foregroundColor(.blue)
                            Text(prompt)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.top, 10)
        }
        .padding(.horizontal)
    }
}

struct ChatbotMessageBubbleView: View {
    let message: Message
    let onRetry: () -> Void
    
    var isUser: Bool { message.role == .user }
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if !isUser {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32, height: 32)
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            if isUser { Spacer() }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(
                        isUser
                        ? Color.blue
                        : (message.isError ? Color.red.opacity(0.1) : Color(.systemGray6))
                    )
                    .foregroundColor(
                        isUser
                        ? .white
                        : (message.isError ? .red : .primary)
                    )
                    .cornerRadius(16)
                
                HStack(spacing: 6) {
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if message.isError {
                        Button(action: onRetry) {
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.clockwise")
                                Text("Retry")
                            }
                            .font(.caption2.bold())
                            .foregroundColor(.red)
                        }
                    }
                }
                
                if isUser {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundColor(.gray)
                } else {
                    Spacer()
                }
            }
        }
    }
}

struct ChatbotTypingIndicatorView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 32, height: 32)
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            
            HStack(spacing: 6) {
                Text("Lotus AI is thinking")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ProgressView()
                    .scaleEffect(0.8)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(16)
            
            Spacer()
        }
    }
}
