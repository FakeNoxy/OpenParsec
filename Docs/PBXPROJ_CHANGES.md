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
