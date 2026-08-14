//
//  ChatbotClient.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 14/8/26.
//

import Dependencies
import DependenciesMacros
import Foundation

// MARK: - Ollama API DTOs

nonisolated public struct OllamaChatMessageDTO: Codable, Sendable {
    public let role: String
    public let content: String
    
    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

nonisolated public struct OllamaChatRequestDTO: Encodable, Sendable {
    public let model: String
    public let messages: [OllamaChatMessageDTO]
    public let stream: Bool
    
    public init(model: String = "llama3", messages: [OllamaChatMessageDTO], stream: Bool = false) {
        self.model = model
        self.messages = messages
        self.stream = stream
    }
}

nonisolated public struct OllamaChatResponseDTO: Decodable, Sendable {
    public let model: String?
    public let message: OllamaChatMessageDTO?
    public let done: Bool?
}

// MARK: - Fallback / Custom API DTOs

nonisolated public struct ChatbotPromptRequestDTO: Encodable, Sendable {
    public let prompt: String
    public let conversationHistory: [ChatbotMessageDTO]?
    
    enum CodingKeys: String, CodingKey {
        case prompt
        case conversationHistory = "conversation_history"
    }
}

nonisolated public struct ChatbotMessageDTO: Codable, Sendable {
    public let role: String
    public let content: String
    
    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

nonisolated public struct ChatbotResponseDTO: Decodable, Sendable {
    public let id: String?
    public let reply: String
    public let timestamp: String?
}

// MARK: - Client Interface

@DependencyClient
public struct ChatbotClient: Sendable {
    public var sendPrompt: @Sendable (_ prompt: String, _ history: [Message]) async throws -> Message
    public var fetchHistory: @Sendable () async throws -> [Message]
    public var clearHistory: @Sendable () async throws -> Void
}

extension ChatbotClient: DependencyKey {
    public static let liveValue: ChatbotClient = {
        @Dependency(\.httpClient) var httpClient
        
        let ollamaBaseURL = URL(string: "http://localhost:11434")!
        let ollamaModel = "llama3" // Default Ollama model (e.g. llama3, mistral, gemma)
        
        return ChatbotClient(
            sendPrompt: { prompt, history in
                // Prepare conversation messages for Ollama Chat API
                var chatMessages: [OllamaChatMessageDTO] = [
                    OllamaChatMessageDTO(role: "system", content: "You are Lotus AI, a helpful assistant integrated into Lotus Connect.")
                ]
                
                let historyMessages = history.suffix(10).map { msg in
                    OllamaChatMessageDTO(
                        role: msg.role == .user ? "user" : "assistant",
                        content: msg.content
                    )
                }
                chatMessages.append(contentsOf: historyMessages)
                chatMessages.append(OllamaChatMessageDTO(role: "user", content: prompt))
                
                let requestDTO = OllamaChatRequestDTO(model: ollamaModel, messages: chatMessages, stream: false)
                
                // Attempt direct request to local Ollama server
                let ollamaURL = ollamaBaseURL.appendingPathComponent("/api/chat")
                var request = URLRequest(url: ollamaURL)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONEncoder().encode(requestDTO)
                
                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    if let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
                        let ollamaResponse = try JSONDecoder().decode(OllamaChatResponseDTO.self, from: data)
                        let replyText = ollamaResponse.message?.content ?? "No response from Ollama."
                        
                        return Message(
                            id: UUID().uuidString,
                            conversationId: "chatbot",
                            role: .assistant,
                            content: replyText,
                            timestamp: Date(),
                            isError: false,
                            status: .sent
                        )
                    }
                } catch {
                    // Fallback to primary backend HTTPClient if local Ollama server is unreachable
                    let fallbackDTO = ChatbotPromptRequestDTO(
                        prompt: prompt,
                        conversationHistory: history.suffix(10).map { ChatbotMessageDTO(role: $0.role.rawValue, content: $0.content) }
                    )
                    let backendResp: ChatbotResponseDTO = try await httpClient.request(
                        "/chatbot/query",
                        .post,
                        fallbackDTO,
                        nil
                    )
                    return Message(
                        id: backendResp.id ?? UUID().uuidString,
                        conversationId: "chatbot",
                        role: .assistant,
                        content: backendResp.reply,
                        timestamp: Date(),
                        isError: false,
                        status: .sent
                    )
                }
                
                throw NSError(domain: "OllamaClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to connect to local Ollama server."])
            },
            fetchHistory: {
                return []
            },
            clearHistory: {
                
            }
        )
    }()
}

extension DependencyValues {
    public var chatbotClient: ChatbotClient {
        get { self[ChatbotClient.self] }
        set { self[ChatbotClient.self] = newValue }
    }
}
