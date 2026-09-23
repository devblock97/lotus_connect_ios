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
        public var errorMessage: String?
        
        public init(feeds: [Post] = []) {
            self.feeds = IdentifiedArray(uniqueElements: feeds)
        }
    }
    
    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppear
        case feedsLoaded(TaskResult<[Post]>)
    }
    
    public init() {}
    
    @Dependency(\.feedClient) var feedClient
    
    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                state.errorMessage = nil
                return .run { send in
                    await send(.feedsLoaded(TaskResult {
                        try await feedClient.getFeed()
                    }))
                }
                
            case let .feedsLoaded(.success(feeds)):
                state.isLoading = false
                state.feeds = IdentifiedArray(uniqueElements: feeds)
                return .none
                
            case let .feedsLoaded(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case .binding:
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
    
    public var body: some View {
        ZStack {
            if store.isLoading && store.feeds.isEmpty {
                ProgressView("Loading Feed...")
            } else if store.feeds.isEmpty {
                EmptyView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(store.feeds) { feed in
                                PostCardView(post: feed)
                        }
                    }
                }
            }
        }
        .onAppear {
            self.store.send(.onAppear)
        }
    }
}

struct PostCardView: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            HStack {
                if post.author.avatarUrl == nil {
                    Image(systemName: "person.crop.circle")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    
                    Image(post.author.avatarUrl ??  "")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                }
                
                Text(post.author.fullName ?? post.author.username)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            
            if !post.mediaItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: true, ) {
                    LazyHStack(spacing: 12) {
                        ForEach(post.mediaItems) { media in
                            if let url = URL(string: media.url) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(maxWidth: .infinity, maxHeight: 250)
                                            .clipped()
                                    case .failure:
                                        Image(systemName: "photo")
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            HStack(spacing: 16) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        
                    }
                } label: {
                    Image(systemName: "heart")
                        .foregroundColor(.primary)
                }
                
                Button {
                    
                } label: {
                    Image(systemName: "bubble.right")
                }
                
                Button {
                    
                } label: {
                    Image(systemName: "paperplane")
                }
                
                Spacer()
                
                Button {
                    withAnimation {}
                } label: {
                    Image(systemName: "bookmark.fill")
                }
            }
            .font(.system(size: 22))
            .padding(.horizontal)
            .padding(.top, 10)
            
            Text("Like by **\(post.author.username) ** and **\(post.likeCount.formatted()) others**")
                .font(.subheadline)
                .padding(.horizontal)
                .padding(.top, 6)
            
            (
                Text(post.author.username).fontWeight(.semibold)
                + Text(" " + post.content)
            )
            .font(.subheadline)
            .padding(.horizontal)
            .padding(.top, 4)
            .lineLimit(2)
            
            
            Text("View all \(post.commentCount) comments")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 10)
        }
    }
}
