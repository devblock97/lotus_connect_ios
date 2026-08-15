//
//  ChatbotFeature.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 14/8/26.
//

import ComposableArchitecture
import SwiftUI
import IdentifiedCollections

@Reducer
public struct ChatbotFeature {
    @ObservableState
    public struct State: Equatable {
        public var messages: IdentifiedArrayOf<Message> = []
        public var inputText: String = ""
        public var isGenerating: Bool = false
        public var errorMessage: String? = nil
        
        public var quickPrompts: [String] = [
            "Summarize my recent conversations",
            "Help me write a professional reply",
            "What can Lotus AI do?",
            "Translate text into Spanish"
        ]
        
        public init(messages: IdentifiedArrayOf<Message> = []) {
            self.messages = messages
        }
    }
    
    @CasePathable
    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppear
        case fetchHistoryResponse(TaskResult<[Message]>)
        case sendButtonTapped
        case quickPromptSelected(String)
        case receiveAssistantResponse(TaskResult<Message>, userMessageId: String)
        case receiveStreamToken(id: String, token: String)
        case streamCompleted(id: String)
        case streamFailed(id: String, error: String)
        case clearHistoryTapped
        case clearHistoryResponse(TaskResult<Bool>)
        case retryTapped(Message)
        case dismissError
    }
    
    @Dependency(\.chatbotClient) var chatbotClient
    @Dependency(\.uuid) var uuid
    
    public init() {}
    
    public var body: some Reducer<State, Action> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.messages.isEmpty else { return .none }
                return .run { send in
                    await send(.fetchHistoryResponse(TaskResult {
                        try await chatbotClient.fetchHistory()
                    }))
                }
                
            case let .fetchHistoryResponse(.success(history)):
                state.messages = IdentifiedArray(uniqueElements: history)
                return .none
                
            case .fetchHistoryResponse(.failure):
                return .none
                
            case .sendButtonTapped:
                let trimmed = state.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, !state.isGenerating else { return .none }
                
                let userMessage = Message(
                    id: uuid().uuidString,
                    conversationId: "chatbot",
                    role: .user,
                    content: trimmed,
                    timestamp: Date(),
                    status: .sent
                )
                
                let assistantMessageId = uuid().uuidString
                let assistantMessage = Message(
                    id: assistantMessageId,
                    conversationId: "chatbot",
                    role: .assistant,
                    content: "",
                    timestamp: Date(),
                    status: .streaming
                )

                
                state.messages.append(userMessage)
                state.messages.append(assistantMessage)
                state.inputText = ""
                state.isGenerating = true
                state.errorMessage = nil
                

                let currentHistory = Array(state.messages)
                
                return .run { send in
                    do {
                        for try await token in chatbotClient.sendPromptStream(trimmed, currentHistory) {
                            await send(.receiveStreamToken(id: assistantMessageId, token: token))
                        }
                        await send(.streamCompleted(id: assistantMessageId))
                    } catch {
                        await send(.streamFailed(id: assistantMessageId, error: error.localizedDescription))
                    }
                }
                
            case let .receiveStreamToken(id, token):
                if state.messages[id: id] != nil {
                    state.messages[id: id]?.content.append(token)
                    state.messages[id: id]?.status = .streaming
                }
                return .none
                
            case let .streamCompleted(id):
                state.isGenerating = false
                if state.messages[id: id] != nil {
                    state.messages[id: id]?.status = .sent
                }
                return .none
                
            case let .streamFailed(id, errorStr):
                state.isGenerating = false
                state.errorMessage = "Failed to get AI response: \(errorStr)"
                if state.messages[id: id] != nil {
                    state.messages[id: id]?.status = .error
                    state.messages[id: id]?.isError = true
                    if state.messages[id: id]?.content.isEmpty == true {
                        state.messages[id: id]?.content = "Sorry, I couldn't process your request right now. Please try again."
                    }
                }
                return .none

            case let .quickPromptSelected(prompt):
                state.inputText = prompt
                return .send(.sendButtonTapped)
                
            case let .receiveAssistantResponse(.success(assistantMessage), _):
                state.isGenerating = false
                state.messages.append(assistantMessage)
                return .none
                
            case let .receiveAssistantResponse(.failure(error), _):
                state.isGenerating = false
                state.errorMessage = "Failed to get AI response: \(error.localizedDescription)"
                
                let errorMsg = Message(
                    id: uuid().uuidString,
                    conversationId: "chatbot",
                    role: .assistant,
                    content: "Sorry, I couldn't process your request right now. Please try again.",
                    timestamp: Date(),
                    isError: true,
                    status: .error
                )
                
                state.messages.append(errorMsg)
                return .none
                
            case .clearHistoryTapped:
                state.messages.removeAll()
                return .run { send in
                    await send(.clearHistoryResponse(TaskResult {
                        try await chatbotClient.clearHistory()
                        return true
                    }))
                }
                
            case .clearHistoryResponse:
                return .none
                
            case .retryTapped:
                guard let lastUserMsg = state.messages.last(where: { $0.role == .user }) else { return .none }
                
                state.inputText = lastUserMsg.content
                return .send(.sendButtonTapped)
                
            case .dismissError:
                state.errorMessage = nil
                return .none
                
            case .binding:
                return .none
            }
        }
    }
}
