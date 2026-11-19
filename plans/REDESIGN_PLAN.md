# OpenParsec UI Redesign Plan

**Date:** 2026-11-19
**Scope:** Main menu (Hosts + Friends), Login, Settings — visual only, no functional changes
**Target:** iPhone Duo (foldable) + all iPhone/iPad, minimum iOS 17

## Goals

1. Follow Apple HIG for iPhone Duo: system toolbars/tab bars on the vertical axis, size-class adaptive layouts, no fixed widths.
2. Modern visual language: hybrid of Liquid Glass (iOS 26+) with an iOS 17-safe fallback (`.ultraThinMaterial` + hairline strokes), keeping the existing dark palette.
3. Preserve 100% of existing functionality (connect, reconnect, logout, refresh, settings toggles) wired to the same `MainViewModel` / `SettingsStore` calls.

## Key references

- `Docs/Duo Design Documentation/Designing for iPhone Duo | Apple Developer Documentation.pdf` — vertical controls, size classes, reserved regions, arrangement views.
- `Docs/Duo Design Documentation/Layout | Apple Developer Documentation.pdf` — visual hierarchy, adaptability, Liquid Glass for controls.
- `Docs/Samples/` — current app in 3 Duo poses + Netflix as the modern reference.
- `Docs/IPHONE_DUO_CHANGES.md` — prior Duo compatibility work (deployment target already 17.0).

## Design decisions

| Element | Before | After |
|---|---|---|
| Top bar | Custom HStack in `MainView` | `NavigationStack` + system `toolbar` (auto vertical-axis on Duo outer display) |
| Tab bar | Custom bottom HStack | System `TabView` (Hosts / Friends), standard bar compression |
| Hosts layout | 1-col, `maxWidth: 400` | `LazyVGrid`: 1 col compact width, 2 cols regular width |
| Last host | Inline card | Hero card, full width |
| Cards | Flat `BackgroundCard` | Glass (iOS 26) / `.ultraThinMaterial` fallback, 12–16pt radii |
| Typography | Hard-coded sizes | Dynamic Type (`body`, `title3`, `caption`, ...) |
| Login/Settings | Flat forms | Glass cards, rounded fields, grouped sections |

### iOS 17 compatibility

Liquid Glass APIs (`.glassEffect()`, `GlassEffectContainer`) are iOS 26+ only. Pattern:

```swift
if #available(iOS 26.0, *) {
    content.glassEffect(.regular, in: .rect(cornerRadius: 16))
} else {
    content
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08)))
}
```

Everything else used (`NavigationStack`, `TabView`, `LazyVGrid`, `containerRelativeFrame`) is iOS 16/17-safe.

## Files to change

- `OpenParsec/UI/Components/` — new design-system helpers (glass modifier, spacing/radius tokens, button style)
- `OpenParsec/Views/Main/MainView.swift`
- `OpenParsec/Views/Main/Components/HostCard.swift`
- `OpenParsec/Views/Main/Components/LastHostCard.swift`
- `OpenParsec/Views/Main/Components/FriendRow.swift`
- `OpenParsec/Views/Login/LoginView.swift`
- `OpenParsec/Views/Settings/SettingsView.swift`
- `OpenParsec/UI/Components/ExUI.swift` (CatTitle/CatList/CatItem/CatSlider/MultiPicker/SegmentPicker)

## Execution steps

1. Create design-system helpers in `OpenParsec/UI/Components`: `GlassBackground` modifier (iOS 26 `.glassEffect` with `.ultraThinMaterial` fallback), `AppSpacing`/`AppRadius` tokens, modern button style.
2. Rebuild `MainView.swift`: replace custom top/bottom bars with `NavigationStack` + system toolbar (logout, refresh, settings items) and a system `TabView` (Hosts/Friends) so Duo's vertical-axis placement is automatic.
3. Make `MainView` layout size-class adaptive: `LazyVGrid` with 1 column at compact width, 2 columns at regular width; remove fixed `maxWidth: 400` constraints; restyle session-expired/refresh-error banners as modern glass banners.
4. Redesign `HostCard.swift`: glass card, rounded avatar, hostname/user hierarchy with Dynamic Type, connection-count badge, full-width Connect button in accent style.
5. Redesign `LastHostCard.swift` as a hero card: full-width, prominent Reconnect action, keep the auto-reconnect toggle.
6. Redesign `FriendRow.swift` and the Friends page header (You card) with glass styling, rounded avatars, consistent spacing.
7. Modernize `LoginView.swift`: glass card container, rounded text fields, large accent Login button, restyle the TFA/loading overlay to match.
8. Modernize `SettingsView.swift` and `ExUI.swift` components: grouped sections, glass styling, standard toggle/picker appearances.
9. Restyle the connecting/loading overlay in `MainView` to the new design language (material background, modern spinner + Cancel button).
10. Verify: previews at compact and regular width, iOS 17 fallback paths compile (no unconditional iOS 26 APIs), no functional behavior changed (connect/reconnect/logout/refresh/toggles all wired to the same `MainViewModel`/`SettingsStore` calls).

## Constraints

- Minimum deployment target: iOS 17 (`IPHONEOS_DEPLOYMENT_TARGET = 17.0` in the app target).
- No changes to `MainViewModel`, `SettingsStore`, networking, or Parsec SDK integration.
- Keep the existing dark color assets (`BackgroundCard`, `BackgroundTab`, `AccentColor`, `Foreground`, ...) as the palette base.
