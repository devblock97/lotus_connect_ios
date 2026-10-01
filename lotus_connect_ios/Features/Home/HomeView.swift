//
//  HomeView.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 21/9/26.
//

import SwiftUI
import ComposableArchitecture

@Reducer
public struct HomeFeature {
    
    @ObservableState
    public struct State: Equatable {
        public var feeds: IdentifiedArrayOf<Post> = []
        public var isLoading: Bool = false
        public var isStoriesLoading: Bool = false
        public var storyGroups: [UserStory] = []
        public var errorMessage: String?
        public var selectedGroupIndex: Int = 0
        public var isViewerPresented: Bool = false
        
        public init(feeds: [Post] = [], storyGroups: [UserStory] = []) {
            self.feeds = IdentifiedArray(uniqueElements: feeds)
            self.storyGroups = storyGroups
        }
    }
    
    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppear
        case feedsLoaded(TaskResult<[Post]>)
        case storiesLoaded(TaskResult<[UserStory]>)
        case storyTrayItemTapped(UserStory)
        case storyViewerDismissed
        case addStoryTapped
    }
    
    public init() {}
    
    @Dependency(\.feedClient) var feedClient
    @Dependency(\.storyClient) var storyClient
    
    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                state.isStoriesLoading = true
                state.errorMessage = nil
                
                return .merge(
                    .run { send in
                        await send(.feedsLoaded(TaskResult {
                            try await feedClient.getFeed()
                        }))
                    },
                    .run { send in
                        await send(.storiesLoaded(TaskResult {
                            try await storyClient.getStories()
                        }))
                    }
                )
                
            case let .storiesLoaded(.success(stories)):
                state.isStoriesLoading = false
                state.storyGroups = stories
                return .none
                
            case .storiesLoaded(.failure):
                state.isStoriesLoading = false
                return .none
                
            
                
            case let .feedsLoaded(.success(feeds)):
                state.isLoading = false
                state.feeds = IdentifiedArray(uniqueElements: feeds)
                return .none
                
            case let .feedsLoaded(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case let .storyTrayItemTapped(group):
                if let index = state.storyGroups.firstIndex(where: { $0.id == group.id }) {
                    state.selectedGroupIndex = index
                    state.isViewerPresented = true
                }
                return .none
                
            case .storyViewerDismissed:
                state.isViewerPresented = false
                return .none
                
            case .addStoryTapped:
                return .none
                
            case .binding, .feedsLoaded:
                return .none
            }
        }
    }
}

public struct HomeView: View {
    @Bindable var store: StoreOf<HomeFeature>
    
    public init(store: StoreOf<HomeFeature>) {
        self.store = store
    }
    
    private var activeFeeds: [Post] {
        store.feeds.isEmpty ? [] : Array(store.feeds)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Header (Lotus Connect serif + Heart & Direct icons)
            HStack(alignment: .center) {
                Text("Lotus Connect")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 20) {
                    Button {
                        // Activity / notifications
                    } label: {
                        Image(systemName: "heart")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundColor(.primary)
                    }
                    
                    Button {
                        // Messages / direct
                    } label: {
                        Image(systemName: "paperplane")
                            .font(.system(size: 21, weight: .regular))
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 6)
            
            // MARK: - Main Scroll Feed
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Stories Tray Row
                    if !store.storyGroups.isEmpty {
                        StoriesTrayView(
                            storyGroups: store.storyGroups,
                            onSelectGroup: { group in
                                store.send(.storyTrayItemTapped(group))
                            },
                            onAddStoryTapped: {
                                store.send(.addStoryTapped)
                            }
                        )
                    }
                    
                    if store.isLoading && store.feeds.isEmpty {
                        ProgressView("Loading Feed...")
                            .padding(.vertical, 32)
                    } else {
                        // Posts List
                        ForEach(activeFeeds) { post in
                            PostCardView(post: post)
                        }
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $store.isViewerPresented) {
            StoryViewerModal(
                storyGroups: store.storyGroups,
                initialGroupIndex: store.selectedGroupIndex,
                onDismiss: {
                    store.send(.storyViewerDismissed)
                }
            )
        }
        .onAppear {
            self.store.send(.onAppear)
        }
    }
}

// MARK: - Post Card View (Matching Instagram & Android PostCard.kt)

struct PostCardView: View {
    let post: Post
    
    @State private var currentImageIndex: Int = 0
    @State private var isLiked: Bool = false
    @State private var isBookmarked: Bool = false
    @State private var likeCount: Int
    
    init(post: Post) {
        self.post = post
        self._likeCount = State(initialValue: post.likeCount)
        self._isLiked = State(initialValue: post.userHasLiked)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Author Header Row
            HStack(spacing: 10) {
                // Author Avatar
                if let avatarUrl = post.author.avatarUrl, let url = URL(string: avatarUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            fallbackAuthorAvatar
                        }
                    }
                    .frame(width: 38, height: 38)
                    .clipShape(Circle())
                } else {
                    fallbackAuthorAvatar
                }
                
                // Username & Full Name
                VStack(alignment: .leading, spacing: 1) {
                    Text(post.author.username)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if let fullName = post.author.fullName, !fullName.isEmpty {
                        Text(fullName)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button {
                    // Post options menu
                } label: {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(6)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            
            // MARK: - Media Carousel
            if !post.mediaItems.isEmpty {
                ZStack(alignment: .topTrailing) {
                    TabView(selection: $currentImageIndex) {
                        ForEach(Array(post.mediaItems.enumerated()), id: \.element.id) { index, media in
                            if let url = URL(string: media.url) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    case .failure:
                                        ZStack {
                                            Color(uiColor: .secondarySystemBackground)
                                            Image(systemName: "photo")
                                                .font(.largeTitle)
                                                .foregroundColor(.secondary)
                                        }
                                    default:
                                        ZStack {
                                            Color(uiColor: .secondarySystemBackground)
                                            ProgressView()
                                        }
                                    }
                                }
                                .tag(index)
                            }
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .aspectRatio(1.0, contentMode: .fit)
                    .clipped()
                    
                    // Top-right counter pill: "1/4"
                    if post.mediaItems.count > 1 {
                        Text("\(currentImageIndex + 1)/\(post.mediaItems.count)")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4.5)
                            .background(Capsule().fill(Color.black.opacity(0.65)))
                            .padding(12)
                    }
                }
            }
            
            // MARK: - Action Buttons Row (Heart, Comment, Share, Dots, Bookmark)
            HStack(alignment: .center) {
                // Left Actions
                HStack(spacing: 16) {
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                            isLiked.toggle()
                            likeCount += isLiked ? 1 : -1
                        }
                    } label: {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : .primary)
                            .scaleEffect(isLiked ? 1.08 : 1.0)
                    }
                    
                    Button {
                        // Comments action
                    } label: {
                        Image(systemName: "bubble.right")
                            .foregroundColor(.primary)
                    }
                    
                    Button {
                        // Share action
                    } label: {
                        Image(systemName: "paperplane")
                            .foregroundColor(.primary)
                    }
                }
                
                Spacer()
                
                // Center Pagination Dots (matching Instagram)
                if post.mediaItems.count > 1 {
                    HStack(spacing: 4.5) {
                        ForEach(0..<post.mediaItems.count, id: \.self) { index in
                            Circle()
                                .fill(
                                    currentImageIndex == index
                                        ? Color(red: 0.0, green: 0.58, blue: 0.98) // Instagram Blue
                                        : Color.gray.opacity(0.4)
                                )
                                .frame(
                                    width: currentImageIndex == index ? 6.5 : 5.0,
                                    height: currentImageIndex == index ? 6.5 : 5.0
                                )
                        }
                    }
                }
                
                Spacer()
                
                // Right Bookmark Button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isBookmarked.toggle()
                    }
                } label: {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundColor(.primary)
                }
            }
            .font(.system(size: 21))
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)
            
            // MARK: - Likes Count
            Text("\(likeCount) likes")
                .font(.system(size: 13.5, weight: .bold))
                .foregroundColor(.primary)
                .padding(.horizontal, 14)
                .padding(.top, 2)
            
            // MARK: - Post Caption
            if !post.content.isEmpty {
                Text("**\(post.author.username)** \(post.content)")
                    .font(.system(size: 13.5))
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .padding(.horizontal, 14)
                    .padding(.top, 3)
            }
            
            // MARK: - Comments Link
            if post.commentCount > 0 {
                Button {
                    // Open comments
                } label: {
                    Text("View all \(post.commentCount) comments")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.top, 3)
                .padding(.bottom, 10)
            }
        }
    }
    
    // Fallback author avatar badge (purple gradient with initials JN)
    private var fallbackAuthorAvatar: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.45, green: 0.25, blue: 0.95), Color(red: 0.20, green: 0.45, blue: 0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Text(String(post.author.username.prefix(2)).uppercased())
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: 38, height: 38)
        .clipShape(Circle())
    }
}
