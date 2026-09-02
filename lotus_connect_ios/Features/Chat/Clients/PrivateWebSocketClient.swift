//
//  PrivateWebSocketClient.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 15/8/26.
//

import Dependencies
import DependenciesMacros
import Foundation

nonisolated public struct WebSocketEventDTO: Decodable, Sendable {
    public let event: String?
    public let type: String?
    public let topic: String?
    public let data: WebSocketMessageDataDTO?
    
    public let id: String?
    public let conversationId: String?
    public let senderId: String?
    public let content: String?
    public let isTyping: Bool?
    
    enum CodingKeys: String, CodingKey {
        case event, type, topic, data, id, content
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case isTyping = "is_typing"
    }
    
    public var resolvedEvent: String {
        event ?? type ?? topic ?? ""
    }
}

nonisolated public struct WebSocketMessageDataDTO: Decodable, Sendable {
    let id: String?
    let conversationId: String
    let senderId: String
    let content: String
    let replyToId: String?
    let createdAt: String?
    let isTyping: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, content
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case replyToId = "reply_to_id"
        case createdAt = "created_at"
        case isTyping = "is_typing"
    }
    
    func toDomain(currentUserId: String) -> Message {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.date(from: createdAt ?? "") ?? Date()
        let role: MessageRole = (senderId == currentUserId) ? .user : .assistant
        
        return Message(
            id: id ?? UUID().uuidString,
            conversationId: conversationId,
            role: role,
            content: content,
            timestamp: timestamp,
            isError: false,
            status: .sent,
            replyToId: replyToId
        )
    }
}

public actor WebSocketActor {
    @Dependency(KeychainClient.self) var keychainClient
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var isConnected = false
    private var pingTimer: Timer?
    private let (stream, continuation) = AsyncStream.makeStream(of: WebSocketEventDTO.self)
    
    public init() {}
    
    public var eventStream: AsyncStream<WebSocketEventDTO> { stream }
    
    public func connect() async {
        guard !isConnected else { return }
        let sessionToken = await (try? keychainClient.loadSession())?.accessToken ?? ""
        guard let url = URL(string: "wss://ef21-2001-ee0-26e-7703-64c2-be98-cc71-71d6.ngrok-free.app/api/v1/ws?token=\(sessionToken)") else { return }
        
        print("[WebSocket] Connecting to topic socket: \(url.absoluteString)")
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true
        
        receiveNextMessage()
    }
    
    public func joinRoom(conversationId: String) {
        print("[WebSocket] Joining room channel for conversation: \(conversationId)")
        send(event: "subscribe", payload: ["conversation_id": conversationId])
        send(event: "join_room", payload: ["conversation_id": conversationId, "room": conversationId])
        send(event: "join", payload: ["room_id": conversationId])
    }
    
    private func receiveNextMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            Task {
                switch result {
                case let .success(wsMessage):
                    switch wsMessage {
                    case let .string(text):
                        print("[WebSocket RX Raw: \(text)")
                        print("==================================================")
                        print("📥 [CHECKPOINT 3] RAW WEBSOCKET FRAME RECEIVED FROM SERVER:")
                        print(text)
                        print("==================================================")
                        if let data = text.data(using: .utf8) {
//                           let dto = try? JSONDecoder().decode(WebSocketEventDTO.self, from: data) {
//                            self.continuation.yield(dto)
                            self.parseAndYield(data: data)
                        }
                        
                    case let .data(data):
                        print("[WebSocket RX Bytes]: \(data.count)")
                        self.parseAndYield(data: data)
                        
                        @unknown default:
                        break
                    }
                case let .failure(error):
                    print("[WebSocket] Error: \(error.localizedDescription)")
                    await self.disconnect()
                }
            }
        }
    }
    
    private func parseAndYield(data: Data) {
        if let dto = try? JSONDecoder().decode(WebSocketEventDTO.self, from: data) {
            print("🧩 [CHECKPOINT 4] JSON DECODED SUCCESSFULLY:")
            print("• Resolved Event: '\(dto.resolvedEvent)'")
            print("• Conversation ID: '\(dto.data?.conversationId ?? dto.conversationId ?? "nil")'")
            print("• Content: '\(dto.data?.content ?? dto.content ?? "nil")'")
            continuation.yield(dto)
        } else if let json = try? JSONSerialization.jsonObject(with: data) {
            print("[WebSocket Upparsed JSON]: \(json)")
        }
    }
    
    public func send(event: String, payload: [String: Any]) {
        let envelope: [String: Any] = ["event": event, "payload": payload]
        if let data = try? JSONSerialization.data(withJSONObject: envelope),
           let jsonString = String(data: data, encoding: .utf8) {
                print("[WebSocket TX]: \(jsonString)")
                webSocketTask?.send(.string(jsonString)) { error in
                    if let error = error {
                        print("[WebSocket Send Error]: \(error.localizedDescription)")
                    }
                }
            }
    }
    
    private func startPingTimer() {
        Task {
            while isConnected {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                guard isConnected, let task = webSocketTask else { break }
                task.sendPing { error in
                    if let error = error {
                        print("[WebSocket Ping Failed]: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    public func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        isConnected = false
    }
}

@DependencyClient
public struct PrivateWebSocketClient: Sendable {
    public var connect: @Sendable () async -> Void
    public var joinRoom: @Sendable (_ conversationId: String) async -> Void
    public var disconnect: @Sendable () async -> Void
    public var observeMessage: @Sendable (_ conversationId: String, _ currentUserId: String) -> AsyncStream<Message> = { _, _ in .finished }
    public var observeEdits: @Sendable (_ conversationId: String) -> AsyncStream<(id: String, content: String)> = { _ in .finished }
    public var observeDeletetions: @Sendable (_ conversationId: String) -> AsyncStream<String> = {_ in .finished }
    public var observeTypingStatus: @Sendable (_ conversationId: String) -> AsyncStream<Bool> = { _ in .finished }
    public var sendMessage: @Sendable (_ conversationId: String, _ content: String, _ replyToId: String?) async throws -> Void
    public var sendEdit: @Sendable (_ conversationId: String, _ messageId: String, _ content: String) async throws -> Void
    public var sendDelete: @Sendable (_ conversationId: String, _ messageId: String) async throws -> Void
    public var sendTypingStatus: @Sendable (_ conversationId: String, _ isTyping: Bool) async throws -> Void
}

extension PrivateWebSocketClient: DependencyKey {
    public static let liveValue: PrivateWebSocketClient = {
        let actor = WebSocketActor()
        
        return PrivateWebSocketClient(
            connect: { await actor.connect() },
            
            joinRoom: { conversationId in await actor.joinRoom(conversationId: conversationId) },
            
            disconnect: { await actor.disconnect() },
            
            observeMessage: { conversationId, currentUserId in
                AsyncStream { continuation in
                    Task {
                        for await dto in await actor.eventStream {
                            let event = dto.resolvedEvent
                            let msgData = dto.data
                            let targetConvId = msgData?.conversationId ?? dto.conversationId ?? ""
                            
                            if (event.isEmpty || event.contains("message") || event.contains("chat")),
                               targetConvId == conversationId || targetConvId.isEmpty {
                                
                                if let validData = msgData {
                                    continuation.yield(validData.toDomain(currentUserId: currentUserId))
                                } else if let text = dto.content {
                                    let fallbackMsg = Message(
                                        id: dto.id ?? UUID().uuidString,
                                        conversationId: conversationId,
                                        role: (dto.senderId == currentUserId) ? .user : .assistant,
                                        content: text,
                                        timestamp: Date(),
                                        isError: false,
                                        status: .sent
                                    )
                                    continuation.yield(fallbackMsg)
                                }
                            }
                        }
                        continuation.finish()
                    }
                }
            },
            
            observeEdits: { conversationId in
                AsyncStream { continuation in
                    Task {
                        for await dto in await actor.eventStream {
                            let event = dto.resolvedEvent
                            let msgData = dto.data
                            let targetConvId = msgData?.conversationId ?? dto.conversationId ?? ""
                            
                            if (event == "chat:edit"),
                               targetConvId == conversationId || targetConvId.isEmpty {
                                let id = msgData?.id ?? dto.id ?? ""
                                let content = msgData?.content ?? dto.content ?? ""
                                if !id.isEmpty {
                                    continuation.yield((id: id, content: content))
                                }
                            }
                        }
                        continuation.finish()
                    }
                }
            },
            
            observeDeletetions: { conversationId in
                AsyncStream { continuation in
                    Task {
                        for await dto in await actor.eventStream {
                            let event = dto.resolvedEvent
                            let msgData = dto.data
                            let targetConvId = msgData?.conversationId ?? dto.conversationId ?? ""
                            
                            if (event == "chat:delete"),
                               targetConvId == conversationId || targetConvId.isEmpty {
                                let id = msgData?.id ?? dto.id ?? ""
                                if !id.isEmpty {
                                    continuation.yield(id)
                                }
                            }
                        }
                        continuation.finish()
                    }
                }
            },
                        
            observeTypingStatus: { conversationId in
                AsyncStream { continuation in
                    Task {
                        for await dto in await actor.eventStream {
                            let event = dto.resolvedEvent
                            let msgData = dto.data
                            let targetConvId = msgData?.conversationId ?? dto.conversationId ?? ""
                            
                            if (event == "chat:typing"),
                               targetConvId == conversationId || targetConvId.isEmpty {
                                continuation.yield(msgData?.isTyping ?? dto.isTyping ?? false)
                            }
                        }
                        continuation.finish()
                    }
                }
            },
            
            sendMessage: { conversationId, content, replyToId in
                await actor.send(event: "chat:message", payload: [
                    "conversation_id": conversationId,
                    "content": content,
                    "reply_to_id": replyToId ?? ""
                ])
            },
            
            sendEdit: { conversationId, messageId, content in
                await actor.send(event: "chat:edit", payload: [
                    "conversation_id": conversationId,
                    "message_id": messageId,
                    "content": content
                ])
            },
            
            sendDelete: { conversationId, messageId in
                await actor.send(event: "chat:delete", payload: [
                    "conversation_id": conversationId,
                    "message_id": messageId,
                ])
            },
            
            sendTypingStatus: { conversationId, isTyping in
                await actor.send(event: "chat:typing", payload: [
                    "conversation_id": conversationId,
                    "is_typing": isTyping
                ])
            }
        )
    }()
}

extension DependencyValues {
    public var privateWebSocketClient: PrivateWebSocketClient {
        get { self[PrivateWebSocketClient.self] }
        set { self[PrivateWebSocketClient.self] = newValue }
    }
}
