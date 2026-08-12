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
        public init() {}
    }
    
    public enum Action: Equatable {}
    
    public init () {}
    
    public var body: some Reducer<State, Action> { Reduce {_, _ in .none}}
}
public struct SettingsView: View {
    
    let store: StoreOf<SettingsFeature>
    
    public var body: some View {
        List {
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
    }
}
