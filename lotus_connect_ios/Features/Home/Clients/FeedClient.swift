//
//  FeedClient.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 23/9/26.
//

import Dependencies

public struct FeedClient: Sendable {
    public var getFeed: @Sendable() async throws -> [Post]
}

extension FeedClient: DependencyKey {
    public static let liveValue: FeedClient = {
        @Dependency(\.httpClient) var httpClient
        
        return FeedClient(
            getFeed: {
                let feeds: [Post] = try await httpClient.request("/feed", .get, nil, nil)
                return feeds
            }
        )
    }()

}

extension DependencyValues {
    public var feedClient: FeedClient {
        get { self[FeedClient.self] }
        set { self[FeedClient.self] = newValue }
    }
}
