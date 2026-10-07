//
//  ContactsView.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 12/8/26.
//

import SwiftUI
import ComposableArchitecture

// MARK: - Color Hex Helper

private extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
    
    static func avatarColor(for string: String) -> Color {
        let colors: [Color] = [
            Color(hex: 0x3B82F6), // Blue
            Color(hex: 0x6366F1), // Indigo
            Color(hex: 0x8B5CF6), // Purple
            Color(hex: 0xEC4899), // Pink
            Color(hex: 0xF97316), // Orange
            Color(hex: 0x14B8A6), // Teal
            Color(hex: 0x10B981), // Emerald
            Color(hex: 0x06B6D4)  // Cyan
        ]
        let hash = abs(string.hashValue)
        return colors[hash % colors.count]
    }
}

// MARK: - Reducer

@Reducer
public struct ContactsFeature {
    
    // MARK: - Subtypes
    
    public enum Segment: String, CaseIterable, Identifiable, Equatable, Sendable {
        case contacts = "Contacts"
        case history = "History"
        case pending = "Pending"
        
        public var id: String { rawValue }
        
        // Aliases for seamless compatibility
        public static let friends = Segment.contacts
        public static let requests = Segment.pending
        public static let search = Segment.contacts
        
        public var iconName: String {
            switch self {
            case .contacts: return "person.2.fill"
            case .history: return "phone.fill"
            case .pending: return "person.badge.plus"
            }
        }
    }
    
    public struct ContactsError: Error, Equatable, Sendable {
        public let message: String
        public init(_ error: Error) {
            self.message = error.localizedDescription
        }
        public init(message: String) {
            self.message = message
        }
    }
    
    public enum AlertAction: Equatable, Sendable {
        case dismiss
        case retryInitialLoad
    }
    
    public enum ConfirmationDialogAction: Equatable, Sendable {
        case confirmRemoveFriend(User)
    }

    // MARK: - State
    
    @ObservableState
    public struct State: Equatable {
        public var contacts: IdentifiedArrayOf<User> = []
        public var pendingRequests: IdentifiedArrayOf<User> = []
        public var callHistory: [CallLog] = []
        public var searchResults: IdentifiedArrayOf<User> = []
        
        public var selectedSegment: Segment = .contacts
        public var searchQuery: String = ""
        
        public var isAddFriendPresented: Bool = false
        public var addFriendUsername: String = ""
        public var isSendingFriendRequest: Bool = false
        
        public var isLoading: Bool = false
        public var isSearching: Bool = false
        public var pendingActionUserIds: Set<String> = []
        public var sentRequestUserIds: Set<String> = []
        public var toastMessage: String? = nil
        
        @Presents public var alert: AlertState<AlertAction>?
        @Presents public var confirmationDialog: ConfirmationDialogState<ConfirmationDialogAction>?
        
        // Filtered contacts based on inline search
        public var filteredContacts: [User] {
            let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if query.isEmpty { return Array(contacts) }
            return contacts.filter { user in
                user.username.localizedCaseInsensitiveContains(query) ||
                (user.fullName?.localizedCaseInsensitiveContains(query) ?? false) ||
                user.email.localizedCaseInsensitiveContains(query)
            }
        }
        
        // Global search results excluding existing friends
        public var globalSearchResults: [User] {
            let friendIds = Set(contacts.map(\.id))
            return searchResults.filter { !friendIds.contains($0.id) }
        }
        
        // Call logs partitioned by time periods
        public var todayCallLogs: [CallLog] {
            let calendar = Calendar.current
            return callHistory.filter { calendar.isDateInToday($0.createdAt) }
        }
        
        public var yesterdayCallLogs: [CallLog] {
            let calendar = Calendar.current
            return callHistory.filter { calendar.isDateInYesterday($0.createdAt) }
        }
        
        public var olderCallLogs: [CallLog] {
            let calendar = Calendar.current
            return callHistory.filter { !calendar.isDateInToday($0.createdAt) && !calendar.isDateInYesterday($0.createdAt) }
        }
        
        public init() {}
    }
    
    // MARK: - Actions
    
    @CasePathable
    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppear
        case refreshPulled
        case segmentChanged(Segment)
        case searchQueryChanged(String)
        case clearSearchTapped
        
        // Add Friend Dialog
        case addFriendButtonTapped
        case addFriendDismissed
        case addFriendUsernameChanged(String)
        case sendFriendRequestSubmitted
        case sendFriendRequestSucceeded(username: String)
        case sendFriendRequestFailed(error: String)
        
        // Initial Concurrent Loading
        case initialDataLoaded(contacts: [User], requests: [User], callHistory: [CallLog])
        case initialDataFailed(ContactsError)
        case searchResultsResponse(Result<[User], ContactsError>)
        
        // User Actions on Friends / Requests
        case sendRequestButtonTapped(User)
        case sendRequestSucceeded(userId: String)
        case sendRequestFailed(userId: String, error: String)
        
        case acceptRequestButtonTapped(User)
        case acceptRequestSucceeded(userId: String, updatedContacts: [User])
        case acceptRequestFailed(user: User, index: Int, error: String)
        
        case rejectRequestButtonTapped(User)
        case rejectRequestSucceeded(userId: String)
        case rejectRequestFailed(user: User, index: Int, error: String)
        
        case removeFriendButtonTapped(User)
        case removeFriendConfirmed(User)
        case removeFriendSucceeded(userId: String)
        case removeFriendFailed(user: User, index: Int, error: String)
        
        case startChatTapped(User)
        case voiceCallTapped(User)
        case videoCallTapped(User)
        case callLogTapped(CallLog)
        
        case dismissToast
        
        // Presentation
        case alert(PresentationAction<AlertAction>)
        case confirmationDialog(PresentationAction<ConfirmationDialogAction>)
    }
    
    // MARK: - Dependencies & Reducer
    
    @Dependency(\.contactClient) var contactsClient
    @Dependency(\.continuousClock) var clock
    
    nonisolated private enum CancelID: Hashable, Sendable {
        case search
        case toast
    }
    
    public init() {}
    
    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce<State, Action> { state, action in
            switch action {
            // MARK: Lifecycle & Initial Concurrent Loading
            case .onAppear, .refreshPulled:
                state.isLoading = true
                state.alert = nil
                return .run { send in
                    async let contactsTask = contactsClient.fetchContacts()
                    async let requestsTask = contactsClient.fetchPendingRequests()
                    async let callHistoryTask = contactsClient.fetchCallHistory()
                    
                    do {
                        let (contacts, requests, callHistory) = try await (contactsTask, requestsTask, callHistoryTask)
                        await send(.initialDataLoaded(contacts: contacts, requests: requests, callHistory: callHistory))
                    } catch {
                        await send(.initialDataFailed(ContactsError(error)))
                    }
                }
                
            case let .initialDataLoaded(contacts, requests, callHistory):
                state.isLoading = false
                state.contacts = IdentifiedArray(uniqueElements: contacts)
                state.pendingRequests = IdentifiedArray(uniqueElements: requests)
                state.callHistory = callHistory
                return .none
                
            case let .initialDataFailed(error):
                state.isLoading = false
                state.alert = AlertState {
                    TextState("Error")
                } actions: {
                    ButtonState(action: .retryInitialLoad) {
                        TextState("Retry")
                    }
                    ButtonState(role: .cancel, action: .dismiss) {
                        TextState("OK")
                    }
                } message: {
                    TextState(error.message)
                }
                return .none
                
            case let .segmentChanged(segment):
                state.selectedSegment = segment
                return .none
                
            // MARK: Inline Search & Debounced Remote Search
            case let .searchQueryChanged(query):
                state.searchQuery = query
                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    state.searchResults.removeAll()
                    state.isSearching = false
                    return .cancel(id: CancelID.search)
                }
                state.isSearching = true
                return .run { [trimmed] send in
                    try await clock.sleep(for: .milliseconds(300))
                    do {
                        let results = try await contactsClient.searchUsers(trimmed)
                        await send(.searchResultsResponse(.success(results)))
                    } catch {
                        await send(.searchResultsResponse(.failure(ContactsError(error))))
                    }
                }
                .cancellable(id: CancelID.search, cancelInFlight: true)
                
            case .clearSearchTapped:
                state.searchQuery = ""
                state.searchResults.removeAll()
                state.isSearching = false
                return .cancel(id: CancelID.search)
                
            case let .searchResultsResponse(.success(results)):
                state.isSearching = false
                state.searchResults = IdentifiedArray(uniqueElements: results)
                return .none
                
            case let .searchResultsResponse(.failure(error)):
                state.isSearching = false
                state.alert = AlertState {
                    TextState("Search Failed")
                } actions: {
                    ButtonState(role: .cancel, action: .dismiss) { TextState("OK") }
                } message: {
                    TextState(error.message)
                }
                return .none
                
            // MARK: Add Friend Modal
            case .addFriendButtonTapped:
                state.isAddFriendPresented = true
                state.addFriendUsername = ""
                return .none
                
            case .addFriendDismissed:
                state.isAddFriendPresented = false
                state.addFriendUsername = ""
                state.isSendingFriendRequest = false
                return .none
                
            case let .addFriendUsernameChanged(username):
                state.addFriendUsername = username
                return .none
                
            case .sendFriendRequestSubmitted:
                let username = state.addFriendUsername.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !username.isEmpty else { return .none }
                state.isSendingFriendRequest = true
                
                return .run { send in
                    do {
                        try await contactsClient.sendFriendRequestByUsername(username)
                        await send(.sendFriendRequestSucceeded(username: username))
                    } catch {
                        await send(.sendFriendRequestFailed(error: error.localizedDescription))
                    }
                }
                
            case let .sendFriendRequestSucceeded(username):
                state.isSendingFriendRequest = false
                state.isAddFriendPresented = false
                state.addFriendUsername = ""
                state.toastMessage = "Friend request sent to @\(username)"
                return .run { send in
                    try await clock.sleep(for: .seconds(3))
                    await send(.dismissToast)
                }
                .cancellable(id: CancelID.toast, cancelInFlight: true)
                
            case let .sendFriendRequestFailed(error):
                state.isSendingFriendRequest = false
                state.alert = AlertState {
                    TextState("Failed to Send Request")
                } actions: {
                    ButtonState(role: .cancel, action: .dismiss) { TextState("OK") }
                } message: {
                    TextState(error)
                }
                return .none
                
            // MARK: Send Request From Search
            case let .sendRequestButtonTapped(user):
                state.pendingActionUserIds.insert(user.id)
                return .run { send in
                    do {
                        try await contactsClient.sendFriendRequest(user.id)
                        await send(.sendRequestSucceeded(userId: user.id))
                    } catch {
                        await send(.sendRequestFailed(userId: user.id, error: error.localizedDescription))
                    }
                }
                
            case let .sendRequestSucceeded(userId):
                state.pendingActionUserIds.remove(userId)
                state.sentRequestUserIds.insert(userId)
                return .none
                
            case let .sendRequestFailed(userId, error):
                state.pendingActionUserIds.remove(userId)
                state.alert = AlertState {
                    TextState("Error")
                } actions: {
                    ButtonState(role: .cancel, action: .dismiss) { TextState("OK") }
                } message: {
                    TextState("Failed to send request: \(error)")
                }
                return .none
                
            // MARK: Accept Request (Optimistic with Rollback)
            case let .acceptRequestButtonTapped(user):
                guard let existingIndex = state.pendingRequests.index(id: user.id) else { return .none }
                state.pendingRequests.remove(id: user.id)
                state.pendingActionUserIds.insert(user.id)
                
                return .run { send in
                    do {
                        try await contactsClient.acceptFriendRequest(user.id)
                        let updatedContacts = try await contactsClient.fetchContacts()
                        await send(.acceptRequestSucceeded(userId: user.id, updatedContacts: updatedContacts))
                    } catch {
                        await send(.acceptRequestFailed(user: user, index: existingIndex, error: error.localizedDescription))
                    }
                }
                
            case let .acceptRequestSucceeded(userId, updatedContacts):
                state.pendingActionUserIds.remove(userId)
                state.contacts = IdentifiedArray(uniqueElements: updatedContacts)
                state.toastMessage = "Friend request accepted"
                return .run { send in
                    try await clock.sleep(for: .seconds(3))
                    await send(.dismissToast)
                }
                .cancellable(id: CancelID.toast, cancelInFlight: true)
                
            case let .acceptRequestFailed(user, index, error):
                state.pendingActionUserIds.remove(user.id)
                if index <= state.pendingRequests.count {
                    state.pendingRequests.insert(user, at: index)
                } else {
                    state.pendingRequests.append(user)
                }
                state.alert = AlertState {
                    TextState("Error")
                } actions: {
                    ButtonState(role: .cancel, action: .dismiss) { TextState("OK") }
                } message: {
                    TextState("Failed to accept request: \(error)")
                }
                return .none
                
            // MARK: Reject Request (Optimistic with Rollback)
            case let .rejectRequestButtonTapped(user):
                guard let existingIndex = state.pendingRequests.index(id: user.id) else { return .none }
                state.pendingRequests.remove(id: user.id)
                state.pendingActionUserIds.insert(user.id)
                
                return .run { send in
                    do {
                        try await contactsClient.rejectFriendRequest(user.id)
                        await send(.rejectRequestSucceeded(userId: user.id))
                    } catch {
                        await send(.rejectRequestFailed(user: user, index: existingIndex, error: error.localizedDescription))
                    }
                }
                
            case let .rejectRequestSucceeded(userId):
                state.pendingActionUserIds.remove(userId)
                state.toastMessage = "Friend request declined"
                return .run { send in
                    try await clock.sleep(for: .seconds(3))
                    await send(.dismissToast)
                }
                .cancellable(id: CancelID.toast, cancelInFlight: true)
                
            case let .rejectRequestFailed(user, index, error):
                state.pendingActionUserIds.remove(user.id)
                if index <= state.pendingRequests.count {
                    state.pendingRequests.insert(user, at: index)
                } else {
                    state.pendingRequests.append(user)
                }
                state.alert = AlertState {
                    TextState("Error")
                } actions: {
                    ButtonState(role: .cancel, action: .dismiss) { TextState("OK") }
                } message: {
                    TextState("Failed to decline request: \(error)")
                }
                return .none
                
            // MARK: Remove Contact Confirmation & Rollback
            case let .removeFriendButtonTapped(user):
                let displayName = user.fullName ?? user.username
                state.confirmationDialog = ConfirmationDialogState {
                    TextState("Remove Contact")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmRemoveFriend(user)) {
                        TextState("Remove \(displayName)")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("Are you sure you want to remove \(displayName) from your contacts?")
                }
                return .none
                
            case let .confirmationDialog(.presented(.confirmRemoveFriend(user))):
                return .send(.removeFriendConfirmed(user))
                
            case let .removeFriendConfirmed(user):
                guard let existingIndex = state.contacts.index(id: user.id) else { return .none }
                state.contacts.remove(id: user.id)
                state.pendingActionUserIds.insert(user.id)
                
                return .run { send in
                    do {
                        try await contactsClient.removeFriend(user.id)
                        await send(.removeFriendSucceeded(userId: user.id))
                    } catch {
                        await send(.removeFriendFailed(user: user, index: existingIndex, error: error.localizedDescription))
                    }
                }
                
            case let .removeFriendSucceeded(userId):
                state.pendingActionUserIds.remove(userId)
                state.toastMessage = "Friend removed"
                return .run { send in
                    try await clock.sleep(for: .seconds(3))
                    await send(.dismissToast)
                }
                .cancellable(id: CancelID.toast, cancelInFlight: true)
                
            case let .removeFriendFailed(user, index, error):
                state.pendingActionUserIds.remove(user.id)
                if index <= state.contacts.count {
                    state.contacts.insert(user, at: index)
                } else {
                    state.contacts.append(user)
                }
                state.alert = AlertState {
                    TextState("Error")
                } actions: {
                    ButtonState(role: .cancel, action: .dismiss) { TextState("OK") }
                } message: {
                    TextState("Failed to remove contact: \(error)")
                }
                return .none
                
            case .startChatTapped, .voiceCallTapped, .videoCallTapped, .callLogTapped:
                return .none
                
            case .dismissToast:
                state.toastMessage = nil
                return .none
                
            // MARK: Presentation Action Handlers
            case .alert(.presented(.retryInitialLoad)):
                return .send(.onAppear)
                
            case .alert, .confirmationDialog, .binding:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$confirmationDialog, action: \.confirmationDialog)
    }
}

// MARK: - Main Contacts View

public struct ContactsView: View {
    @Bindable var store: StoreOf<ContactsFeature>
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var tabIndicatorNamespace
    
    public init(store: StoreOf<ContactsFeature>) {
        self.store = store
    }
    
    // Gradient definitions matching lotus_connect
    private var indicatorGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color(hex: 0xDEC08F),
                    Color(hex: 0xF7D9A4),
                    Color(hex: 0xB7CEA0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(hex: 0x6F5B40),
                    Color(hex: 0xC07F39),
                    Color(hex: 0xE29F52)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    private var indicatorShadowColor: Color {
        colorScheme == .dark
            ? Color(hex: 0xDEC08F).opacity(0.28)
            : Color(hex: 0x6F5B40).opacity(0.28)
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // MARK: Custom Granular Gradient Tab Bar
                tabBarView
                
                // MARK: Tab Content
                TabView(selection: $store.selectedSegment.sending(\.segmentChanged)) {
                    FriendsTabView(store: store)
                        .tag(ContactsFeature.Segment.contacts)
                    
                    HistoryTabView(store: store)
                        .tag(ContactsFeature.Segment.history)
                    
                    PendingRequestsTabView(store: store)
                        .tag(ContactsFeature.Segment.pending)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            
            // MARK: Toast Banner
            if let message = store.toastMessage {
                toastView(message: message)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .navigationTitle("Contacts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 8) {
                    Button {
                        store.send(.addFriendButtonTapped)
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .accessibilityLabel("Add Friend")
                    
                    Button {
                        store.send(.refreshPulled)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .accessibilityLabel("Refresh")
                }
            }
        }
        .sheet(isPresented: $store.isAddFriendPresented) {
            AddFriendSheetView(store: store)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .confirmationDialog($store.scope(state: \.confirmationDialog, action: \.confirmationDialog))
        .onAppear {
            store.send(.onAppear)
        }
    }
    
    // MARK: - Tab Bar View
    private var tabBarView: some View {
        let isDark = colorScheme == .dark
        let containerBg = isDark
            ? Color.white.opacity(0.06)
            : Color(uiColor: .tertiarySystemFill).opacity(0.65)
        
        return HStack(spacing: 0) {
            ForEach(ContactsFeature.Segment.allCases) { segment in
                tabButton(for: segment, isDark: isDark)
            }
        }
        .padding(3)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(containerBg)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
    
    @ViewBuilder
    private func tabButton(for segment: ContactsFeature.Segment, isDark: Bool) -> some View {
        let isSelected = store.selectedSegment == segment
        let pendingCount = store.pendingRequests.count
        
        Button {
            _ = withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                store.send(.segmentChanged(segment))
            }
        } label: {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(indicatorGradient)
                        .shadow(color: indicatorShadowColor, radius: 8, x: 0, y: 2)
                        .matchedGeometryEffect(id: "activeTabIndicator", in: tabIndicatorNamespace)
                }
                
                HStack(spacing: 6) {
                    Text(segment.rawValue)
                        .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                        .tracking(-0.2)
                        .foregroundColor(
                            isSelected
                                ? (isDark ? Color(hex: 0x271905) : .white)
                                : Color.secondary.opacity(0.85)
                        )
                    
                    if segment == .pending && pendingCount > 0 {
                        Text("\(pendingCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(
                                isSelected
                                    ? (isDark ? Color(hex: 0x271905) : .white)
                                    : (isDark ? Color(hex: 0x271905) : .white)
                            )
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(
                                Capsule().fill(
                                    isSelected
                                        ? (isDark ? Color(hex: 0x271905).opacity(0.18) : Color.white.opacity(0.3))
                                        : (isDark ? Color(hex: 0xDEC08F) : Color(hex: 0xC07F39))
                                )
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .frame(height: 38)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Toast View
    private func toastView(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color(hex: 0x16A34A))
                .font(.system(size: 16, weight: .bold))
            
            Text(message)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

// MARK: - Friends Tab View

public struct FriendsTabView: View {
    @Bindable var store: StoreOf<ContactsFeature>
    @Environment(\.colorScheme) private var colorScheme
    
    public init(store: StoreOf<ContactsFeature>) {
        self.store = store
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // MARK: Styled Inline Search Bar
                searchBarView
                
                // MARK: Content States
                if store.isLoading && store.contacts.isEmpty && store.searchResults.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.1)
                        Text("Loading contacts...")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 80)
                } else if store.searchQuery.isEmpty && store.contacts.isEmpty {
                    emptyFriendsView
                } else {
                    contactsListContent
                }
            }
            .padding(.bottom, 24)
        }
        .refreshable {
            await store.send(.refreshPulled).finish()
        }
    }
    
    // MARK: - Search Bar
    private var searchBarView: some View {
        let isDark = colorScheme == .dark
        
        return HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary.opacity(0.8))
            
            TextField("Search friends...", text: $store.searchQuery.sending(\.searchQueryChanged))
                .font(.system(size: 14))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            
            if !store.searchQuery.isEmpty {
                Button {
                    store.send(.clearSearchTapped)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isDark ? Color(uiColor: .secondarySystemBackground) : Color.white)
                .shadow(color: Color.black.opacity(isDark ? 0.2 : 0.03), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(isDark ? 0.3 : 0.45), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }
    
    // MARK: - Contacts List Content
    @ViewBuilder
    private var contactsListContent: some View {
        let isSearching = !store.searchQuery.isEmpty
        let filtered = store.filteredContacts
        let globalResults = store.globalSearchResults
        
        if isSearching {
            // Local matching friends section
            if !filtered.isEmpty {
                sectionHeader(title: "MY FRIENDS", count: filtered.count, color: .accentColor)
                ForEach(filtered) { user in
                    ContactCardView(user: user, store: store)
                }
            }
            
            // Global search results section
            if !globalResults.isEmpty {
                sectionHeader(title: "GLOBAL SEARCH & ADD FRIENDS", count: globalResults.count, color: .secondary)
                ForEach(globalResults) { user in
                    GlobalUserCardView(user: user, store: store)
                }
            }
            
            // Empty search state
            if filtered.isEmpty && globalResults.isEmpty && !store.isSearching {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.4))
                        .padding(.top, 40)
                    Text("No Matching Results")
                        .font(.system(size: 16, weight: .bold))
                    Text("No contacts or users match '\(store.searchQuery)'")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 24)
            }
        } else {
            // All friends section
            sectionHeader(title: "ALL FRIENDS", count: store.contacts.count, color: .secondary)
            ForEach(store.contacts) { user in
                ContactCardView(user: user, store: store)
            }
        }
    }
    
    private func sectionHeader(title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11.5, weight: .bold))
                .tracking(0.8)
                .foregroundColor(color)
            
            Text("\(count)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(color.opacity(0.12))
                )
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
    
    // MARK: - Empty Friends View
    private var emptyFriendsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.35))
                .padding(.top, 60)
            
            Text("No Contacts Found")
                .font(.system(size: 18, weight: .bold))
            
            Text("Send friend requests to connect with your friends.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                store.send(.addFriendButtonTapped)
            } label: {
                Label("Add Friend", systemImage: "person.badge.plus")
                    .font(.system(size: 14, weight: .bold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .padding(.top, 8)
        }
    }
}

// MARK: - Contact Card View (Matching Flutter ContactCard)

public struct ContactCardView: View {
    let user: User
    let store: StoreOf<ContactsFeature>
    @Environment(\.colorScheme) private var colorScheme
    
    public init(user: User, store: StoreOf<ContactsFeature>) {
        self.user = user
        self.store = store
    }
    
    public var body: some View {
        let isDark = colorScheme == .dark
        let displayName = user.fullName?.isEmpty == false ? user.fullName! : user.username
        let initials = String(displayName.prefix(1)).uppercased()
        let isOnline = true // Presence status
        
        let cardColor = isDark
            ? Color(uiColor: .secondarySystemGroupedBackground)
            : Color.white
        let borderColor = Color(uiColor: .separator)
            .opacity(isDark ? 0.3 : 0.45)
        let shadowColor = Color.black
            .opacity(isDark ? 0.25 : 0.04)
        
        return HStack(spacing: 14) {
            // MARK: Avatar + Online Presence Dot
            ZStack(alignment: .bottomTrailing) {
                if let avatarUrl = user.avatarUrl, let url = URL(string: avatarUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        avatarFallback(initials: initials, username: user.username)
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                    avatarFallback(initials: initials, username: user.username)
                }
                
                // Presence indicator dot
                Circle()
                    .fill(Color(hex: 0x22C55E))
                    .frame(width: 13, height: 13)
                    .overlay(
                        Circle().stroke(cardColor, lineWidth: 2.2)
                    )
            }
            
            // MARK: Name & Subtitle
            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .font(.system(size: 15.5, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 5) {
                    if isOnline {
                        Circle()
                            .fill(Color(hex: 0x22C55E))
                            .frame(width: 6, height: 6)
                        
                        Text("Online")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(isDark ? Color.green.opacity(0.85) : Color(hex: 0x16A34A))
                    } else {
                        Text("@\(user.username)")
                            .font(.system(size: 12.5))
                            .foregroundColor(.secondary.opacity(0.75))
                    }
                }
                .lineLimit(1)
            }
            
            Spacer(minLength: 8)
            
            // MARK: Action Buttons
            HStack(spacing: 4) {
                // Chat button
                actionIconButton(icon: "bubble.left.fill", color: .accentColor, tooltip: "Chat") {
                    store.send(.startChatTapped(user))
                }
                
                // Audio call button
                actionIconButton(icon: "phone.fill", color: Color(hex: 0x2563EB), tooltip: "Voice Call") {
                    store.send(.voiceCallTapped(user))
                }
                
                // Video call button
                actionIconButton(icon: "video.fill", color: Color(hex: 0x16A34A), tooltip: "Video Call") {
                    store.send(.videoCallTapped(user))
                }
                
                // More menu button (Unfriend)
                Menu {
                    Button(role: .destructive) {
                        store.send(.removeFriendButtonTapped(user))
                    } label: {
                        Label("Unfriend", systemImage: "person.badge.minus")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.75))
                        .frame(width: 30, height: 34)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardColor)
                .shadow(color: shadowColor, radius: 10, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    
    private func avatarFallback(initials: String, username: String) -> some View {
        Circle()
            .fill(Color.avatarColor(for: username).opacity(0.2))
            .frame(width: 44, height: 44)
            .overlay(
                Text(initials)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Color.avatarColor(for: username))
            )
    }
    
    private func actionIconButton(icon: String, color: Color, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tooltip)
    }
}

// MARK: - Global Search User Card View

public struct GlobalUserCardView: View {
    let user: User
    let store: StoreOf<ContactsFeature>
    @Environment(\.colorScheme) private var colorScheme
    
    public init(user: User, store: StoreOf<ContactsFeature>) {
        self.user = user
        self.store = store
    }
    
    public var body: some View {
        let isDark = colorScheme == .dark
        let displayName = user.fullName?.isEmpty == false ? user.fullName! : user.username
        let initials = String(displayName.prefix(1)).uppercased()
        let isPendingAction = store.pendingActionUserIds.contains(user.id)
        let isSent = store.sentRequestUserIds.contains(user.id) || user.friendshipStatus == "pending"
        
        let cardColor = isDark
            ? Color(uiColor: .secondarySystemGroupedBackground)
            : Color.white
        let borderColor = Color(uiColor: .separator)
            .opacity(isDark ? 0.3 : 0.45)
        let shadowColor = Color.black
            .opacity(isDark ? 0.2 : 0.04)
        
        return HStack(spacing: 14) {
            Circle()
                .fill(Color.avatarColor(for: user.username).opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(initials)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color.avatarColor(for: user.username))
                )
            
            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("@\(user.username)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isPendingAction {
                ProgressView()
                    .scaleEffect(0.85)
                    .frame(width: 60)
            } else if isSent {
                Text("Requested")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: 0xD97706))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(Color(hex: 0xFEF3C7))
                    )
            } else {
                Button {
                    store.send(.sendRequestButtonTapped(user))
                } label: {
                    Label("Add", systemImage: "person.badge.plus")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardColor)
                .shadow(color: shadowColor, radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

// MARK: - History Tab View (Matching Flutter HistoryScreen)

public struct HistoryTabView: View {
    let store: StoreOf<ContactsFeature>
    
    public init(store: StoreOf<ContactsFeature>) {
        self.store = store
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if store.callHistory.isEmpty {
                    emptyHistoryView
                } else {
                    let today = store.todayCallLogs
                    let yesterday = store.yesterdayCallLogs
                    let older = store.olderCallLogs
                    
                    if !today.isEmpty {
                        historySectionHeader(title: "TODAY")
                        ForEach(today) { log in
                            HistoryCardView(log: log, store: store)
                        }
                    }
                    
                    if !yesterday.isEmpty {
                        historySectionHeader(title: "YESTERDAY")
                        ForEach(yesterday) { log in
                            HistoryCardView(log: log, store: store)
                        }
                    }
                    
                    if !older.isEmpty {
                        historySectionHeader(title: "OLDER")
                        ForEach(older) { log in
                            HistoryCardView(log: log, store: store)
                        }
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .refreshable {
            await store.send(.refreshPulled).finish()
        }
    }
    
    private func historySectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .tracking(0.6)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }
    
    private var emptyHistoryView: some View {
        VStack(spacing: 16) {
            Image(systemName: "phone.down.left.circle")
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.35))
                .padding(.top, 70)
            
            Text("No Call History Logs")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Recent audio and video calls will appear here.")
                .font(.system(size: 13.5))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - History Card View (Matching Flutter HistoryCard)

public struct HistoryCardView: View {
    let log: CallLog
    let store: StoreOf<ContactsFeature>
    @Environment(\.colorScheme) private var colorScheme
    
    public init(log: CallLog, store: StoreOf<ContactsFeature>) {
        self.log = log
        self.store = store
    }
    
    public var body: some View {
        let isDark = colorScheme == .dark
        let peerName = log.hostName ?? log.username ?? "Unknown User"
        let initials = String(peerName.prefix(1)).uppercased()
        let isMissed = log.isMissed
        
        let cardColor = isDark
            ? Color(uiColor: .secondarySystemGroupedBackground)
            : Color.white
        let borderColor = Color(uiColor: .separator)
            .opacity(isDark ? 0.3 : 0.45)
        let shadowColor = Color.black
            .opacity(isDark ? 0.25 : 0.04)
        
        let timeFormatter: DateFormatter = {
            let df = DateFormatter()
            df.dateFormat = "h:mm a"
            return df
        }()
        
        return HStack(spacing: 14) {
            // MARK: Avatar with Call Type Badge
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(isMissed ? Color.red.opacity(0.15) : Color.accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(initials)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(isMissed ? .red : .accentColor)
                    )
                
                // Status badge dot
                Circle()
                    .fill(isMissed ? Color(hex: 0xEF4444) : Color(hex: 0x16A34A))
                    .frame(width: 15, height: 15)
                    .overlay(
                        Image(systemName: isMissed ? "xmark" : (log.isVideo ? "video.fill" : "phone.fill"))
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .overlay(
                        Circle().stroke(cardColor, lineWidth: 2)
                    )
            }
            
            // MARK: Peer Info & Details
            VStack(alignment: .leading, spacing: 3) {
                Text(peerName)
                    .font(.system(size: 15.5, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    Image(systemName: log.isVideo ? "video.fill" : "phone.fill")
                        .font(.system(size: 11))
                        .foregroundColor(isMissed ? Color(hex: 0xEF4444) : .secondary)
                    
                    Text(log.isVideo ? "Video Call" : "Voice Call")
                        .font(.system(size: 13))
                        .foregroundColor(isMissed ? Color(hex: 0xEF4444) : .secondary)
                    
                    if log.durationSeconds > 0 {
                        Circle()
                            .fill(Color.secondary.opacity(0.5))
                            .frame(width: 3.5, height: 3.5)
                        
                        Text(formatDuration(log.durationSeconds))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    } else if isMissed {
                        Text("• Missed")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: 0xEF4444))
                    }
                }
            }
            
            Spacer()
            
            // MARK: Timestamp & Callback Button
            HStack(spacing: 10) {
                Text(timeFormatter.string(from: log.createdAt))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Button {
                    store.send(.callLogTapped(log))
                } label: {
                    Image(systemName: log.isVideo ? "video.fill" : "phone.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 34, height: 34)
                        .background(Color(uiColor: .tertiarySystemFill))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardColor)
                .shadow(color: shadowColor, radius: 10, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        if m > 0 {
            return "\(m)m \(s)s"
        }
        return "\(s)s"
    }
}

// MARK: - Pending Requests Tab View (Matching Flutter AllFriendRequestsScreen)

public struct PendingRequestsTabView: View {
    let store: StoreOf<ContactsFeature>
    
    public init(store: StoreOf<ContactsFeature>) {
        self.store = store
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if store.pendingRequests.isEmpty {
                    emptyRequestsView
                } else {
                    ForEach(store.pendingRequests) { user in
                        RequestCardView(user: user, store: store)
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .refreshable {
            await store.send(.refreshPulled).finish()
        }
    }
    
    private var emptyRequestsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.badge.shield.checkmark")
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.35))
                .padding(.top, 70)
            
            Text("No Pending Requests")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Friend requests sent to you will appear here.")
                .font(.system(size: 13.5))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Request Card View (Matching Flutter RequestCard)

public struct RequestCardView: View {
    let user: User
    let store: StoreOf<ContactsFeature>
    @Environment(\.colorScheme) private var colorScheme
    
    public init(user: User, store: StoreOf<ContactsFeature>) {
        self.user = user
        self.store = store
    }
    
    public var body: some View {
        let isDark = colorScheme == .dark
        let displayName = user.fullName?.isEmpty == false ? user.fullName! : user.username
        let initials = String(displayName.prefix(1)).uppercased()
        let isPendingAction = store.pendingActionUserIds.contains(user.id)
        
        let cardColor = isDark
            ? Color(uiColor: .secondarySystemGroupedBackground)
            : Color.white
        let borderColor = Color(uiColor: .separator)
            .opacity(isDark ? 0.3 : 0.45)
        let shadowColor = Color.black
            .opacity(isDark ? 0.25 : 0.04)
        
        return HStack(spacing: 14) {
            // MARK: Avatar
            ZStack {
                if let avatarUrl = user.avatarUrl, let url = URL(string: avatarUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        avatarFallback(initials: initials, username: user.username)
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                    avatarFallback(initials: initials, username: user.username)
                }
            }
            
            // MARK: Name & Subtitle
            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .font(.system(size: 15.5, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundColor(.primary)
                
                Text("@\(user.username)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.75))
            }
            
            Spacer()
            
            // MARK: Accept & Reject Actions
            if isPendingAction {
                ProgressView()
                    .scaleEffect(0.9)
                    .frame(width: 72)
            } else {
                HStack(spacing: 12) {
                    // Accept button
                    Button {
                        store.send(.acceptRequestButtonTapped(user))
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(Color(hex: 0x16A34A))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Accept")
                    
                    // Reject button
                    Button {
                        store.send(.rejectRequestButtonTapped(user))
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(Color(hex: 0xEF4444).opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reject")
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardColor)
                .shadow(color: shadowColor, radius: 10, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    
    private func avatarFallback(initials: String, username: String) -> some View {
        Circle()
            .fill(Color.avatarColor(for: username).opacity(0.2))
            .frame(width: 44, height: 44)
            .overlay(
                Text(initials)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Color.avatarColor(for: username))
            )
    }
}

// MARK: - Add Friend Sheet View (Matching Flutter _showAddFriendDialog)

public struct AddFriendSheetView: View {
    @Bindable var store: StoreOf<ContactsFeature>
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    public init(store: StoreOf<ContactsFeature>) {
        self.store = store
    }
    
    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Enter username to send friend request")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                
                HStack(spacing: 10) {
                    Image(systemName: "at")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16, weight: .semibold))
                    
                    TextField("e.g. username", text: $store.addFriendUsername.sending(\.addFriendUsernameChanged))
                        .font(.system(size: 15))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    if !store.addFriendUsername.isEmpty {
                        Button {
                            store.send(.addFriendUsernameChanged(""))
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(colorScheme == .dark ? Color(uiColor: .secondarySystemBackground) : Color(uiColor: .systemGray6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(uiColor: .separator).opacity(0.5), lineWidth: 1)
                )
                
                Spacer()
                
                Button {
                    store.send(.sendFriendRequestSubmitted)
                } label: {
                    HStack {
                        Spacer()
                        if store.isSendingFriendRequest {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Send Request")
                                .font(.system(size: 16, weight: .bold))
                        }
                        Spacer()
                    }
                    .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .disabled(store.addFriendUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isSendingFriendRequest)
            }
            .padding(20)
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        store.send(.addFriendDismissed)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.visible)
    }
}
