//
//  CallsView.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 12/8/26.
//
import SwiftUI
import ComposableArchitecture

@Reducer
public struct CallsFeature {
    @ObservableState public struct State: Equatable {
        public init() {}
    }
    
    public enum Action: Equatable {}
    
    public init () {}
    
    public var body: some Reducer<State, Action> { Reduce { _, _ in .none}}
}

public struct CallsView: View {
    
    let store: StoreOf<CallsFeature>
    
    public var body: some View {
        ContentUnavailableView("Calls", systemImage: "phone", description: Text("Recent audio and video calls."))
            .navigationTitle("Calls")
    }
}
