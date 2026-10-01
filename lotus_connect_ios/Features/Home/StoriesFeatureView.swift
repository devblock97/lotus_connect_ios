//
//  StoriesFeatureView.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 28/9/26.
//

import SwiftUI
import Combine

// MARK: - Design Tokens & Colors

public struct StoryColors {
    public static let instagramGradient = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.76, blue: 0.23), // Yellow
            Color(red: 0.98, green: 0.35, blue: 0.22), // Orange-Red
            Color(red: 0.86, green: 0.16, blue: 0.54), // Magenta-Pink
            Color(red: 0.55, green: 0.15, blue: 0.82)  // Purple
        ],
        startPoint: .bottomLeading,
        endPoint: .topTrailing
    )
    
    /// Gray gradient for watched/seen stories
    public static let seenGradient = LinearGradient(
        colors: [
            Color(uiColor: .systemGray4),
            Color(uiColor: .systemGray5)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let instagramBlue = Color(red: 0.0, green: 0.58, blue: 0.98)
    
    /// Vibrant green gradient for Close Friends stories
    public static let closeFriendsGradient = LinearGradient(
        colors: [
            Color(red: 0.10, green: 0.82, blue: 0.35),
            Color(red: 0.32, green: 0.98, blue: 0.48)
        ],
        startPoint: .bottomLeading,
        endPoint: .topTrailing
    )
    
    /// Deterministic modern gradient for initial avatars
    public static func avatarGradient(for name: String) -> [Color] {
        let palettes: [[Color]] = [
            [Color(red: 0.38, green: 0.40, blue: 0.96), Color(red: 0.61, green: 0.35, blue: 0.91)], // Indigo Purple
            [Color(red: 0.96, green: 0.38, blue: 0.52), Color(red: 0.98, green: 0.55, blue: 0.38)], // Rose Coral
            [Color(red: 0.18, green: 0.73, blue: 0.61), Color(red: 0.12, green: 0.53, blue: 0.90)], // Teal Blue
            [Color(red: 0.95, green: 0.58, blue: 0.20), Color(red: 0.91, green: 0.30, blue: 0.24)], // Amber Flame
            [Color(red: 0.49, green: 0.23, blue: 0.93), Color(red: 0.23, green: 0.51, blue: 0.96)]  // Deep Violet
        ]
        let hash = abs(name.hashValue)
        return palettes[hash % palettes.count]
    }
}

// MARK: - Story Item Button Style

public struct StoryItemButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

// MARK: - Avatar with Instagram Ring View

public struct StoryAvatarView: View {
    public let username: String
    public let avatarUrl: String?
    public let isSeen: Bool
    public let hasRing: Bool
    public var isCloseFriends: Bool
    public var size: CGFloat = 68
    
    private var avatarSize: CGFloat {
        hasRing ? (size - 8) : (size - 2)
    }
    
    public init(
        username: String,
        avatarUrl: String? = nil,
        isSeen: Bool = false,
        hasRing: Bool = true,
        isCloseFriends: Bool = false,
        size: CGFloat = 68
    ) {
        self.username = username
        self.avatarUrl = avatarUrl
        self.isSeen = isSeen
        self.hasRing = hasRing
        self.isCloseFriends = isCloseFriends
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            if hasRing {
                Circle()
                    .stroke(
                        isSeen ? StoryColors.seenGradient : (isCloseFriends ? StoryColors.closeFriendsGradient : StoryColors.instagramGradient),
                        lineWidth: 2.2
                    )
                    .frame(width: size, height: size)
                
                // Crisp negative-space background gap
                Circle()
                    .fill(Color(uiColor: .systemBackground))
                    .frame(width: size - 4, height: size - 4)
            }
            
            // Avatar Content (AsyncImage or Vibrant Fallback)
            Group {
                if let avatarUrl, let url = URL(string: avatarUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            fallbackAvatar
                        }
                    }
                } else {
                    fallbackAvatar
                }
            }
            .frame(width: avatarSize, height: avatarSize)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.black.opacity(hasRing ? 0.04 : 0.12), lineWidth: 0.6)
            )
        }
    }
    
    @ViewBuilder
    private var fallbackAvatar: some View {
        let nameLower = username.lowercased()
        if nameLower == "marvel" {
            ZStack {
                Color(red: 0.90, green: 0.12, blue: 0.14)
                Text("MARVEL")
                    .font(.system(size: avatarSize * 0.25, weight: .heavy, design: .default))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        } else if nameLower.contains("story") {
            ZStack {
                Color(white: 0.15)
                Image(systemName: "person.fill")
                    .font(.system(size: avatarSize * 0.44))
                    .foregroundColor(.white.opacity(0.95))
            }
        } else {
            ZStack {
                LinearGradient(
                    colors: StoryColors.avatarGradient(for: username),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                Text(String(username.prefix(1)).uppercased())
                    .font(.system(size: avatarSize * 0.40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Stories Horizontal Tray

public struct StoriesTrayView: View {
    public let storyGroups: [UserStory]
    public let onSelectGroup: (UserStory) -> Void
    public let onAddStoryTapped: () -> Void
    
    public init(
        storyGroups: [UserStory],
        onSelectGroup: @escaping (UserStory) -> Void,
        onAddStoryTapped: @escaping () -> Void
    ) {
        self.storyGroups = storyGroups
        self.onSelectGroup = onSelectGroup
        self.onAddStoryTapped = onAddStoryTapped
    }
    
    public init(
        storyGroups: Binding<[UserStory]>,
        onSelectGroup: @escaping (UserStory) -> Void,
        onAddStoryTapped: @escaping () -> Void
    ) {
        self.storyGroups = storyGroups.wrappedValue
        self.onSelectGroup = onSelectGroup
        self.onAddStoryTapped = onAddStoryTapped
    }
    
    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 14) {
                // Current User "Your Story" Item
                if let currentUser = storyGroups.first(where: { $0.isSelf }) {
                    CurrentUserStoryTrayItem(
                        group: currentUser,
                        onTap: {
                            if currentUser.stories.isEmpty {
                                onAddStoryTapped()
                            } else {
                                onSelectGroup(currentUser)
                            }
                        },
                        onAddTapped: onAddStoryTapped
                    )
                }
                
                // Friends' Story Items
                ForEach(storyGroups.filter { !$0.isSelf }) { group in
                    FriendStoryTrayItem(group: group) {
                        onSelectGroup(group)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 8)
        }
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - Current User Tray Item

private struct CurrentUserStoryTrayItem: View {
    let group: UserStory
    let onTap: () -> Void
    let onAddTapped: () -> Void
    
    private var hasActiveStory: Bool {
        !group.stories.isEmpty
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                ZStack(alignment: .bottomTrailing) {
                    StoryAvatarView(
                        username: group.user.username,
                        avatarUrl: group.user.avatarUrl,
                        isSeen: !group.hasUnseen,
                        hasRing: hasActiveStory,
                        isCloseFriends: group.hasCloseFriendsStory,
                        size: 68
                    )
                    
                    Button(action: onAddTapped) {
                        ZStack {
                            Circle()
                                .fill(Color(uiColor: .systemBackground))
                                .frame(width: 23, height: 23)
                            
                            Circle()
                                .fill(StoryColors.instagramBlue)
                                .frame(width: 19, height: 19)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundColor(.white)
                        }
                    }
                    .offset(x: 2, y: 2)
                }
                
                Text("Your story")
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundColor(.secondary)
                    .frame(width: 74)
                    .lineLimit(1)
            }
        }
        .buttonStyle(StoryItemButtonStyle())
    }
}

// MARK: - Friend Tray Item

private struct FriendStoryTrayItem: View {
    let group: UserStory
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                StoryAvatarView(
                    username: group.user.username,
                    avatarUrl: group.user.avatarUrl,
                    isSeen: !group.hasUnseen,
                    hasRing: true,
                    isCloseFriends: group.hasCloseFriendsStory,
                    size: 68
                )
                
                Text(group.user.username)
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundColor(.primary)
                    .frame(width: 74)
                    .lineLimit(1)
            }
        }
        .buttonStyle(StoryItemButtonStyle())
    }
}

// MARK: - Fullscreen Story Viewer (Instagram-Grade Modal Player)

public struct StoryViewerModal: View {
    public let storyGroups: [UserStory]
    public let initialGroupIndex: Int
    public let onDismiss: () -> Void
    public var onMarkAsSeen: ((UserStory) -> Void)? = nil
    
    @State private var currentGroupIndex: Int = 0
    @State private var currentStoryIndex: Int = 0
    @State private var progress: CGFloat = 0.0
    @State private var isPaused: Bool = false
    @State private var isLiked: Bool = false
    @State private var replyText: String = ""
    @State private var floatingHearts: [FloatingHeart] = []
    @State private var dragOffset: CGSize = .zero
    
    // Per-story dynamic duration (defaults to 5s if not specified)
    private var currentStoryDuration: Double {
        guard let story = currentStory, story.duration > 0 else { return 5.0 }
        return story.duration
    }
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    public init(
        storyGroups: [UserStory],
        initialGroupIndex: Int,
        onDismiss: @escaping () -> Void,
        onMarkAsSeen: ((UserStory) -> Void)? = nil
    ) {
        self.storyGroups = storyGroups
        self.initialGroupIndex = initialGroupIndex
        self.onDismiss = onDismiss
        self.onMarkAsSeen = onMarkAsSeen
    }
    
    public init(
        storyGroups: Binding<[UserStory]>,
        initialGroupIndex: Int,
        onDismiss: @escaping () -> Void
    ) {
        self.storyGroups = storyGroups.wrappedValue
        self.initialGroupIndex = initialGroupIndex
        self.onDismiss = onDismiss
        self.onMarkAsSeen = { group in
            if let idx = storyGroups.wrappedValue.firstIndex(where: { $0.id == group.id }) {
                storyGroups.wrappedValue[idx].hasUnseen = false
            }
        }
    }
    
    private var currentGroup: UserStory? {
        guard currentGroupIndex >= 0 && currentGroupIndex < storyGroups.count else { return nil }
        return storyGroups[currentGroupIndex]
    }
    
    private var currentStory: Story? {
        guard let group = currentGroup,
              currentStoryIndex >= 0 && currentStoryIndex < group.stories.count else { return nil }
        return group.stories[currentStoryIndex]
    }
    
    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let group = currentGroup, let story = currentStory {
                    // Story Content Area
                    storyContentView(story: story, size: proxy.size)
                    
                    // Tap Areas (Left 30% = Prev, Right 70% = Next)
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .frame(width: proxy.size.width * 0.32)
                            .onTapGesture {
                                previousStory()
                            }
                        
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .frame(width: proxy.size.width * 0.68)
                            .onTapGesture {
                                nextStory()
                            }
                    }
                    
                    VStack(spacing: 0) {
                        // Top Segmented Progress Bar
                        progressBarsView(storiesCount: group.stories.count)
                            .padding(.horizontal, 12)
                            .padding(.top, proxy.safeAreaInsets.top + 8)
                        
                        // User Header
                        headerView(group: group, story: story)
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                        
                        Spacer()
                        
                        // Floating Heart Reactions
                        floatingHeartsView
                        
                        // Bottom Actions Bar
                        bottomActionsBar
                            .padding(.horizontal, 14)
                            .padding(.bottom, max(proxy.safeAreaInsets.bottom, 12))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: dragOffset.height > 0 ? 32 : 0, style: .continuous))
            .offset(y: max(0, dragOffset.height))
            .scaleEffect(dragOffset.height > 0 ? max(0.85, 1.0 - (dragOffset.height / 1000.0)) : 1.0)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation
                            isPaused = true
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 120 {
                            onDismiss()
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dragOffset = .zero
                                isPaused = false
                            }
                        }
                    }
            )
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.2)
                    .onChanged { _ in
                        isPaused = true
                    }
                    .onEnded { _ in
                        isPaused = false
                    }
            )
        }
        .onAppear {
            currentGroupIndex = min(max(0, initialGroupIndex), max(0, storyGroups.count - 1))
            currentStoryIndex = 0
            markCurrentGroupAsSeen()
        }
        .onReceive(timer) { _ in
            guard !isPaused, currentStory != nil else { return }
            let step = 0.05 / currentStoryDuration
            if progress + step >= 1.0 {
                progress = 1.0
                nextStory()
            } else {
                progress += step
            }
        }
    }
    
    // MARK: - Story Content View
    
    @ViewBuilder
    private func storyContentView(story: Story, size: CGSize) -> some View {
        ZStack {
            if let url = URL(string: story.mediaUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size.width, height: size.height)
                            .clipped()
                    default:
                        gradientBackdrop(story: story)
                    }
                }
            } else {
                gradientBackdrop(story: story)
            }
            
            VStack {
                LinearGradient(
                    colors: [Color.black.opacity(0.65), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
                
                Spacer()
                
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 150)
            }
            .ignoresSafeArea()
            
            if let caption = story.caption {
                VStack {
                    Spacer()
                    Text(caption)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 96)
                        .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 3)
                }
            }
        }
    }
    
    private func gradientBackdrop(story: Story) -> some View {
        LinearGradient(
            colors: story.backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Progress Bars
    
    private func progressBarsView(storiesCount: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<max(1, storiesCount), id: \.self) { index in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.35))
                        
                        Capsule()
                            .fill(Color.white)
                            .frame(width: progressWidth(for: index, totalWidth: geo.size.width))
                    }
                }
                .frame(height: 2.2)
            }
        }
    }
    
    private func progressWidth(for index: Int, totalWidth: CGFloat) -> CGFloat {
        if index < currentStoryIndex {
            return totalWidth
        } else if index == currentStoryIndex {
            return totalWidth * progress
        } else {
            return 0
        }
    }
    
    // MARK: - Header View
    
    private func headerView(group: UserStory, story: Story) -> some View {
        HStack(spacing: 10) {
            StoryAvatarView(
                username: group.user.username,
                avatarUrl: group.user.avatarUrl,
                isSeen: false,
                hasRing: false,
                size: 34
            )
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(group.isSelf ? "Your story" : group.user.username)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(story.timeAgo.isEmpty ? story.createdAt : story.timeAgo)
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                if let location = story.locationName {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 10, weight: .semibold))
                        Text(location)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.9))
                }
            }
            
            Spacer()
            
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .padding(8)
            }
        }
    }
    
    // MARK: - Bottom Actions Bar
    
    private var bottomActionsBar: some View {
        HStack(spacing: 12) {
            // "Send message" pill
            HStack {
                TextField("", text: $replyText, prompt: Text("Send message...").foregroundColor(.white.opacity(0.6)))
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
            )
            
            // Like Heart Button
            Button {
                spawnHeart()
            } label: {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(isLiked ? .red : .white)
                    .frame(width: 44, height: 44)
            }
            
            // Share Button
            Button {
                // Share action
            } label: {
                Image(systemName: "paperplane")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
        }
    }
    
    // MARK: - Floating Hearts Reaction
    
    private var floatingHeartsView: some View {
        ZStack {
            ForEach(floatingHearts) { heart in
                Image(systemName: "heart.fill")
                    .font(.system(size: heart.size))
                    .foregroundColor(.red)
                    .offset(x: heart.xOffset, y: heart.yOffset)
                    .opacity(heart.opacity)
                    .scaleEffect(heart.scale)
            }
        }
        .frame(height: 100)
        .allowsHitTesting(false)
    }
    
    private func spawnHeart() {
        isLiked.toggle()
        guard isLiked else { return }
        
        let heart = FloatingHeart(
            xOffset: CGFloat.random(in: 80...130),
            yOffset: 0,
            size: CGFloat.random(in: 28...42),
            opacity: 1.0,
            scale: 0.5
        )
        floatingHearts.append(heart)
        
        withAnimation(.easeOut(duration: 1.2)) {
            if let index = floatingHearts.firstIndex(where: { $0.id == heart.id }) {
                floatingHearts[index].yOffset = -220
                floatingHearts[index].xOffset += CGFloat.random(in: -30...30)
                floatingHearts[index].opacity = 0.0
                floatingHearts[index].scale = 1.3
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            floatingHearts.removeAll(where: { $0.id == heart.id })
        }
    }
    
    // MARK: - Story Navigation Logic
    
    private func nextStory() {
        guard let group = currentGroup else { return }
        if currentStoryIndex + 1 < group.stories.count {
            currentStoryIndex += 1
            progress = 0.0
        } else {
            nextGroup()
        }
    }
    
    private func previousStory() {
        if currentStoryIndex > 0 {
            currentStoryIndex -= 1
            progress = 0.0
        } else {
            previousGroup()
        }
    }
    
    private func nextGroup() {
        if currentGroupIndex + 1 < storyGroups.count {
            currentGroupIndex += 1
            currentStoryIndex = 0
            progress = 0.0
            markCurrentGroupAsSeen()
        } else {
            onDismiss()
        }
    }
    
    private func previousGroup() {
        if currentGroupIndex > 0 {
            currentGroupIndex -= 1
            let prevGroup = storyGroups[currentGroupIndex]
            currentStoryIndex = max(0, prevGroup.stories.count - 1)
            progress = 0.0
        }
    }
    
    private func markCurrentGroupAsSeen() {
        guard currentGroupIndex >= 0 && currentGroupIndex < storyGroups.count else { return }
        onMarkAsSeen?(storyGroups[currentGroupIndex])
    }
}

// MARK: - Floating Heart Model

private struct FloatingHeart: Identifiable {
    let id = UUID()
    var xOffset: CGFloat
    var yOffset: CGFloat
    var size: CGFloat
    var opacity: Double
    var scale: CGFloat
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)

        let r, g, b, a: Double
        switch hex.count {
        case 6: // RGB (24-bit)
            r = Double((rgb >> 16) & 0xFF) / 255
            g = Double((rgb >> 8) & 0xFF) / 255
            b = Double(rgb & 0xFF) / 255
            a = 1.0
        case 8: // ARGB (32-bit)
            a = Double((rgb >> 24) & 0xFF) / 255
            r = Double((rgb >> 16) & 0xFF) / 255
            g = Double((rgb >> 8) & 0xFF) / 255
            b = Double(rgb & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0; a = 1.0
        }

        self.init(red: r, green: g, blue: b, opacity: a)
    }
}
