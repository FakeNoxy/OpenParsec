# OpenParsec Refactoring Strategy

## Executive Summary

This document outlines a comprehensive strategy to improve the code quality and maintainability of the OpenParsec iOS application. The current codebase has two primary issues:
1. **Flat folder structure** - All Swift files reside in a single `OpenParsec/` directory
2. **Oversized files** - Several files exceed 600+ lines and handle multiple unrelated responsibilities

---

## Part 1: Proposed Folder Structure

### Current State (Flat)
```
OpenParsec/
├── AppDelegate.swift
├── ContentView.swift
├── MainView.swift
├── ParsecView.swift
├── ParsecViewController.swift  (1591 lines - LARGEST)
├── ParsecSDKBridge.swift       (730 lines)
├── KeyCodeTranslators.swift    (602 lines)
├── PictureInPictureManager.swift
├── ... (all other files in root)
```

### Proposed Structure (Layered Architecture)

```
OpenParsec/
│
├── App/                          # App lifecycle & entry points
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   └── ContentView.swift         # Root view coordinator
│
├── Views/                        # SwiftUI Views
│   ├── Login/
│   │   └── LoginView.swift
│   ├── Main/
│   │   ├── MainView.swift
│   │   └── Components/           # Reusable sub-components
│   │       ├── HostCardView.swift
│   │       ├── ConnectionOverlayView.swift
│   │       └── RefreshHeaderView.swift
│   ├── Stream/                   # Parsec streaming view
│   │   ├── ParsecView.swift
│   │   ├── ParsecStatusBar.swift
│   │   ├── MenuPanelView.swift
│   │   └── ConnectionLogPanel.swift
│   └── Settings/
│       └── SettingsView.swift
│
├── ViewControllers/              # UIKit View Controllers
│   ├── ParsecViewController.swift
│   ├── ParsecGLKViewController.swift
│   └── ParsecMetalViewController.swift
│
├── Managers/                     # Singleton service managers
│   ├── ParsecBackgroundManager.swift
│   ├── PictureInPictureManager.swift
│   ├── NetworkWatcher.swift
│   └── ConnectionLog.swift
│
├── Network/                      # API & networking
│   ├── NetworkHandler.swift
│   ├── APIClient.swift           # (new - extract HTTP logic)
│   └── Models/                   # API response models
│       ├── ClientInfo.swift
│       ├── HostInfo.swift
│       ├── UserInfo.swift
│       └── FriendInfo.swift
│
├── Parsec/                       # Parsec SDK integration
│   ├── SDK/
│   │   ├── ParsecSDKBridge.swift
│   │   ├── CParsec.swift         # Facade wrapper
│   │   └── ParsecService.swift   # Protocol definition
│   ├── Input/
│   │   ├── GameController.swift
│   │   ├── TouchController.swift
│   │   └── KeyCodeTranslators.swift
│   └── Rendering/
│       ├── ParsecGLKRenderer.swift
│       ├── ParsecMetalRenderer.swift
│       └── ParsecPlayground.swift # Protocol
│
├── Settings/                     # Settings & preferences
│   ├── SettingsStore.swift
│   ├── SettingsHandler.swift     # Static proxy (keep for migration)
│   └── SettingsModels.swift      # Enum definitions
│
├── Models/                       # Data models & shared state
│   ├── SharedModel.swift         # (renamed from Shared.swift)
│   ├── ParsecResolution.swift
│   ├── MouseInfo.swift
│   └── ParsecStatusExtensions.swift
│
├── Utilities/                    # Helpers & extensions
│   ├── CursorPositionHelper.swift
│   ├── KeychainHelper.swift      # (new - extract keychain logic)
│   └── Extensions/
│       ├── StringExtensions.swift
│       └── ViewExtensions.swift
│
├── UI/Components/                # Reusable UI components
│   ├── ActivityIndicator.swift
│   ├── URLImage.swift
│   ├── CatTitle.swift
│   ├── CatList.swift
│   ├── CatItem.swift
│   ├── CatSlider.swift
│   ├── SegmentPicker.swift
│   ├── MultiPicker.swift
│   └── Choice.swift
│
├── Helpers/                      # Small utility classes
│   ├── UIViewControllerWrapper.swift
│   ├── TouchHandlingView.swift
│   ├── ViewContainerPatch.swift
│   └── KeyBoardTest.swift
│
└── Resources/
    ├── Assets.xcassets/
    ├── Base.lproj/
    └── Info.plist
```

---

## Part 2: File Splitting Strategy

### 2.1 ParsecViewController.swift (1591 lines → ~6 files)

**Current problems:**
- Handles touch input, keyboard, cursor management, zoom, momentum physics, PiP, rendering setup, and menu gestures all in one file
- Over 1591 lines - exceeds reasonable file size by 3x

**Proposed split:**

| New File | Responsibility | Lines (est.) |
|----------|---------------|--------------|
| `ParsecViewController.swift` | Core VC lifecycle, view setup, coordination | ~250 |
| `TouchInputHandler.swift` | Touch delegate, cursor movement, pinch/zoom gestures, momentum physics | ~400 |
| `KeyboardManager.swift` | Virtual keyboard, accessory view, keyboard visibility, toolbar buttons | ~350 |
| `CursorManager.swift` | Cursor positioning, overlay, viewport centering, edge scrolling | ~250 |
| `MenuGestureHandler.swift` | Edge swipe gestures, menu toggle logic | ~100 |
| `ParsecViewController+Zoom.swift` (extension) | Zoom-specific logic | ~100 |

---

### 2.2 ParsecView.swift (978 lines → ~3 files)

**Current problems:**
- Combines the main stream view, status bar polling logic, menu panel, and connection state management

**Proposed split:**

| New File | Responsibility | Lines (est.) |
|----------|---------------|--------------|
| `ParsecView.swift` | Main stream view composition | ~200 |
| `ParsecStatusBar.swift` | Already separate - keep as is | ~200 |
| `StreamConnectionManager.swift` | Reconnect logic, disconnect handling, state polling | ~250 |
| `MenuPanelView.swift` | In-stream menu panel UI | ~150 |

---

### 2.3 ParsecSDKBridge.swift (730 lines → ~3 files)

**Current problems:**
- Mixes SDK initialization, input handling (mouse, keyboard, gamepad), frame rendering, and audio

**Proposed split:**

| New File | Responsibility | Lines (est.) |
|----------|---------------|--------------|
| `ParsecSDKBridge.swift` | SDK init, connect/disconnect, status, config | ~250 |
| `InputSender.swift` | Mouse, keyboard, gamepad message sending | ~250 |
| `FrameRenderer.swift` | Frame polling, audio polling, render loop | ~200 |

---

### 2.4 KeyCodeTranslators.swift (602 lines → ~2 files)

**Current problems:**
- Massive switch statements for key code mapping

**Proposed split:**

| New File | Responsibility | Lines (est.) |
|----------|---------------|--------------|
| `UIKeyCodeTranslator.swift` | UIKeyboardHIDUsage → Parsec keycode | ~250 |
| `CharacterKeyCodeTranslator.swift` | Character/string → Parsec keycode | ~200 |

**Alternative:** Consider using a `Dictionary`-based lookup instead of switch statements to reduce code size by ~60%.

---

### 2.5 MainView.swift (824 lines → ~3 files)

**Current problems:**
- Host list, friend list, connection logic, and API calls all mixed together

**Proposed split:**

| New File | Responsibility | Lines (est.) |
|----------|---------------|--------------|
| `MainView.swift` | Main hosts/friends tab UI | ~250 |
| `HostManager.swift` | Host list refresh, friend list refresh, API calls | ~250 |
| `ConnectionManager.swift` | Connect to host, poll connection status, retry logic | ~200 |

---

### 2.6 NetworkHandler.swift + API Models (already reasonable)

**Current state:** Contains API model structs mixed with network monitoring logic

**Proposed split:**

| New File | Responsibility |
|----------|---------------|
| `Network/NetworkHandler.swift` | Just the `clinfo` static property |
| `Managers/NetworkWatcher.swift` | Network path monitoring |
| `Network/Models/ClientInfo.swift` | ClientInfo struct |
| `Network/Models/HostInfo.swift` | HostInfo, HostInfoList structs |
| `Network/Models/UserInfo.swift` | UserInfo, SelfInfo structs |
| `Network/Models/FriendInfo.swift` | FriendInfo structs |

---

## Part 3: Architectural Improvements

### 3.1 Adopt MVVM Pattern

**Current:** Views directly call `CParsec`, `SettingsHandler`, `DataManager`, and `ParsecBackgroundManager`

**Proposed:**
```
Views (SwiftUI)
    ↓
ViewModels (ObservableObject)
    ↓
Managers/Services (Singletons)
    ↓
Parsec SDK (CParsec → ParsecSDKBridge)
```

**New ViewModel files to create:**
- `StreamViewModel.swift` - Manages stream state, reconnect logic
- `MainViewModel.swift` - Manages host list, connection state
- `LoginViewModel.swift` - Manages authentication flow

### 3.2 Dependency Injection

Replace direct singleton access with protocol-based dependencies:
```swift
protocol ParsecService { ... }          // Already exists ✓
protocol SettingsProvider { ... }       // New
protocol NetworkProvider { ... }        // New
protocol BackgroundManager { ... }      // New
```

### 3.3 Extract Keychain Operations

Create `KeychainHelper.swift`:
```swift
class KeychainHelper {
    static func save(_ data: Data, key: String)
    static func load(key: String) -> Data?
    static func remove(key: String)
}
```
This eliminates keychain code scattered across `LoginView.swift`, `MainView.swift`, and `ContentView.swift`.

### 3.4 Centralize API Calls

Create `APIClient.swift`:
```swift
class APIClient {
    func fetchHosts() async throws -> [HostInfo]
    func fetchFriends() async throws -> [FriendInfo]
    func fetchUserInfo() async throws -> SelfInfoData
    func authenticate(email: String, password: String, tfa: String?) async throws -> ClientInfo
}
```

### 3.5 Settings Refactoring

`SettingsHandler` is a static struct that proxies to `SettingsStore`. This is an anti-pattern:
- **Option A:** Use `SettingsStore.shared` directly (ObservableObject)
- **Option B:** Use `@AppStorage` property wrapper directly in views
- **Option C:** Keep `SettingsHandler` but mark as deprecated, migrate gradually

---

## Part 4: Migration Plan

### Phase 1: Low-Risk Organization (Week 1)
- [ ] Create folder structure
- [ ] Move existing files to new locations (no code changes)
- [ ] Update import paths if needed
- [ ] Verify Xcode build still works

### Phase 2: Extract Models (Week 2)
- [ ] Move API model structs to `Network/Models/`
- [ ] Extract `KeychainHelper`
- [ ] Split `Shared.swift` → `Models/` folder
- [ ] Move enums to `Settings/SettingsModels.swift`

### Phase 3: Split Largest Files (Weeks 3-4)
- [ ] Split `ParsecViewController.swift` (highest impact)
- [ ] Split `ParsecView.swift`
- [ ] Split `ParsecSDKBridge.swift`

### Phase 4: Architectural Improvements (Weeks 5-6)
- [ ] Create ViewModels
- [ ] Extract `APIClient`
- [ ] Migrate to async/await for network calls
- [ ] Introduce protocol-based dependencies

### Phase 5: Polish (Week 7)
- [ ] Add SwiftLint configuration
- [ ] Add documentation comments
- [ ] Remove deprecated code paths
- [ ] Update README with architecture overview

---

## Part 5: Code Quality Recommendations

### 5.1 File Size Guidelines
- **Maximum:** 400 lines per file
- **Warning threshold:** 300 lines
- **Ideal:** 150-250 lines

### 5.2 Naming Conventions
- Use `Manager` suffix for singletons that manage state/lifecycle
- Use `Handler` suffix for event/callback processors
- Use `Provider` suffix for protocol-based data sources
- Use `ViewModel` suffix for ObservableObject view models

### 5.3 Swift-Specific Improvements
1. Replace `Timer`-based polling with `async/await` + `Task`
2. Use `@MainActor` instead of `DispatchQueue.main.async`
3. Replace `NotificationCenter` with `@Published` properties where possible
4. Use `Result` type instead of error domains for API responses
5. Add `actor` for thread-safe managers

### 5.4 Testing Strategy
With proper folder structure and protocol-based dependencies:
- Unit test ViewModels independently
- Mock `ParsecService` for view testing
- Integration test `APIClient` with test endpoints

---

## Part 6: Quick Wins (Immediate Improvements)

1. **Add SwiftLint** - Create `.swiftlint.yml` to enforce consistent style
2. **Add file header comments** - Brief description at top of each file
3. **Consolidate MARK comments** - Use `// MARK: -` consistently
4. **Remove dead code** - Commented-out blocks in `MainView.swift`, `KeyCodeTranslators.swift`
5. **Use `guard let` consistently** - Replace nested `if let` with early returns
6. **Extract repeated URL construction** - Network API URLs appear in multiple files

---

## Summary of Changes

| Metric | Before | After (Target) |
|--------|--------|---------------|
| Root-level Swift files | 28+ | ~8 (App lifecycle only) |
| Largest file | 1591 lines | ~350 lines |
| Average file size | 280 lines | 150-200 lines |
| Folder depth | 1 | 2-3 |
| Separation of concerns | Mixed | Clear layers |
| Testability | Difficult | Protocol-based mocking |
