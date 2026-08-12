//
//  lotus_connect_iosApp.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 10/8/26.
//

import SwiftUI
import SwiftData

import ComposableArchitecture

/// The main entry point for the Lotus Connect iOS application.
/// Initializes the root TCA Store with `RootTabFeature` and presents `RootTabView`.
@main
struct LotusConnectApp: App {
    /// The root store powering the bottom tab navigation and all sub-features.
    @State private var store = Store(
        initialState: RootTabFeature.State()
    ) {
        RootTabFeature()
            #if DEBUG
            // Logs state changes and actions in Xcode Console during development
            ._printChanges()
            #endif
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(store: store)
        }
    }
}

// MARK: - Canvas Preview
#Preview("Lotus Connect Main App") {
    RootTabView(
        store: Store(initialState: RootTabFeature.State()) {
            RootTabFeature()
        }
    )
}
