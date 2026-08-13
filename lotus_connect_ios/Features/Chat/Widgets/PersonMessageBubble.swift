//
//  PersonMessageBubble.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 13/8/26.
//

import SwiftUI

public struct PersonMessageBubble: View {
    public let message: Message
    public let peerName: String
    public let replyingToMessage: Message?
    public let onReply: () -> Void
    public let onEdit: () -> Void
    public let onDelete: () -> Void
    
    public var isUser: Bool { message.role == .user }
    
    public var body: some View {
        HStack {
            if isUser { Spacer() }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                
                // Reply Bubble Header
                if let reply = replyingToMessage {
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(isUser ? Color.white.opacity(0.8) : Color.blue)
                            .frame(width: 3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(reply.role == .user ? "You" : peerName)
                                .font(.caption2.bold())
                                .foregroundColor(isUser ? .white.opacity(0.9) : .blue)
                            Text(reply.content)
                                .font(.caption2)
                                .lineLimit(1)
                                .foregroundColor(isUser ? .white.opacity(0.8) : .secondary)
                        }
                    }
                    .padding(6)
                    .background(isUser ? Color.black.opacity(0.15) : Color(.systemGray4))
                    .cornerRadius(8)
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
                            ProgressView().scaleEffect(0.5)
                        case .sent:
                            Image(systemName: "checkmark").font(.caption2).foregroundColor(.secondary)
                        case .read:
                            Image(systemName: "checkmark.seal.fill").font(.caption2).foregroundColor(.blue)
                        case .streaming:
                            EmptyView()
                        case .error:
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .contextMenu {
                Button {
                    onReply()
                } label: {
                    Label("Reply", systemImage: "arrowshape.turn.up.left")
                }
                
                Button {
                    UIPasteboard.general.string = message.content
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                
                if isUser {
                    Button {
                        onEdit()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            
            if !isUser { Spacer() }
        }
    }
}
