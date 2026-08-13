//
//  PrivateChatDetailFeature.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 13/8/26.
//

import ComposableArchitecture
import Foundation

@Reducer
public struct PrivateChatDetailFeature {
    @ObservableState
    public struct State: Equatable {
        public var conversation: Conversation
        public var messages: IdentifiedArrayOf<Message> = []
        public var inputText: String = ""
        public var replyingToMessage: Message?
        public var editingMessage: Message?
        public var isPeerTyping: Bool = false
        public var isLoading: Bool = false
        public var errorMessage: String?
        public init(conversation: Conversation) {
            self.conversation = conversation
        }
    }
    
    @CasePathable
    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppear
        case messagesLoaded(TaskResult<[Message]>)
        case sendButtonTapped
        case messageSentResponse(TaskResult<Message>)
        case setReplyingToMessage(Message?)
        case setEditingMessage(Message?)
        case updateMessageSubmitted(String, String)
        case messageUpdatedResponse(TaskResult<Bool>)
        case deleteMessageTapped(String)
        case messageDeletedResponse(TaskResult<Bool>)
        case typingStatusChanged(Bool)
    }
    
    @Dependency(\.privateChatClient) var privateChatClient
    
    public init() {}
    
    public var body: some Reducer<State, Action> {
            BindingReducer()
            Reduce { state, action in
                switch action {
                // MARK: - Fetch Messages on Screen Appear
                case .onAppear:
                    state.isLoading = true
                    let convId = state.conversation.id
                    return .run { send in
                        await send(.messagesLoaded(TaskResult {
                            try await privateChatClient.fetchMessages(conversationId: convId)
                        }))
                    }
                case let .messagesLoaded(.success(messages)):
                    state.isLoading = false
                    state.messages = IdentifiedArray(uniqueElements: messages)
                    return .none
                case let .messagesLoaded(.failure(error)):
                    state.isLoading = false
                    state.errorMessage = error.localizedDescription
                    return .none
                // MARK: - Send Message
                case .sendButtonTapped:
                    let text = state.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return .none }
                    let convId = state.conversation.id
                    let replyToId = state.replyingToMessage?.id
                    let tempMsgId = UUID().uuidString
                    let optimisticMessage = Message(
                        id: tempMsgId,
                        conversationId: convId,
                        role: .user,
                        content: text,
                        timestamp: Date(),
                        status: .sending,
                        replyToId: replyToId
                    )
                    state.messages.append(optimisticMessage)
                    state.inputText = ""
                    state.replyingToMessage = nil
                    return .run { send in
                        await send(.messageSentResponse(TaskResult {
                            try await privateChatClient.sendMessage(conversationId: convId, content: text, replyToId: replyToId)
                        }))
                    }
                case let .messageSentResponse(.success(confirmedMsg)):
                    if let lastIndex = state.messages.firstIndex(where: { $0.status == .sending }) {
                        state.messages[lastIndex] = confirmedMsg
                    }
                    return .none
                case let .messageSentResponse(.failure(error)):
                    if let lastIndex = state.messages.firstIndex(where: { $0.status == .sending }) {
                        state.messages[lastIndex].status = .error
                        state.messages[lastIndex].isError = true
                    }
                    state.errorMessage = error.localizedDescription
                    return .none
                // MARK: - Reply & Edit
                case let .setReplyingToMessage(message):
                    state.replyingToMessage = message
                    state.editingMessage = nil
                    return .none
                case let .setEditingMessage(message):
                    state.editingMessage = message
                    if let msg = message {
                        state.inputText = msg.content
                    }
                    state.replyingToMessage = nil
                    return .none
                case let .updateMessageSubmitted(msgId, newContent):
                    state.messages[id: msgId]?.content = newContent
                    state.editingMessage = nil
                    state.inputText = ""
                    return .run { send in
                        await send(.messageUpdatedResponse(TaskResult {
                            try await privateChatClient.updateMessage(messageId: msgId, content: newContent)
                            return true
                        }))
                    }
                case .messageUpdatedResponse(.success):
                    return .none
                case let .messageUpdatedResponse(.failure(error)):
                    state.errorMessage = error.localizedDescription
                    return .none
                // MARK: - Delete Message
                case let .deleteMessageTapped(msgId):
                    state.messages.remove(id: msgId)
                    return .run { send in
                        await send(.messageDeletedResponse(TaskResult {
                            try await privateChatClient.deleteMessage(messageId: msgId)
                            return true
                        }))
                    }
                case .messageDeletedResponse(.success):
                    return .none
                case let .messageDeletedResponse(.failure(error)):
                    state.errorMessage = error.localizedDescription
                    return .none
                case let .typingStatusChanged(isTyping):
                    state.isPeerTyping = isTyping
                    return .none
                case .binding:
                    return .none
                }
            }
        }
}
