# iOS YouTube blocking — Safari vs Isle WebView

## Problem

`ManagedSettingsStore.webContent.blockedByFilter` (iOS 17+) applies **device-wide**. It blocks **WKWebView inside Isle** as well as Safari — users see **「Website Not Allowed — 'youtube.com' is a restricted website.」**

Apple does **not** provide an API to block Safari by User-Agent while exempting the host app’s WebView.

## What Isle does now

| Mechanism | Safari / YouTube app | Isle WebView |
|-----------|----------------------|--------------|
| `webContent.blockedByFilter` | ~~was used~~ **disabled** | must stay off |
| Screen Time **app** shield (`FamilyActivityPicker`) | blocks YouTube app | no |
| **IsleSafariContentBlocker** extension | blocks listed domains in Safari | no |
| In-app schedule (`YoutubeAccessGuard`) | n/a | overlay during active slots |

On launch, `main.dart` calls `IosScreenTimeService.ensureIsleYoutubeWebViewUnblocked()` to clear legacy OS filters.

## User recovery

1. Rebuild/run latest Isle (auto-clear on boot).
2. YouTube WebView → top bar **「해제」** or **설정 → Isle 핵심 설정 → Isle WebView 막힘 해제**.
3. Reload WebView.

## Setup (recommended)

**설정 → Isle 핵심 설정** — pick YouTube in Screen Time, enable Safari Content Blocker extension, open links in Isle.
