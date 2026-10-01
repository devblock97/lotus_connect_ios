//
//  StoryClient.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 30/9/26.
//
import Dependencies

public struct StoryClient: Sendable {
    public var getStories: @Sendable() async throws -> [UserStory]
}

extension StoryClient: DependencyKey {
    public static let liveValue: StoryClient = {
        @Dependency(\.httpClient) var httpClient
        
        return StoryClient(
            getStories: {
                let stories: [UserStory] = try await httpClient.request("stories/tray", .get, nil, nil)
                return stories
            }
        )
    }()
}

extension DependencyValues {
    public var storyClient: StoryClient {
        get { self[StoryClient.self] }
        set { self[StoryClient.self] = newValue }
    }
}
