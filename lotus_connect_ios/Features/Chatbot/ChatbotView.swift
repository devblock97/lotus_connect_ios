//
//  ChatbotView.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 12/8/26.
//

import ComposableArchitecture
import SwiftUI

@Reducer public struct ChatbotFeature {
    @ObservableState public struct State: Equatable {
        public init() {}
    }
    
    public enum Action: Equatable {
        
    }
    
    public init() {
        
    }
    
    public var body: some Reducer<State, Action> {
        Reduce { _, _ in .none}
    }
}
public struct ChatbotView: View {
    let store: StoreOf<ChatbotFeature>
    
    public var body: some View {
        ContentUnavailableView("AI", systemImage: "sparkles", description: Text("Ask anything to Lotus AI"))
            .navigationTitle("AI")
    }
}
