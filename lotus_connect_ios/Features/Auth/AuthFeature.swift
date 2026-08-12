//
//  AuthFeature.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 12/8/26.
//

import ComposableArchitecture
import Foundation

@Reducer
public struct AuthFeature {
    @ObservableState
    public struct State: Equatable {
        public var user: User?
        public var isLoading: Bool = false
        public var errorMessage: String?
        public var isRegisterMode: Bool = false
        
        public var emailText: String = ""
        public var passwordText: String = ""
        public var usernameText: String = ""
        public var fullNameText: String = ""
        
        public var isAuthenticated: Bool { user != nil }
        
        public init(user: User? = nil) {
            self.user = user
        }
    }
    
    @CasePathable
    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppear
        case sessionRestored(TaskResult<AuthSession?>)
        case loginResponse(TaskResult<AuthSession>)
        case submitButtonTapped
        case registerResponse(TaskResult<Bool>)
        case toggleRegisterMode
        case logoutButtonTapped
        case logoutCompleted
    }
    
    @Dependency(\.authClient) var authClient
    
    public init() {}
    
    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    await send(.sessionRestored(TaskResult {
                        try await authClient.restoreSession()
                    }))
                }
                
            case let .sessionRestored(.success(session)):
                state.isLoading = false
                if let session = session {
                    state.user = session.user
                }
                return .none
            case .sessionRestored(.failure):
                state.isLoading = false
                return .none
                
            case .toggleRegisterMode:
                state.isRegisterMode.toggle()
                state.errorMessage = nil
                return .none
                
            case .submitButtonTapped:
                state.errorMessage = nil
                state.isLoading = true
                
                if state.isRegisterMode {
                    let username = state.usernameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let email = state.emailText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let password = state.passwordText
                    let fullName = state.fullNameText.isEmpty ? nil : state.fullNameText
                    
                    return .run { send in
                        await send(.registerResponse(TaskResult {
                            try await authClient.register(
                                username: username,
                                email: email,
                                password: password,
                                fullName: fullName
                            )
                            return true
                        }))
                    }
                } else {
                    let email = state.emailText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let password = state.passwordText
                    
                    return .run { send in
                        await send(.loginResponse(TaskResult {
                            try await authClient.login(email: email, password: password)
                        }))
                    }
                }
                
            case let .loginResponse(.success(session)):
                state.isLoading = false
                state.user = session.user
                return .none
                
            case .registerResponse(.success):
                state.isLoading = false
                state.isRegisterMode = false
                state.errorMessage = nil
                return .none
                
            case let .registerResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case .logoutButtonTapped:
                state.isLoading = true
                return .run { send in
                    try await authClient.logout(refreshToken: "")
                    await send(.logoutCompleted)
                }
            case .logoutCompleted:
                state.user = nil
                state.isLoading = false
                return .none
                
            case .binding:
                return .none
            case .loginResponse(.failure(_)):
                return .none
            }
        }
    }
}
