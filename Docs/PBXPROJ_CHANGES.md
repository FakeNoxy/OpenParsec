# PBXPROJ_CHANGES.md

> This file is the checklist of file-level changes that must be applied to `OpenParsec.xcodeproj/project.pbxproj` by the user at the end of the refactoring. Each phase lists the files that were created, deleted, renamed, or moved. Apply all entries for a phase together in a single Xcode project edit.

## Phase 1

### Deleted files (remove from project.pbxproj)
- DELETED: OpenParsec/Models/SharedModel.swift
- DELETED: OpenParsec/Helpers/TouchHandlingView.swift
- DELETED: OpenParsec/ViewControllers/ParsecPlayground.swift
- DELETED: OpenParsec/ViewControllers/ParsecKeyboard.swift

### Created files (add to project.pbxproj)
- CREATED: OpenParsec/Models/AppConstants.swift
- CREATED: OpenParsec/Models/CursorPositionHelper.swift
- CREATED: OpenParsec/Models/StreamSessionState.swift
- CREATED: OpenParsec/Models/ParsecResolution.swift
- CREATED: OpenParsec/Network/Models/IdentifiableModels.swift
- CREATED: OpenParsec/Utilities/Extensions/StringExtensions.swift
- CREATED: OpenParsec/Utilities/Extensions/ViewExtensions.swift
- CREATED: OpenParsec/Utilities/Logging.swift
- CREATED: OpenParsec/Settings/SettingTypes.swift
- CREATED: OpenParsec/Parsec/Input/TouchController.swift
- CREATED: OpenParsec/ViewControllers/ParsecRendererView.swift
- CREATED: OpenParsec/ViewControllers/ParsecVirtualKeyboard.swift

### Modified files (no pbxproj change needed, already in project)
- MODIFIED: OpenParsec/Parsec/SDK/CParsec.swift (ParsecResolution + MouseInfo removed)
- MODIFIED: OpenParsec/Parsec/SDK/ParsecTypes.swift (ConnectionLog, appNote, settings enums removed)
- MODIFIED: OpenParsec/App/ContentView.swift (.test case removed, GLBDataModel → AppConstants)
- MODIFIED: OpenParsec/Views/Main/MainView.swift (commented TestView button removed)
- MODIFIED: OpenParsec/Views/Main/MainViewMethods.swift (IdentifiableHostInfo/UserInfo/Page removed, GLBDataModel → AppConstants)
- MODIFIED: OpenParsec/Views/Stream/ParsecViewMethods.swift (genDisplaySheet + View extension removed, DataManager → StreamSessionState)
- MODIFIED: OpenParsec/Views/Stream/ParsecView.swift (DataManager → StreamSessionState)
- MODIFIED: OpenParsec/Views/Login/LoginView.swift (GLBDataModel → AppConstants)
- MODIFIED: OpenParsec/Parsec/SDK/ParsecSDKBridge.swift (commented block removed, DataManager → StreamSessionState)
- MODIFIED: OpenParsec/Parsec/Input/GameController.swift (commented block removed)
- MODIFIED: OpenParsec/ViewControllers/ParsecGLKViewController.swift (ParsecPlayground → ParsecRendererView)
- MODIFIED: OpenParsec/ViewControllers/ParsecMetalViewController.swift (ParsecPlayground → ParsecRendererView)
- MODIFIED: OpenParsec/ViewControllers/ParsecViewController.swift (ParsecPlayground → ParsecRendererView)
- MODIFIED: OpenParsec/Info.plist (armv7 → arm64)
- MODIFIED: README.md (iOS 14+ → iOS 17+)

## Phase 2

### Deleted files (remove from project.pbxproj)
- DELETED: OpenParsec/ViewControllers/ParsecGestureHandling.swift (content split into ParsecTouchController.swift + ParsecMenuEdge.swift)

### Created files (add to project.pbxproj)
- CREATED: OpenParsec/ViewControllers/ParsecHardwareKeyboard.swift (pressesBegan/Ended/Cancelled, startKeyRepeat/stopKeyRepeat/resetKeyState, isModifierKey)
- CREATED: OpenParsec/ViewControllers/ParsecKeyboardScrolling.swift (keyboardWillShow, accessoryClearBand, pictureShiftAboveKeyboard, updatePanHandle/setPanHandleVisible/setPanHandleAxes/layoutKeyBar, handlePanHandle/handlePanHandleDoubleTap, keyboardWillHide)
- CREATED: OpenParsec/ViewControllers/ParsecKeyboardLayout.swift (KeyboardButton class, inputAccessoryView, createKeyboardButton, toolbarButtons(in:), toolbarButtonClicked, doneTapped)
- CREATED: OpenParsec/ViewControllers/ParsecTouchController.swift (touch pipeline: parsecTouchesUpdated, moveCursor, handleTwoFinger, momentum/CADisplayLink, applyZoom, positionCursorOverlay, edge scroll, setZoomEnabled, UIScrollViewDelegate methods)
- CREATED: OpenParsec/ViewControllers/ParsecMenuEdge.swift (addMenuEdgeSwipe, updateMenuEdgeSwipe, handleMenuEdgeSwipe, tap/long-press handlers)

### Modified files (no pbxproj change needed, already in project)
- MODIFIED: OpenParsec/ViewControllers/ParsecViewController.swift (moved methods removed; panStartOffset/repeatTimer/repeatKeyCode/optCmdRemapActive/altKeyHeld access widened private → internal for cross-file extension access)
- MODIFIED: OpenParsec/ViewControllers/ParsecVirtualKeyboard.swift (inputAccessoryView/createKeyboardButton/toolbarButtons/toolbarButtonClicked/doneTapped moved to ParsecKeyboardLayout.swift)
- MODIFIED: OpenParsec/ViewControllers/ParsecTouchHelpers.swift (KeyboardButton class moved to ParsecKeyboardLayout.swift)

## Phase 3

### Deleted files (remove from project.pbxproj)
- DELETED: OpenParsec/Views/Main/MainViewMethods.swift (logic absorbed into MainViewModel.swift)

### Created files (add to project.pbxproj)
- CREATED: OpenParsec/Network/APIClient.swift (APIClient, APIError, APIResponse)
- CREATED: OpenParsec/Network/ParsecAPI.swift (ParsecAPI: authenticate/hosts/selfInfo/friends)
- CREATED: OpenParsec/Utilities/KeychainService.swift (KeychainService save/load/remove)
- CREATED: OpenParsec/Views/Login/LoginViewModel.swift (LoginViewModel: authenticate + restore)
- CREATED: OpenParsec/Views/Main/MainViewModel.swift (MainViewModel: refresh×3, connect/poll/retry, logout)

### Renamed files (update path in project.pbxproj, keep the same file reference ID)
- RENAMED: OpenParsec/Network/NetworkHandler.swift → OpenParsec/Network/SessionStore.swift (class NetworkHandler → SessionStore)
- RENAMED: OpenParsec/Settings/SettingsHandler.swift → OpenParsec/Settings/SettingsStore.swift (static proxy SettingsHandler deleted; SettingsStore class kept)

### Modified files (no pbxproj change needed, already in project)
- MODIFIED: OpenParsec/Models/AppConstants.swift (apiBaseURL + userAgent added)
- MODIFIED: OpenParsec/App/ContentView.swift (UI-only; owns LoginViewModel/MainViewModel, session restore moved to LoginViewModel)
- MODIFIED: OpenParsec/Views/Login/LoginView.swift (UI-only; auth + keychain moved to LoginViewModel)
- MODIFIED: OpenParsec/Views/Main/MainView.swift (UI-only; all logic moved to MainViewModel)
- MODIFIED: OpenParsec/UI/Components/URLImage.swift (dataTask → async/await URLSession.shared.data(for:))
- MODIFIED: OpenParsec/UI/Components/ExUI.swift (dead iOS<15 MultiPicker fallback + genActionSheet/select removed)
- MODIFIED: OpenParsec/Parsec/SDK/ParsecSDKBridge.swift (comment: SettingsHandler → SettingsStore)
- MODIFIED: all SettingsHandler call sites (≈30) → SettingsStore.shared
- MODIFIED: all NetworkHandler call sites → SessionStore

## Phase 4

### Deleted files (remove from project.pbxproj)
- (none)

### Created files (add to project.pbxproj)
- CREATED: OpenParsec/Parsec/Rendering/RenderLoop.swift (RenderLoop protocol + GLKViewController/MTKView conformances, moved out of ParsecBackgroundManager.swift / ParsecMetalViewController.swift)
- CREATED: OpenParsec/Managers/SessionCoordinator.swift (SessionCoordinator: scene lifecycle fan-out — sceneWillConnect/handleReconnectShortcut/sceneDidDisconnect/sceneDidBecomeActive/sceneWillResignActive/sceneWillEnterForeground/sceneDidEnterBackground)
- CREATED: OpenParsec/Views/Stream/ReconnectController.swift (ReconnectController: reconnect/disconnect state machine — attach/handle/holdFrame/pictureBack/poll/reconnectTo/disconnect, formerly inlined in ParsecStatusBar + ParsecViewMethods)
- CREATED: OpenParsec/Views/Stream/StreamMenuPanel.swift (StreamMenuPanel: stream menu, extracted verbatim from ParsecView.menuPanel)
- CREATED: OpenParsec/Parsec/SDK/UserDataHandler.swift (UserDataHandler: host user-data decoding — handle(event:)/resetResolutionLatch, extracted from ParsecSDKBridge.handleUserDataEvent)
- CREATED: OpenParsec/Parsec/Input/TextKeycodeResolver.swift (TextKeycodeResolver.resolve(text:), extracted from ParsecSDKBridge.getKeyCodeByText)
- CREATED: OpenParsec/Views/Main/Components/HostCard.swift (HostCard: host row, extracted from MainView)
- CREATED: OpenParsec/Views/Main/Components/FriendRow.swift (FriendRow: friend row, extracted from MainView)
- CREATED: OpenParsec/Views/Main/Components/LastHostCard.swift (LastHostCard: "Last connected" card, extracted from MainView)

### Renamed files (update path in project.pbxproj, keep the same file reference ID)
- (none)

### Modified files (no pbxproj change needed, already in project)
- MODIFIED: OpenParsec/Managers/ParsecBackgroundManager.swift (7 closure callbacks → enum Event + addEventHandler/removeEventHandler/emit + EventToken + canShortcutReconnect; RenderLoop protocol removed (moved to RenderLoop.swift); glkViewController → renderLoop)
- MODIFIED: OpenParsec/Parsec/Rendering/ParsecMetalRenderer.swift (upload(): onNextFrame consume-once → ParsecBackgroundManager.shared.emit(.nextFrame))
- MODIFIED: OpenParsec/ViewControllers/ParsecGLKViewController.swift (glkViewController → renderLoop)
- MODIFIED: OpenParsec/ViewControllers/ParsecMetalViewController.swift (extension MTKView: RenderLoop removed (moved to RenderLoop.swift); glkViewController → renderLoop)
- MODIFIED: OpenParsec/App/SceneDelegate.swift (thin forwarder to SessionCoordinator.shared)
- MODIFIED: OpenParsec/Views/Stream/ParsecStatusBar.swift (poll() state machine removed → pure UI over ReconnectController; 7 @State/@Binding vars → one @ObservedObject)
- MODIFIED: OpenParsec/Views/Stream/ParsecView.swift (7 reconnect @State vars → @StateObject ReconnectController; menuPanel → StreamMenuPanel; ParsecBackgroundDisconnect onReceive removed)
- MODIFIED: OpenParsec/Views/Stream/ParsecViewMethods.swift (post() → reconnect.attach(...); disconnect()/reconnectTo() removed (moved to ReconnectController); glkViewController → renderLoop; PiP handlers → reconnect.disconnect)
- MODIFIED: OpenParsec/Views/Main/MainViewModel.swift (onShouldReconnect/onShortcutReconnect → addEventHandler token + canShortcutReconnect)
- MODIFIED: OpenParsec/Views/Main/MainView.swift (host/friend/last-host cards → HostCard/FriendRow/LastHostCard; onShortcutReconnect = nil → canShortcutReconnect = false)
- MODIFIED: OpenParsec/Parsec/SDK/ParsecSDKBridge.swift (handleUserDataEvent → UserDataHandler; getKeyCodeByText → TextKeycodeResolver; didSetResolution moved to UserDataHandler; poll queues named parsec.poll.audio / parsec.poll.event)
- MODIFIED: OpenParsec/Parsec/SDK/CParsec.swift (destroy() now releases parsecImpl, triggering ParsecSDKBridge.deinit → ParsecDestroy + audio_destroy)

## Build warnings (for user's pbxproj pass)

> The following two build warnings originate from `OpenParsec.xcodeproj/project.pbxproj` and can only be fixed by editing the project file. These are actions the **USER** must perform when updating the project file — no source code changes were made for them.

### 1. "Skipping duplicate build file in Copy Bundle Resources build phase: OpenParsec/Base.lproj/LaunchScreen.storyboard"

- **Cause:** `LaunchScreen.storyboard` is listed **twice** in the target's *Copy Bundle Resources* build phase (two build-file entries pointing at the same file reference).
- **Fix (user action):** Remove the duplicate `LaunchScreen.storyboard` entry from the *Copy Bundle Resources* phase so that exactly **one** reference remains.
  - Xcode UI: Select the **OpenParsec** target → *Build Phases* → expand **Copy Bundle Resources** → select the duplicate `LaunchScreen.storyboard` row → click the **−** (minus) button.
  - Note: the storyboard is also referenced via the `UILaunchStoryboardName` info property, which is correct and must be kept — only the *duplicate build-phase entry* is removed.

### 2. "Run script build phase 'Run Script' will be run during every build because it does not specify any outputs"

- **Cause:** The *Run Script* build phase declares no output files, so Xcode cannot use dependency analysis and runs the script on every build.
- **Fix (user action) — pick one:**
  - **Option A — declare outputs (preferred if the script produces files):**
    1. Select the **OpenParsec** target → *Build Phases* → **Run Script**.
    2. Expand the **Output Files** section (click the disclosure triangle).
    3. Click **+** and add the file path(s) the script produces (e.g. `$(TARGET_BUILD_DIR)/...` or a relative path to the generated file).
    4. Xcode will then run the script only when its inputs change or its outputs are missing.
  - **Option B — force it to run every build (if the script genuinely must run on every build):**
    1. Select the **OpenParsec** target → *Build Phases* → **Run Script**.
    2. Make sure the **"Based on dependency analysis"** checkbox is **unchecked** (uncheck it if it is checked).
    3. This sets `alwaysOutOfDate = 1` on the phase; Xcode will then run the script on every build and the warning goes away.
 
 ## Phase 5
 
 ### Created files (add to project.pbxproj)
 
 > Phase 5 introduces the **`OpenParsecTests`** unit-test target. The user must:
 > 1. Create a new **Unit Testing Bundle** target named `OpenParsecTests` (Xcode → File → New → Target → Unit Testing Bundle), set its **Bundle Identifier** (e.g. `com.aigch.OpenParsecTests`), and add it to the **OpenParsec** scheme's *Test* action.
 > 2. Add the five test source files below to the `OpenParsecTests` target (drag them in, or add them via *Target Membership*).
 > 3. Ensure the app target is a dependency of the test target (Xcode does this automatically when the target is created against the app) so `@testable import OpenParsec` resolves.
 
 - CREATED: OpenParsecTests/KeyCodeTranslatorsTests.swift (KeyCodeTranslators.parsecKeyCodeTranslator / getParsecKeycode / uiKeyCodeToInt + TextKeycodeResolver.resolve — letters, digits, special keys, punctuation, fullwidth variants, unresolvable input)
 - CREATED: OpenParsecTests/CursorPositionHelperTests.swift (CursorPositionHelper.toHost / toClient — identity mapping, origin, center, clamping, negative values, round-trips; uses CParsec.initialize()/destroy() for a deterministic 1920×1080 bridge)
 - CREATED: OpenParsecTests/APIClientTests.swift (APIError accessors + case discrimination, APIResponse storage, decode-pattern replication of APIClient.data(), baseURL/userAgent constants; documents the non-injectable URLSession.shared limitation)
 - CREATED: OpenParsecTests/SettingsStoreTests.swift (SettingsStore round-trip for all settings + registered defaults; save/restore of UserDefaults.standard in setUp/tearDown; documents the non-injectable singleton limitation)
 - CREATED: OpenParsecTests/ReconnectControllerTests.swift (ReconnectController initial state, .endedInBackground event transitions, attach idempotency; documents that poll()/reconnectTo() require a live SDK connection and are deliberately not tested)
 
 ### Modified files (no pbxproj change needed, already in project)
 
 - MODIFIED: OpenParsec/Network/SessionStore.swift (concurrency fix: `clinfo` now guarded by an `NSLock` — written from main-actor view models, read from `APIClient.perform()` off-main; behavior-preserving)
 - MODIFIED: OpenParsec/Models/AppConstants.swift (one-line doc comment added)
 - MODIFIED: OpenParsec/Models/CursorPositionHelper.swift (one-line doc comment added)
 - MODIFIED: OpenParsec/Models/StreamSessionState.swift (`// MARK: -` header + one-line doc comment added)
 - MODIFIED: OpenParsec/Models/ParsecResolution.swift (`// MARK: -` header + one-line doc comment added)
 - MODIFIED: OpenParsec/Network/Models/IdentifiableModels.swift (one-line doc comment added)
 - MODIFIED: OpenParsec/Utilities/Extensions/StringExtensions.swift (one-line doc comment added)
 - MODIFIED: OpenParsec/Utilities/Extensions/ViewExtensions.swift (one-line doc comment added)
 - MODIFIED: OpenParsec/Utilities/Logging.swift (`// MARK: -` header + one-line doc comment added)
 - MODIFIED: OpenParsec/Settings/SettingTypes.swift (one-line doc comment added)
 - MODIFIED: OpenParsec/Settings/SettingsStore.swift (`// MARK: -` header + one-line doc comment added)
 - MODIFIED: OpenParsec/Parsec/Input/TouchController.swift (one-line doc comment added)
 - MODIFIED: OpenParsec/ViewControllers/ParsecRendererView.swift (one-line doc comment added)
 - MODIFIED: OpenParsec/ViewControllers/ParsecHardwareKeyboard.swift (`// MARK: -` header + one-line doc comment added)
 - MODIFIED: OpenParsec/ViewControllers/ParsecKeyboardScrolling.swift (`// MARK: -` header + one-line doc comment added)
 - MODIFIED: OpenParsec/ViewControllers/ParsecKeyboardLayout.swift (`// MARK: -` header + one-line doc comment added)
 - MODIFIED: OpenParsec/ViewControllers/ParsecMenuEdge.swift (`// MARK: -` header + one-line doc comment added)
 - MODIFIED: OpenParsec/ViewControllers/ParsecTouchController.swift (`// MARK: -` header + one-line doc comment added)
 
 ### User pbxproj actions (Phase 5)
 
 1. **Create the `OpenParsecTests` unit-test target** and add the five test files listed above to it (see "Created files" note).
 2. **Set `SWIFT_STRICT_CONCURRENCY = minimal`** in the **OpenParsec** app target's build settings (*Swift Compiler — Concurrency → Strict Concurrency Checking = Minimal*) to enable ongoing concurrency checking.
   - Xcode UI: Select the **OpenParsec** target → *Build Settings* → search for "Strict Concurrency" → set **Swift Compiler - Concurrency: Strict Concurrency Checking** to **Minimal**.

## Audit corrections

> The following entries were missing from the original checklist and are appended here as corrections.

### Renamed files (update path in project.pbxproj, keep the same file reference ID)

The original document listed the following pairs as separate DELETED + CREATED entries. They should be treated as **renames** (update the file reference path, keep the same file reference ID):

- RENAMED: OpenParsec/ViewControllers/ParsecKeyboard.swift → OpenParsec/ViewControllers/ParsecVirtualKeyboard.swift (Phase 1)
- RENAMED: OpenParsec/ViewControllers/ParsecPlayground.swift → OpenParsec/ViewControllers/ParsecRendererView.swift (Phase 1)

### User pbxproj actions (missing from original document)

- **Raise the project deployment target from 13.0 to 17.0.**
 - Xcode UI: Select the **OpenParsec** target → *General* → **Minimum Deployments** → set **iOS** to **17.0**.
 - Or in *Build Settings*: search for "Deployment Target" → set **iOS Deployment Target** to **17.0**.

## Bugfixes

- FIXED (in-place, no pbxproj change): `OpenParsec/Parsec/SDK/ParsecSDKBridge.swift` `startBackgroundTask()` — the Phase 4 queue-naming edit called `DispatchQueue.global(qos: .utility, name: "parsec.poll.audio")` / `...("parsec.poll.event")`, but `DispatchQueue.global(qos:)` has no `name:` parameter (compile error "Extra argument 'name' in call"). Replaced with the labeled-queue initializers `DispatchQueue(label: "parsec.poll.audio", qos: .utility)` / `DispatchQueue(label: "parsec.poll.event", qos: .utility)`, preserving the descriptive queue names and the `.utility` QoS; polling-loop behavior unchanged.
- FIXED (in-place, no pbxproj change): `OpenParsec/Parsec/SDK/UserDataHandler.swift` `handle(event:)` — the Phase 4 extraction left a bare `parsec` in `ParsecGetBuffer(parcsec, event.key)` (compile error "Cannot find 'parsec' in scope"); the bridge's SDK handle is the handler's own stored `parsec` property (injected via `init(_ parsec:)`), so the call now reads `ParsecGetBuffer(self.parsec, event.key)` — same SDK call, same handle, no new dependency introduced.
