//
//  SettingsView.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 12/8/26.
//

import ComposableArchitecture
import SwiftUI

@Reducer public struct SettingsFeature {
    @ObservableState public struct State: Equatable {
        public var currentUser: User?
        public var isLoading: Bool = false
        public var errorMessage: String?
        public var isAuthenticated: Bool { currentUser != nil }
        
        public init(currentUser: User? = nil) {
            self.currentUser = currentUser
        }
    }
    
    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppear
        case sessionLoaded(User?)
        case loginButtonTapped
        case logoutButtonTapped
        case logoutResponse(TaskResult<Bool>)
    }
    
    @Dependency(\.authClient) var authClient
    @Dependency(KeychainClient.self) var keychainClient
    
    public init () {}
    
    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                // Read saved user profile from Keychain when Settings opens
                return .run { send in
                    if let session = try? await keychainClient.loadSession() {
                        await send(.sessionLoaded(session.user))
                    } else {
                        await send(.sessionLoaded(nil))
                    }
                }
                
            case let .sessionLoaded(user):
                state.currentUser = user
                return .none
                
            case .loginButtonTapped:
                return .none
                
            case .logoutButtonTapped:
                state.isLoading = true
                state.errorMessage = nil
                return .run { send in
                    await send(.logoutResponse(TaskResult {
                        try await authClient.logout(refreshToken: "")
                        return true
                    }))}
            case .logoutResponse(.success):
                state.isLoading = false
                state.currentUser = nil
                return .none
                
            case let .logoutResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case .binding:
                return .none
            }
        }
    }
    
}

public struct SettingsView: View {
    
    let store: StoreOf<SettingsFeature>
    
    public var body: some View {
        List {
            Section("Account") {
                if let user = store.currentUser {
                    HStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.fullName ?? user.username)
                                .font(.headline)
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    Button(role: .destructive) {
                        store.send(.logoutButtonTapped)
                    } label: {
                        HStack {
                            Spacer()
                            if store.isLoading {
                                ProgressView()
                            } else {
                                Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Not Signed In")
                            .font(.headline)
                        Text("Sign in to sync conversation across your devices.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Button {
                            store.send(.loginButtonTapped)
                        } label: {
                            Label("Sign In / Register", systemImage: "arrow.right.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 4)
                    }
                }
            }
            Section("Preferences") {
                Label("Theme", systemImage: "paintpalette")
                Label("Language", systemImage: "globe")
            }
            Section("AI Settings") {
                Label("API Keys", systemImage: "key")
                Label("Default Model", systemImage: "cpu")
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            store.send(.onAppear)
        }
    }
}
