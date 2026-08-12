//
//  ContactsView.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 12/8/26.
//

import SwiftUI
import ComposableArchitecture

@Reducer public struct ContactsFeature {
    @ObservableState public struct State: Equatable {
        public init() {}
    }
    
    public enum Action: Equatable {}
    
    public init() {}
    
    public var body: some Reducer<State, Action> { Reduce { _, _ in .none}}
}
public struct ContactsView: View {
    
    let store: StoreOf<ContactsFeature>
    
    public var body: some View {
        ContentUnavailableView("Contacts", systemImage: "person.2", description: Text("Your contact list will appear here."))
            .navigationTitle("Contacts")
    }
}
