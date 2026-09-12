//
//  PrivateChatDetailView.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 13/8/26.
//

import ComposableArchitecture
import SwiftUI
import AVKit


public struct PrivateChatDetailView: View {
    @Bindable var store: StoreOf<PrivateChatDetailFeature>
    
    public init(store: StoreOf<PrivateChatDetailFeature>) {
        self.store = store
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(store.messages.reversed()) { message in
                            PrivateMessageBubble(
                                message: message,
                                replyingToMessage: store.messages[id: message.replyToId ?? ""],
                                onReply: { store .send(.setReplyingToMessage(message))},
                                onEdit: { store.send(.setEditingMessage(message))},
                                onDelete: { store.send(.deleteMessageTapped(message.id))}
                            )
                            .id(message.id)
                        }
                        Color.clear
                            .frame(height: 1)
                            .id("bottom_anchor")
                    }
                    .padding()
                }
                .defaultScrollAnchor(.bottom)
                .onAppear {
                    if !store.messages.isEmpty {
                        proxy.scrollTo("bottom_anchor", anchor: .bottom)
                    }
                }
                .onChange(of: store.messages.count) { _, _ in
                    if let firstId = store.messages.first?.id {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo("bottom_anchor", anchor: .bottom)
                        }
                    }
                }
            }
            
            // MARK: - Typing Indicator Banner
            if store.isPeerTyping {
                HStack(spacing: 6) {
                    Text("\(store.conversation.title) is typing...")
                        .font(.caption)
                        .italic()
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
            
            // MARK: - Active Reply / Edit Bar Preview
            if let replyMsg = store.replyingToMessage {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Replying to:")
                            .font(.caption.bold())
                            .foregroundColor(.blue)
                        Text(replyMsg.content)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button {
                        store.send(.setReplyingToMessage(nil))
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
            }
            
            Divider()
            
            HStack(spacing: 8) {
                TextField("Message \(store.conversation.title)...", text: $store.inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)
                Button {
                    if let editingMsg = store.editingMessage {
                        store.send(.updateMessageSubmitted(editingMsg.id, store.inputText))
                    } else {
                        store.send(.sendButtonTapped)
                    }
                } label: {
                    Image(systemName: store.editingMessage != nil ? "checkmark.circle.fill" : "paperplane.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .disabled(store.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .navigationTitle(store.conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 36, height: 36)
                        Text(store.conversation.title.prefix(1))
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.conversation.title)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        // Handle later
                    } label: {
                         Image(systemName: "phone")
                    }
                    Button {
                        // Handle later
                    } label: {
                        Image(systemName: "video")
                    }
                }
            }
        }
        .onAppear { store.send(.onAppear) }
    }
}

struct ReplyBannerView: View {
    let sendername: String
    let content: String
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.blue)
                .frame(width: 4, height: 36)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Replying to \(sendername)")
                    .font(.caption.bold())
                    .foregroundColor(.blue)
                
                Text(content)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
}

struct PrivateMessageBubble: View {
    let message: Message
    let replyingToMessage: Message?
    let onReply: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var isUser: Bool { message.role == .user }
    
    var body: some View {
        HStack {
            if isUser { Spacer() }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                if let reply = replyingToMessage {
                    Text(reply.content)
                        .font(.caption)
                        .padding(8)
                        .background(Color.black.opacity(0.1))
                        .cornerRadius(8)
                        .lineLimit(2)
                }
                
                if !message.allMedia.isEmpty {
                    MediaGridView(mediaItems: message.allMedia)
                }
                
                Text(message.content)
                    .padding(12)
                    .background(isUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(isUser ? .white : .primary)
                    .cornerRadius(16)
                
                HStack(spacing: 4) {
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if isUser {
                        switch message.status {
                        case .sending:
                            ProgressView().scaleEffect(0.6)
                        case .sent, .read:
                            Image(systemName: "checkmark").font(.caption2)
                        case .streaming:
                            EmptyView()
                        case .error:
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption2)
                        }
                    }
                }
            }
            .contextMenu {
                Button { onReply() } label: {
                    Label("Reply", systemImage: "arrowshape.turn.up.left")
                }
                if isUser {
                    Button { onEdit() } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) { onDelete() } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            
            if !isUser { Spacer() }
        }
    }
}

struct MediaGridView: View {
    let mediaItems: [MediaItem]
    
    var body: some View {
        if mediaItems.count == 1, let item = mediaItems.first {
            SingleMeidaView(item: item)
                .frame(maxWidth: 240, maxHeight: 280)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 4)], spacing: 4) {
                ForEach(mediaItems) { item in
                    SingleMeidaView(item: item)
                        .frame(width: 110, height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .frame(maxWidth: 230)
        }
    }
}

struct SingleMeidaView: View {
    let item: MediaItem
    @State private var showFullScreen = false
    
    var body: some View {
        ZStack {
            if item.isVideo && (item.thumbnail == nil || item.thumbnail?.isEmpty == true) {
                if let videoURL = item.url.asCleanURL {
                    VideoThumbnailView(videoURL: videoURL)
                }
            } else {
                let targetString = item.thumbnail ?? item.url
                RemoteThumbnailView(urlString: targetString)
                
                if item.isVideo {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 36, height: 36)
                        Image(systemName: "play.fill")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                }
            }
            
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showFullScreen = true
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            if item.isVideo, let url = URL(string: item.url) {
                VideoPlayerSheetView(videoURL: url)
            } else if let url = URL(string: item.url) {
                FullScreenRemoteImageView(url: url, onDismiss: { showFullScreen = false})
            }
        }
    }
}

struct RemoteThumbnailView: View {
    let urlString: String
    @State private var loadedImage: UIImage?
    @State private var isLoading = true
    @State private var hasError = false
    
    private static let cache = NSCache<NSString, UIImage>()
    
    var body: some View {
        ZStack {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if isLoading {
                ZStack {
                    Color.gray.opacity(0.15)
                    ProgressView()
                }
            } else {
                ZStack {
                    Color.gray.opacity(0.15)
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                }
            }
        }
        .task(id: urlString) {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        if let cached = Self.cache.object(forKey: urlString as NSString) {
            self.loadedImage = cached
            self.isLoading = false
            return
        }
        
        guard let url = urlString.asCleanURL else {
            self.isLoading = false
            self.hasError = true
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode),
               let image = UIImage(data: data) {
                Self.cache.setObject(image, forKey: urlString as NSString)
                await MainActor.run {
                    self.loadedImage = image
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                    self.hasError = true
                }
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.hasError = true
            }
        }
    }
}

struct VideoThumbnailView: View {
    let videoURL: URL
    @State private var thumbnailImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if isLoading {
                ZStack {
                    Color.black.opacity(0.85)
                    ProgressView()
                        .tint(.white)
                }
            } else {
                Color.black.opacity(0.85)
            }
            
            Circle()
                .fill(Color.black.opacity(0.6))
                .frame(width: 38, height: 38)
            
            Image(systemName: "play.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
        .task {
            await generateThumbnail()
        }
    }
    
    private func generateThumbnail() async {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        do {
            let time = CMTime(seconds: 0.5, preferredTimescale: 600)
            let cgImage = try await generator.image(at: time).image
            let uiImage = UIImage(cgImage: cgImage)
            await MainActor.run {
                self.thumbnailImage = uiImage
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

public struct VideoPlayerSheetView: View {
    let videoURL: URL
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    
    public init(videoURL: URL) {
        self.videoURL = videoURL
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let player = player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .navigationTitle("Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        player?.pause()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.8), for: .navigationBar)
            .onAppear {
                let avPlayer = AVPlayer(url: videoURL)
                self.player = avPlayer
                avPlayer.play()
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
        }
    }
}

struct FullScreenRemoteImageView: View {
    let url: URL
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView()
                }
            }
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white.opacity(0.8))
                    .padding()
            }
        }
    }
}

extension String {
    var asCleanURL: URL? {
        if let url = URL(string: self) { return url }
        if let encoded = self.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            return URL(string: encoded)
        }
        return nil
    }
}

