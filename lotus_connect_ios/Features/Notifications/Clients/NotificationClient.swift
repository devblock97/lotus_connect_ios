//
//  NotificationClient.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 28/8/26.
//

import Dependencies

nonisolated private struct EmptyResponseDTO: Decodable, Sendable { }

public struct NotificationClient: Sendable {
    public var fetchNotifications: @Sendable () async throws -> [AppNotification]
    
    public var markAllRead: @Sendable () async throws -> Void
    
    public var markAsRead: @Sendable (_ notification: String) async throws -> Void
}

extension NotificationClient: DependencyKey {
    public static let liveValue: NotificationClient = {
        @Dependency(\.httpClient) var httpClient
        
        return NotificationClient(
            fetchNotifications: {
                let notifications: [AppNotification] = try await httpClient.request("/users/notifications", .get, nil, nil)
                return notifications
            },
            markAllRead: {
                let _: EmptyResponseDTO = try await httpClient.request("/users/notifications/read", .get, nil, nil)
            },
            markAsRead: { notificationId in
                let _: EmptyResponseDTO = try await httpClient.request("/api/v1/users/notifications/\(notificationId)/read", .patch, nil, nil)
            }
        )
    }()
}

extension DependencyValues {
    public var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}
