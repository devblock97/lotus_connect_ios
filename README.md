# Lotus Connect (iOS)

<p align="center">
  <img src="docs/screenshots/home_screen_dark.png" alt="Lotus Connect Home Screen (Dark Mode)" width="320"/>
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="docs/screenshots/home_screen.png" alt="Lotus Connect Home Screen (Light Mode)" width="320"/>
</p>

<p align="center">
  <b>A modern, high-performance social messaging and stories client for iOS.</b><br/>
  Engineered with Point-Free’s <b>The Composable Architecture (TCA)</b> and <b>SwiftUI</b>.
</p>

---

## 🌟 Highlights

- **Instagram-Grade Stories**: Interactive horizontal story tray with custom gradient rings, negative-space gaps, and a full-screen story player with segmented progress bars (auto-advancing, tap to skip, long-press to pause, and interactive drag-down dismiss).
- **Rich Media Feeds**: Multi-image horizontal post carousels with swipeable page indicators, floating counters (`1/4`), double-tap likes, and author badges.
- **Real-Time Messaging**: WebSocket-powered chat with instant bi-directional messaging, live typing indicators, message edits, and deletions.
- **Friend & Contact Management**: Segmented contact directory featuring alphabetical indexation, pending connection requests, and live debounced user search.
- **Architectural Purity**: Built entirely upon TCA 1.26+ conventions using `@ObservableState`, scoped reducers, isolated side-effects, and dependency injection.

---

## 📱 Screenshots

| Home & Stories (Dark) | Home & Stories (Light) | Authentication |
|:---:|:---:|:---:|
| <img src="docs/screenshots/home_screen_dark.png" width="260"/> | <img src="docs/screenshots/home_screen.png" width="260"/> | <img src="docs/screenshots/auth_login.png" width="260"/> |

---

## 🏗️ Architecture & Tech Stack

```
lotus_connect_ios/
├── App/
│   ├── Navigation/       # RootTabView, RootTabFeature, MainTab
│   ├── AppFeature.swift  # Top-level state coordinator
│   └── AppView.swift
├── Features/
│   ├── Home/             # Stories tray, full-screen story viewer, feed carousels
│   ├── Chat/             # Real-time message bubbles, WebSockets
│   ├── ChatList/         # Conversation threads and inbox
│   ├── Chatbot/          # AI conversational streaming assistant
│   ├── Contacts/         # Contact directory, pending requests, search
│   ├── Auth/             # Session restoration, Keychain client, login/signup
│   └── Notifications/    # Activity and notifications feed
├── Domain/
│   └── Models/           # Post, Story, User, Message, Conversation entities
└── Core/
    ├── Network/          # URLSession HTTPClient abstractions
    └── Security/         # Keychain session storage
```

### Technology Matrix
- **UI Framework**: SwiftUI (iOS 17+)
- **State Management**: [The Composable Architecture (TCA)](https://github.com/pointfreeco/swift-composable-architecture) `v1.26.1`
- **Concurrency**: Native Swift Concurrency (`async`/`await`, `AsyncStream`, `@Sendable`)
- **Networking**: URLSession & WebSocket Task Engine
- **Image Loading**: Native `AsyncImage` with progressive caching and custom fallbacks
- **Security**: Keychain Services with biometrics support

---

## 🚀 Getting Started

### Prerequisites
- macOS Sonoma or later
- Xcode 16.0+ (iOS 17.0+ SDK)
- Simulator or physical iOS device

### Installation & Run

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/lotus_connect_ios.git
   cd lotus_connect_ios
   ```

2. **Open in Xcode:**
   ```bash
   open lotus_connect_ios.xcodeproj
   ```

3. **Resolve Swift Package Dependencies:**
   Xcode will automatically fetch Point-Free's dependencies (`swift-composable-architecture`, `swift-dependencies`, `swift-navigation`).

4. **Run the Project:**
   Select your desired simulator target (e.g. `iPhone 16 Pro` or `iPhone 17`) and press **Cmd + R**.

---

## 🤝 Pair Programming & Contributing

- Adheres to Point-Free TCA strict concurrency guidelines and Swift 6 language mode compatibility.
- Views observe state granularly through `@ObservableState` and `@Bindable`.
- Reducer actions follow explicit intent-based naming (`storyTapped`, `likeButtonTapped`, `refreshPulled`).