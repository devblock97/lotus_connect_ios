//
//  ContactsView.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 12/8/26.
//

import SwiftUI
import ComposableArchitecture

@Reducer
public struct ContactsFeature {
    
    public enum Segment: String, CaseIterable, Identifiable, Equatable {
        case contacts = "Contacts"
        case requests = "Requests"
        case search = "Search"
        
        public var id: String { self.rawValue }
    }
    
    @ObservableState
    public struct State: Equatable {
        public var contacts: IdentifiedArrayOf<User> = []
        public var pendingRequests: IdentifiedArrayOf<User> = []
        public var searchResults: IdentifiedArrayOf<User> = []
        
        public var selectedSegment: Segment = .contacts
        public var searchText: String = ""
        
        
        public var isLoading: Bool = false
        public var isSearching: Bool = false
        public var errorMessage: String?
        public var toastMessage: String?
        
        public var filteredContacts: [User] {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if query.isEmpty { return Array(contacts)}
            return contacts.filter { user in
                user.username.localizedStandardContains(query) ||
                (user.fullName?.localizedCaseInsensitiveContains(query) ?? false) ||
                user.email.localizedCaseInsensitiveContains(query)
            }
        }
        
        public var groupedContacts: [(key: String, users: [User])] {
            let sorted = filteredContacts.sorted { ($0.fullName ?? $0.username) < ($1.fullName ?? $1.username)}
            let grouped = Dictionary(grouping: sorted) { user -> String in
                let name = user.fullName ?? user.username
                let firstChar = String(name.prefix(1)).uppercased()
                return firstChar.rangeOfCharacter(from: .letters) != nil ? firstChar : "#"
            }
            return grouped.map { (key: $0.key, user: $0.value) }.sorted { $0.key < $1.key }
        }
        
        public init() {}
    }
    
    @CasePathable
    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppear
        case refreshPulled
        case segmentChanged(Segment)
        case searchDebounced(String)
        
        case contactsLoaded(TaskResult<[User]>)
        case pendingRequestsLoaded(TaskResult<[User]>)
        case searchResultsLoaded(TaskResult<[User]>)
        
        case sendRequestTapped(String)
        case acceptRequestTapped(String)
        case rejectRequestTapped(String)
        case removeFriendTapped(String)
        
        case actionSuccess(String)
        case actionFailure(String)
        case dismissToast
    }
    
    @Dependency(\.contactClient) var contactsClient
    @Dependency(\.continuousClock) var clock
    
    nonisolated private enum CancelID: Hashable, Sendable {
        case search
    }
    
    public init() {}
    
    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce<State, Action> { state, action in // <-- Added <State, Action>
            switch action {
            case .onAppear, .refreshPulled:
                state.isLoading = true
                state.errorMessage = nil
                return .run { send in
                    await send(.contactsLoaded(TaskResult {
                        try await contactsClient.fetchContacts()
                    }))
                    await send(.pendingRequestsLoaded(TaskResult {
                        try await contactsClient.fetchPendingRequests()
                    }))
                }
                
            case let .segmentChanged(segment):
                state.selectedSegment = segment
                return .none
                
            case let .contactsLoaded(.success(users)):
                state.isLoading = false
                state.contacts = IdentifiedArray(uniqueElements: users)
                return .none
                
            case let .contactsLoaded(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case let .pendingRequestsLoaded(.success(requests)):
                state.pendingRequests = IdentifiedArray(uniqueElements: requests)
                return .none
                
            case .pendingRequestsLoaded(.failure):
                return .none
                
            case .binding(\.searchText):
                guard state.selectedSegment == .search else { return .none }
                let query = state.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                if query.isEmpty {
                    state.searchResults.removeAll()
                    return .cancel(id: CancelID.search)
                }
                state.isSearching = true
                return .run { [query] send in
                    try await clock.sleep(for: .milliseconds(300))
                    await send(.searchResultsLoaded(TaskResult {
                        try await contactsClient.searchUsers(query)
                    }))
                }
                .cancellable(id: CancelID.search, cancelInFlight: true)
                
            case let .searchResultsLoaded(.success(results)):
                state.isSearching = false
                state.searchResults = IdentifiedArray(uniqueElements: results)
                return .none
                
            case let .searchResultsLoaded(.failure(error)):
                state.isSearching = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case let .sendRequestTapped(userId):
                return .run { send in
                    do {
                        try await contactsClient.sendFriendRequest(userId)
                        await send(.actionSuccess("Friend request sent!"))
                    } catch {
                        await send(.actionFailure(error.localizedDescription))
                    }
                }
                
            case let .acceptRequestTapped(userId):
                state.pendingRequests.remove(id: userId)
                return .run { send in
                    do {
                        try await contactsClient.acceptFriendRequest(userId)
                        await send(.actionSuccess("Friend request accepted!"))
                        await send(.refreshPulled)
                    } catch {
                        await send(.actionFailure(error.localizedDescription))
                    }
                }
                
            case let .rejectRequestTapped(userId):
                state.pendingRequests.remove(id: userId)
                return .run { send in
                    do {
                        try await contactsClient.rejectFriendRequest(userId)
                        await send(.actionSuccess("Friend request declined."))
                    } catch {
                        await send(.actionFailure(error.localizedDescription))
                    }
                }
                
            case let .removeFriendTapped(userId):
                state.contacts.remove(id: userId)
                return .run { send in
                    do {
                        try await contactsClient.removeFriend(userId)
                        await send(.actionSuccess("Contact removed."))
                    } catch {
                        await send(.actionFailure(error.localizedDescription))
                    }
                }
                
            case let .actionSuccess(message):
                state.toastMessage = message
                return .none
                
            case let .actionFailure(error):
                state.errorMessage = error
                return .none
                
            case .dismissToast:
                state.toastMessage = nil
                state.errorMessage = nil
                return .none
                
            case .binding, .searchDebounced:
                return .none
            }
        }
    }

}
        
public struct ContactsView: View {
    
    @Bindable var store: StoreOf<ContactsFeature>
    
    public init(store: StoreOf<ContactsFeature>) {
        self.store = store
    }
    
    private var selectedSegmentBinding: Binding<ContactsFeature.Segment> {
        Binding(
            get: { store.selectedSegment },
            set: { store.send(.segmentChanged($0)) }
        )
    }
    
    private func segmentTitle(for segment: ContactsFeature.Segment) -> String {
        if segment == .requests && !store.pendingRequests.isEmpty {
            return "\(segment.rawValue) (\(store.pendingRequests.count))"
        }
        return segment.rawValue
    }
    
    public var body: some View {
        VStack {
            Picker("Contacts Segment", selection: selectedSegmentBinding) {
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
                    ContentUnavailableView("Search List View", image: "contact.circle.fill")
                }
            }
        }
        .navigationTitle("Contacts")
        .searchable(
            text: $store.searchText,
            prompt: store.selectedSegment == .search ? "Search users globally..." : "Filter contacts..."
        )
        .onAppear {
            store.send(.onAppear)
        }
        .alert(
            "Notice",
            isPresented: Binding(
                get: { store.errorMessage != nil || store.toastMessage != nil },
                set: { _ in store.send(.dismissToast)}
            ),
            actions: {
                Button("OK", role: .cancel) { store.send(.dismissToast)}
            },
            message: {
                Text(errorMessage())
            }
        )
    }
    
    private func errorMessage() -> String {
        return store.errorMessage ?? store.toastMessage ?? ""
    }
}

private struct UserSearchView: View {
    let store: StoreOf<ContactsFeature>
    
    var body: some View {
        Group {
            if store.isSearching {
                ProgressView("Searching users...")
            } else if store.searchResults.isEmpty {
                ContentUnavailableView(
                    "Search Users",
                    systemImage: "magnifyingglass",
                    description: Text("Type a username or email to find and connect with friends.")
                )
            } else {
                List {
                    ForEach(store.searchResults) { user in
                        HStack(spacing: 12) {
                            UserAvatarView(name: user.fullName ?? user.username)
                            
                            VStack {
                                Text(user.fullName ?? user.username)
                                    .font(.headline)
                                Text("@\(user.username)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button {
                                store.send(.sendRequestTapped(user.id))
                            } label: {
                                Label("Add", systemImage: "person.badge.plus")
                                    .font(.subheadline.bold())
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}

private struct ContactsListView: View {
    let store: StoreOf<ContactsFeature>
    
    var body: some View {
        Group {
            if store.isLoading && store.contacts.isEmpty {
                ProgressView("Loading contacts...")
            } else if store.filteredContacts.isEmpty {
                ContentUnavailableView(
                    "No Contacts Found",
                    systemImage: "person.crop.rectangle.stack",
                    description: Text("Add new friends using the Find People tab.")
                )
            } else {
                List {
                    ForEach(store.groupedContacts, id: \.key) { section in
                        Section(header: Text(section.key).font(.headline)) {
                            ForEach(section.users) { user in
                                ContactRowView(user: user)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            store.send(.removeFriendTapped(user.id))
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
                            
                            HStack(spacing: 8) {
                                Button {
                                    store.send(.acceptRequestTapped(user.id))
                                } label: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.green)
                                }
                                .buttonStyle(.borderless)
                                
                                Button {
                                    store.send(.rejectRequestTapped(user.id))
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.borderless)
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
