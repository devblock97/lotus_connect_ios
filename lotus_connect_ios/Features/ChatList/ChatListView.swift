//
//  ChatListView.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 12/8/26.
//

import ComposableArchitecture
import SwiftUI

@Reducer public struct ChatListFeature {
    @ObservableState public struct State: Equatable {
        public init() {}
    }
    
    public enum Action: Equatable {}
    
    public init() {}
    
    public var body: some Reducer<State, Action> { Reduce { _, _ in .none }}
}
public struct ChatListView: View {
    
    let store: StoreOf<ChatListFeature>
    
//    public init(store: StoreOf<ChatListFeature>) {
//        self.store = store
//    }
    
    public var body: some View {
        ContentUnavailableView("Chats", systemImage: "bubble.left.and.bubble.right", description: Text("Your conversation will appear here."))
            .navigationTitle("Chats")
    }
}
