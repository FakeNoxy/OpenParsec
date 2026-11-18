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
