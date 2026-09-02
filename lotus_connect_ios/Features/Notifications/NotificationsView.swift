//
//  NotificationsView.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 28/8/26.
//
import SwiftUI
import ComposableArchitecture

@Reducer
public struct NotificationsFeature {
    @ObservableState
    public struct State: Equatable {
        public var notifications: IdentifiedArrayOf<AppNotification> = []
        public var isLoading: Bool = false
        public var errorMessage: String?
        
        public var hasUnread: Bool {
            notifications.contains(where: { $0.isRead })
        }
        
        public init(notifications: [AppNotification] = []) {
            self.notifications = IdentifiedArray(uniqueElements: notifications)
        }
    }
    
    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppear
        case refreshPulled
        case notificationsLoaded(TaskResult<[AppNotification]>)
        case notificationTapped(AppNotification)
        case navigateToChat(conversationId: String)
        case navigateToCalls
        case navigateToContacts
    }
    
    public init() {}
    
    @Dependency(\.notificationClient) var notificationClient
    
    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear, .refreshPulled:
                state.isLoading = true
                state.errorMessage = nil
                return .run { send in
                    await send(.notificationsLoaded(TaskResult {
                        try await notificationClient.fetchNotifications()
                    }))
                }
                
            case let .notificationsLoaded(.success(notifications)):
                state.isLoading = false
                state.notifications = IdentifiedArray(uniqueElements: notifications)
                return .none
                
            case let .notificationsLoaded(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
                                
            case let .notificationTapped(notification):
                if !notification.isRead {
                    state.notifications[id: notification.id]?.isRead = true
                }
                
                guard let data = notification.data else { return .none }
                
                switch data.type {
                case .chat:
                    if let conversationId = data.conversationId {
                        return .send(.navigateToChat(conversationId: conversationId))
                    }
                    
                case .missedCall:
                    return .send(.navigateToCalls)
                    
                case .friendAccept, .friendRequest:
                    return .send(.navigateToContacts)
                    
                case .unknown, .none:
                    break
                }
                
                return .run { _ in
                    try? await notificationClient.markAsRead(notification.id)
                }
                                
            case .navigateToContacts, .navigateToChat, .navigateToCalls, .binding:
                return .none
            }
        }
    }
}

struct NotificationsView: View {
    @Bindable var store: StoreOf<NotificationsFeature>
    
    public init(store: StoreOf<NotificationsFeature>) {
        self.store = store
    }
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            if store.isLoading && store.notifications.isEmpty {
                ProgressView("Loading notifications...")
            } else if store.notifications.isEmpty {
                EmptyNotificationsStateView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(store.notifications) { notification in
                            NotificationCardView(
                                notification: notification,
                                onTap: { store.send(.notificationTapped(notification)) }
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                
                Button {
                    store.send(.onAppear)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh")
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
    
}

struct NotificationCardView: View {
    let notification: AppNotification
    let onTap: () -> Void
    
    private var isMissedCall: Bool {
        notification.data?.type == NotificationType.missedCall
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isMissedCall ? Color.red.opacity(0.12) : Color.blue.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: isMissedCall ? "phone.arrow.up.right" : "bubble.left.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(isMissedCall ? .red : .blue)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(notification.title)
                            .font(.system(size: 15, weight: notification.isRead ? .regular : .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if !notification.isRead {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 8)
                        }
                    }
                    Text(notification.body)
                        .font(.system(size: 13,))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(notification.createdAt.formatted(.dateTime.month().day().hour().minute()))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        notification.isRead ? Color.clear : Color.blue.opacity(0.2),
                        lineWidth: notification.isRead ? 0 : 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct EmptyNotificationsStateView: View {
    var body: some View {
        VStack {
            Text("All caught up!")
                .font(.title3.bold())
            Text("You don't have any notifications at the moment.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
