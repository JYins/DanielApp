# DanielApp iOS Source Notes

This target is the SwiftUI iOS app for Daniel & Friends. The current product shell is:

`Daily Verse → Connect → Resources → Settings`

## Main App Structure

- `DanielAppApp.swift`: app entry point, Firebase initialization, custom font registration, widget/deep-link handoff.
- `MainTabView.swift`: four-tab shell and app-level tab synchronization.
- `VerseOfTheDayView.swift`: daily verse home, local read/favorite/share actions, manual/automatic verse settings entry.
- `ChurchCommunicationView.swift`: Connect page. Uses `NewsletterViewModel` for announcements/newsletters and keeps messages as a prepared future surface.
- `ChurchResourcesView.swift`: first-phase local seed resource library for hymnbook, church documents, useful links, Bible study, and Bible seminar.
- `SettingsView.swift`: full-page settings for language, update mode, notifications, account, support, and app metadata.

## Services And Data

- `VerseDataService` loads bundled trilingual Bible data and stores selected language/update mode.
- `AuthManager` wraps Firebase Auth and Firestore user profiles/access approval.
- `NewsletterViewModel` reads Firestore `newsletters` and is the live Firebase source for Connect.
- `WordCardViewModel` and `PraiseViewModel` remain available legacy/reusable Firebase services, but they are not first-level Resources dependencies in this phase.
- Widgets use App Group `UserDefaults` through `VerseWidgetSettingsManager` and related widget managers.

## Localization

All new visible strings must support Chinese, English, and Korean. Prefer shared keys in `LocalizedText.swift` for repeated labels; screen-local helpers are acceptable for one-off copy.

## Agent Workflow

Read the repository root `AGENTS.md` before editing. Graphify is installed for this repository; use `graphify query`, `graphify path`, or `graphify explain` before broad code exploration when `graphify-out/graph.json` exists. Run `graphify update .` after code changes to keep the graph current.
