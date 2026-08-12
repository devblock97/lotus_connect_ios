//
//  AppView.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 12/8/26.
//
import ComposableArchitecture
import SwiftUI

public struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>
    
    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }
    
    public var body: some View {
        Group {
            if store.auth.isAuthenticated {
                RootTabView(
                    store: store.scope(state: \.rootTab, action: \.rootTab)
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                AuthView(
                    store: store.scope(state: \.auth, action: \.auth)
                )
                .transition(.opacity)
            }
        }
        .animation(.default, value: store.auth.isAuthenticated)
    }
}
