//
//  AppFeature.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 12/8/26.
//

import SwiftUI
import ComposableArchitecture

@Reducer
public struct AppFeature {
    @ObservableState
    public struct State: Equatable {
        public var auth = AuthFeature.State()
        public var rootTab = RootTabFeature.State()
        
        public init() {}
    }
    
    @CasePathable
    public enum Action: Equatable {
        case auth(AuthFeature.Action)
        case rootTab(RootTabFeature.Action)
    }
    
    public init() {}
    
    public var body: some Reducer<State, Action> {
        Scope(state: \.auth, action: \.auth) {
            AuthFeature()
        }
        Scope(state: \.rootTab, action: \.rootTab) {
            RootTabFeature()
        }
        
        Reduce { state, action in
            switch action {
            case .rootTab(.settings(.logoutButtonTapped)), .auth(.logoutCompleted):
                state.auth.user = nil
                return .none
                
            default:
                return .none
            }
        }
    }
}
