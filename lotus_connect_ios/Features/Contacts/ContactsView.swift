//
//  ContactsView.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 12/8/26.
//

import SwiftUI
import ComposableArchitecture

// MARK: - Reducer

@Reducer
public struct ContactsFeature {
    
    // MARK: - Subtypes
    
    public enum Segment: String, CaseIterable, Identifiable, Equatable, Sendable {
        case contacts = "Contacts"
        case requests = "Requests"
        case search = "Search"
        
        public var id: String { rawValue }
        
        public var iconName: String {
            switch self {
            case .contacts: return "person.2.fill"
            case .requests: return "person.badge.plus"
            case .search: return "magnifyingglass"
            }
        }
    }
    
    public struct ContactsError: Error, Equatable, Sendable {
        public let message: String
        public init(_ error: Error) {
            self.message = error.localizedDescription
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
        public var searchResults: IdentifiedArrayOf<User> = []
        
        public var selectedSegment: Segment = .contacts
        public var contactFilterText: String = ""
        public var globalSearchText: String = ""
        
        public var isLoading: Bool = false
        public var isSearching: Bool = false
        public var pendingActionUserIds: Set<String> = []
        public var sentRequestUserIds: Set<String> = []
        
        @Presents public var alert: AlertState<AlertAction>?
        @Presents public var confirmationDialog: ConfirmationDialogState<ConfirmationDialogAction>?
        
        public var filteredContacts: [User] {
            let query = contactFilterText.trimmingCharacters(in: .whitespacesAndNewlines)
            if query.isEmpty { return Array(contacts) }
            return contacts.filter { user in
                user.username.localizedCaseInsensitiveContains(query) ||
                (user.fullName?.localizedCaseInsensitiveContains(query) ?? false) ||
                user.email.localizedCaseInsensitiveContains(query)
            }
        }
        
        public var groupedContacts: [(key: String, users: [User])] {
            let sorted = filteredContacts.sorted {
                ($0.fullName ?? $0.username).localizedCaseInsensitiveCompare($1.fullName ?? $1.username) == .orderedAscending
            }
            let grouped = Dictionary(grouping: sorted) { user -> String in
                let name = user.fullName ?? user.username
                let firstChar = String(name.prefix(1)).uppercased()
                return firstChar.rangeOfCharacter(from: .letters) != nil ? firstChar : "#"
            }
            return grouped.map { (key: $0.key, users: $0.value) }.sorted { $0.key < $1.key }
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
        
        // Data Responses
        case initialDataLoaded(contacts: [User], requests: [User])
        case initialDataFailed(ContactsError)
        case searchResultsResponse(Result<[User], ContactsError>)
        
        // User Intents
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
        
        case clearFilterTapped
        case clearSearchTapped
        
        // Presentation
        case alert(PresentationAction<AlertAction>)
        case confirmationDialog(PresentationAction<ConfirmationDialogAction>)
    }
    
    // MARK: - Dependencies & Reducer
    
    @Dependency(\.contactClient) var contactsClient
    @Dependency(\.continuousClock) var clock
    
    nonisolated private enum CancelID: Hashable, Sendable {
        case search
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
                    
                    do {
                        let (contacts, requests) = try await (contactsTask, requestsTask)
                        await send(.initialDataLoaded(contacts: contacts, requests: requests))
                    } catch {
                        await send(.initialDataFailed(ContactsError(error)))
                    }
                }
                
            case let .initialDataLoaded(contacts, requests):
                state.isLoading = false
                state.contacts = IdentifiedArray(uniqueElements: contacts)
                state.pendingRequests = IdentifiedArray(uniqueElements: requests)
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
                if segment != .search {
                    return .cancel(id: CancelID.search)
                }
                return .none
                
            // MARK: Search Debounce & Cancellation
            case .binding(\.globalSearchText):
                let query = state.globalSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
                if query.isEmpty {
                    state.searchResults.removeAll()
                    state.isSearching = false
                    return .cancel(id: CancelID.search)
                }
                state.isSearching = true
                return .run { [query] send in
                    try await clock.sleep(for: .milliseconds(300))
                    do {
                        let results = try await contactsClient.searchUsers(query)
                        await send(.searchResultsResponse(.success(results)))
                    } catch {
                        await send(.searchResultsResponse(.failure(ContactsError(error))))
                    }
                }
                .cancellable(id: CancelID.search, cancelInFlight: true)
                
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
                
            // MARK: Send Friend Request
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
                return .none
                
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
                return .none
                
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
                state.confirmationDialog = ConfirmationDialogState {
                    TextState("Remove Contact")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmRemoveFriend(user)) {
                        TextState("Remove \(user.fullName ?? user.username)")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("Are you sure you want to remove \(user.fullName ?? user.username) from your contacts?")
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
                return .none
                
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
                
            case .clearFilterTapped:
                state.contactFilterText = ""
                return .none
                
            case .clearSearchTapped:
                state.globalSearchText = ""
                state.searchResults.removeAll()
                state.isSearching = false
                return .cancel(id: CancelID.search)
                
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
    
    public init(store: StoreOf<ContactsFeature>) {
        self.store = store
    }
    
    private func segmentTitle(for segment: ContactsFeature.Segment) -> String {
        if segment == .requests && !store.pendingRequests.isEmpty {
            return "\(segment.rawValue) (\(store.pendingRequests.count))"
        }
        return segment.rawValue
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            Picker("Contacts Segment", selection: $store.selectedSegment.sending(\.segmentChanged)) {
                ForEach(ContactsFeature.Segment.allCases) { segment in
                    Text(segmentTitle(for: segment))
                        .tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // MARK: - Content Views
            ZStack {
                switch store.selectedSegment {
                case .contacts:
                    ContactsListView(store: store)
                case .requests:
                    PendingRequestsView(store: store)
                case .search:
                    UserSearchView(store: store)
                }
            }
        }
        .navigationTitle("Contacts")
        .searchable(
            text: store.selectedSegment == .search ? $store.globalSearchText : $store.contactFilterText,
            prompt: store.selectedSegment == .search ? "Search users globally..." : "Filter contacts..."
        )
        .onAppear {
            store.send(.onAppear)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .confirmationDialog($store.scope(state: \.confirmationDialog, action: \.confirmationDialog))
    }
}

// MARK: - Search View

private struct UserSearchView: View {
    let store: StoreOf<ContactsFeature>
    
    var body: some View {
        Group {
            if store.isSearching && store.searchResults.isEmpty {
                ProgressView("Searching users...")
            } else if store.globalSearchText.isEmpty {
                ContentUnavailableView(
                    "Search Users",
                    systemImage: "magnifyingglass",
                    description: Text("Type a username or email to find and connect with friends.")
                )
            } else if store.searchResults.isEmpty {
                ContentUnavailableView.search(text: store.globalSearchText)
            } else {
                List {
                    ForEach(store.searchResults) { user in
                        let isFriend = store.contacts.contains(where: { $0.id == user.id })
                        let isRequested = store.sentRequestUserIds.contains(user.id)
                        let isLoading = store.pendingActionUserIds.contains(user.id)
                        
                        HStack(spacing: 12) {
                            UserAvatarView(name: user.fullName ?? user.username)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.fullName ?? user.username)
                                    .font(.headline)
                                Text("@\(user.username)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if isFriend {
                                Label("Friend", systemImage: "checkmark.circle.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            } else if isRequested {
                                Label("Sent", systemImage: "clock.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                Button {
                                    store.send(.sendRequestButtonTapped(user))
                                } label: {
                                    if isLoading {
                                        ProgressView().scaleEffect(0.8)
                                    } else {
                                        Label("Add", systemImage: "person.badge.plus")
                                            .font(.subheadline.bold())
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .buttonBorderShape(.capsule)
                                .disabled(isLoading)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}

// MARK: - Contacts List View

private struct ContactsListView: View {
    let store: StoreOf<ContactsFeature>
    
    var body: some View {
        Group {
            if store.isLoading && store.contacts.isEmpty {
                ProgressView("Loading contacts...")
            } else if store.contacts.isEmpty {
                ContentUnavailableView(
                    "No Contacts",
                    systemImage: "person.crop.rectangle.stack",
                    description: Text("Your contact list is empty.")
                )
            } else if store.filteredContacts.isEmpty {
                ContentUnavailableView.search(text: store.contactFilterText)
            } else {
                List {
                    ForEach(store.groupedContacts, id: \.key) { section in
                        Section(header: Text(section.key).font(.headline)) {
                            ForEach(section.users) { user in
                                ContactRowView(user: user)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            store.send(.removeFriendButtonTapped(user))
                                        } label: {
                                            Label("Remove", systemImage: "person.slash.fill")
                                        }
                                    }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await store.send(.refreshPulled).finish()
                }
            }
        }
    }
}

// MARK: - Pending Requests View

private struct PendingRequestsView: View {
    let store: StoreOf<ContactsFeature>
    
    var body: some View {
        Group {
            if store.pendingRequests.isEmpty {
                ContentUnavailableView(
                    "No Pending Requests",
                    systemImage: "person.badge.shield.checkmark",
                    description: Text("Friend requests sent to you will appear here.")
                )
            } else {
                List {
                    ForEach(store.pendingRequests) { user in
                        let isLoading = store.pendingActionUserIds.contains(user.id)
                        
                        HStack(spacing: 12) {
                            UserAvatarView(name: user.fullName ?? user.username)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.fullName ?? user.username)
                                    .font(.headline)
                                Text("@\(user.username)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if isLoading {
                                ProgressView()
                            } else {
                                HStack(spacing: 8) {
                                    Button {
                                        store.send(.acceptRequestButtonTapped(user))
                                    } label: {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.green)
                                    }
                                    .buttonStyle(.borderless)
                                    
                                    Button {
                                        store.send(.rejectRequestButtonTapped(user))
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}

// MARK: - Row Subviews

private struct ContactRowView: View {
    let user: User
    
    var body: some View {
        HStack(spacing: 14) {
            UserAvatarView(name: user.fullName ?? user.username)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.fullName ?? user.username)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(user.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

private struct UserAvatarView: View {
    let name: String
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.15))
                .frame(width: 44, height: 44)
            
            Text(String(name.prefix(1)).uppercased())
                .font(.headline)
                .foregroundStyle(.blue)
        }
    }
}
