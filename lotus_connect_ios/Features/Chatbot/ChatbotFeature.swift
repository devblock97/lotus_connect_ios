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
                
                state.messages.append(userMessage)
                state.inputText = ""
                state.isGenerating = true
                state.errorMessage = nil
                
                let currentHistory = Array(state.messages)
                
                return .run { send in
                    await send(.receiveAssistantResponse(
                        TaskResult {
                            try await chatbotClient.sendPrompt(trimmed, currentHistory)
                        },
                        userMessageId: userMessage.id
                    ))
                }
                
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
