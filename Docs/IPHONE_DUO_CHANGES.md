# iPhone Duo Compatibility Changes

## Summary
This document outlines all changes made to prepare OpenParsec for iPhone Duo (Apple's foldable iPhone).

## Key Requirements Addressed

### 1. Removed `UIScreen.main` Usage
**Issue:** iPhone Duo has dynamic screen sizes that change when folding/unfolding. Using `UIScreen.main` for sizing breaks adaptive layouts.

**Files Changed:**
- `ParsecViewController.swift` (4 instances)
- `ParsecView.swift` (2 instances)
- `ParsecGLKViewController.swift` (2 instances)
- `ParsecMetalViewController.swift` (2 instances)
- `MainView.swift` (1 instance)

**Solution:** Replaced with view/window-scoped screen references:
```swift
// Before
let scale = UIScreen.main.scale
let fps = UIScreen.main.maximumFramesPerSecond

// After
let scale = view.window?.screen.scale ?? 2.0
let fps = view.window?.screen.maximumFramesPerSecond ?? 60
```

### 2. Removed Device Idiom Checks
**Issue:** `UIDevice.current.userInterfaceIdiom` can't reliably identify iPhone Duo (it can behave like both phone and pad).

**Files Changed:**
- `SettingsView.swift` (1 instance)

**Solution:** Use generic labels instead of device-specific ones:
```swift
// Before
UIDevice.current.userInterfaceIdiom == .pad ? "Hide iPad Status Bar" : "Hide iPhone Status Bar"

// After
"Hide Status Bar"
```

### 3. Updated Deployment Target
**Issue:** iPhone Duo requires iOS 17+ for proper foldable support.

**Files Changed:**
- `OpenParsec.xcodeproj/project.pbxproj`

**Solution:** Updated `IPHONEOS_DEPLOYMENT_TARGET` from `14.0` to `17.0`

### 4. Added Portrait Upside Down Support
**Issue:** iPhone Duo needs all orientation support for flexible folding states.

**Files Changed:**
- `Info.plist`

**Solution:** Added `UIInterfaceOrientationPortraitUpsideDown` to `UISupportedInterfaceOrientations`

### 5. Improved Window Scene Handling
**Issue:** No key window during launch reconnect on dynamic-sized devices.

**Files Changed:**
- `MainView.swift`

**Solution:** Added UIWindowScene fallback for getting screen dimensions:
```swift
if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
    let scale = scene.screen.nativeScale
    let size = scene.coordinateSpace.visibleSize
    ParsecResolution.updateClientResolution(width: Int(size.width * scale), height: Int(size.height * scale))
}
```

## Testing Recommendations

1. **Test on iOS Simulator with various window sizes** (if available)
2. **Test rotation handling** - ensure stream resizes correctly
3. **Test split-screen/multitasking** - verify adaptive layouts
4. **Test frame rate changes** - ensure FPS adapts to screen capabilities
5. **Test resolution changes** - verify client resolution updates correctly

## Files Modified

1. `OpenParsec/Info.plist` - Added portrait upside down orientation
2. `OpenParsec.xcodeproj/project.pbxproj` - Updated deployment target
3. `OpenParsec/ParsecViewController.swift` - Removed UIScreen.main usage
4. `OpenParsec/ParsecView.swift` - Removed UIScreen.main usage
5. `OpenParsec/ParsecGLKViewController.swift` - Removed UIScreen.main usage
6. `OpenParsec/ParsecMetalViewController.swift` - Removed UIScreen.main usage
7. `OpenParsec/MainView.swift` - Improved window scene handling
8. `OpenParsec/SettingsView.swift` - Removed device idiom check

## Notes

- All changes maintain backward compatibility with existing iPhone and iPad models
- Fallback values are provided for safety (e.g., `?? 2.0` for scale, `?? 60` for FPS)
- Comments marked with "iPhone Duo:" indicate changes made specifically for foldable device support
