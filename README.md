# Daniel & Friends 🦁

**A daily Bible verse widget for iOS — built with faith, curiosity, and a whole lot of AI-assisted learning.**

<p align="center">
  <img src="screenshots/home_widget.png" width="250" alt="Home Screen Widget" />
  &nbsp;&nbsp;
  <img src="screenshots/lock_screen_widget.png" width="250" alt="Lock Screen Widget" />
  &nbsp;&nbsp;
  <img src="screenshots/verse_of_the_day.png" width="250" alt="Verse of the Day" />
</p>

---

## The Story

It started with Duolingo.

I'd been keeping a daily streak for a while, and one morning it hit me — that little widget on my home screen was genuinely shaping my habits. What if I could have something similar, but instead of a language lesson, it greeted me with a meaningful Bible verse every day?

I attend a Korean church, and our community is a beautiful mix of Chinese, English, and Korean speakers. I wanted something that could serve all of us — not just in one language, but in all three, with a single tap to switch.

So I built **Daniel & Friends**. Named after the Book of Daniel, because Daniel and his friends stayed faithful in a foreign land — and that resonated with me as someone navigating life between cultures.

**Here's the thing: I had zero iOS development experience when I started.** No Swift, no Xcode, no WidgetKit. I learned everything through vibe coding — having conversations with AI chatbots, asking questions, iterating, breaking things, and fixing them. This project is proof that curiosity paired with the right tools can take you surprisingly far.

---

## Features

- **Daily Verse Widget** — A home screen widget (`systemMedium`) that shows a fresh, meaningful Bible verse every day
- **Lock Screen Widget** — Rectangular and circular lock screen widgets so scripture is always just a glance away
- **Trilingual Support** — Full Chinese / English / Korean support with instant language switching
- **Midnight Auto-Refresh** — A custom update system that ensures the verse changes right at midnight (this was the hardest part — more on that below)
- **Curated Verse Collection** — 642 hand-picked meaningful verses, not random noise
- **Church Newsletter** — A community section for sharing church newsletters (Firebase-powered, approval-based)
- **Word Card Gallery** — Browse beautifully hand-drawn word cards created by our church sisters
- **Connect Hub** — Quick links to our church's Instagram and YouTube

<p align="center">
  <img src="screenshots/settings_language.png" width="200" alt="Language Settings" />
  &nbsp;
  <img src="screenshots/word_cards.png" width="200" alt="Word Card Gallery" />
  &nbsp;
  <img src="screenshots/newsletter.png" width="200" alt="Church Newsletter" />
  &nbsp;
  <img src="screenshots/connect.png" width="200" alt="Connect View" />
</p>

---

## Architecture

### How the Daily Verse Engine Works

The verse system is built on two data layers:

```
verses_index.json     →  642 curated verse references (e.g. "Psalm 23:1", "Romans 8:28")
verses_merged.json    →  18,000+ verses with trilingual content {reference, cn, en, kr}
```

Every day, the app computes which verse to show using a deterministic algorithm:

```swift
let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
let index = (dayOfYear - 1) % verseIndices.count
```

This means the same day always yields the same verse — no server needed, fully offline-capable. The widget has its own independent dataset (`widget_verses.json`, ~3,800 verses) with a date-seed algorithm, so it can operate even when the main app hasn't been opened.

### The Midnight Update Challenge

> This was genuinely the hardest technical problem I solved. Apple's WidgetKit documentation does **not** clearly explain how to guarantee a widget refreshes at exactly midnight.

Here's what I discovered through extensive experimentation:

**The problem:** WidgetKit's `TimelineProvider` lets you schedule future entries, but iOS throttles widget updates aggressively. Setting `.after(midnight)` as your reload policy does **not** guarantee your widget refreshes at midnight — the system may delay it by minutes or even hours.

**My solution — a multi-layered update strategy:**

```
┌─────────────────────────────────────────────────┐
│           Midnight Update Architecture          │
├─────────────────────────────────────────────────┤
│                                                 │
│  Layer 1: Timeline Policy                       │
│  └─ .after(nextUpdateDate) set to midnight      │
│     or next background-change time              │
│                                                 │
│  Layer 2: Pre-fetch at 23:50                    │
│  └─ MidnightUpdateManager pre-loads tomorrow's  │
│     verse 10 min early, writes to App Group     │
│     shared UserDefaults, then triggers           │
│     WidgetCenter.shared.reloadAllTimelines()    │
│                                                 │
│  Layer 3: Midnight Timer (0:00)                 │
│  └─ Applies the pre-loaded verse, clears stale  │
│     state, sends local notification, triggers   │
│     another widget reload                       │
│                                                 │
│  Layer 4: Foreground Recovery                   │
│  └─ On app foreground, checks if midnight was   │
│     missed (e.g. app was killed), runs          │
│     checkMissedUpdates() to catch up            │
│                                                 │
│  Layer 5: Widget Self-Healing                   │
│  └─ WidgetLifecycleManager detects stale data   │
│     (>25h since last update, or date mismatch)  │
│     and triggers immediate refresh              │
│                                                 │
└─────────────────────────────────────────────────┘
```

The key insight: **you can't rely on any single mechanism.** The pre-fetch at 23:50, the midnight timer, the foreground recovery check, and the widget's own staleness detection all work together as a safety net. When one layer fails (and they will — iOS is aggressive about killing background tasks), another catches it.

### Trilingual Bible Verse System

Supporting three languages sounds simple until you realize:

1. **Different Bible editions have different verse counts.** Some Korean translations include verses that Chinese translations skip, and vice versa. I built a cross-reference validation system in `VerseModels.swift` that normalizes references across all three languages.

2. **Book names need bidirectional mapping.** "创世记" ↔ "Genesis" ↔ "창세기". The app maintains a complete Old/New Testament book name mapping table that handles Roman numerals, abbreviations, and full names in all three languages.

3. **Font rendering matters.** Chinese, English, and Korean each need their own font family for proper rendering. The app uses:
   - Chinese: 爱点风雅黑长体 (a clean, commercial-free Chinese font)
   - English: System rounded font
   - Korean: GowunDodum (a warm, readable Korean font)

### Firebase Integration & Community Features

The church community features are powered by Firebase:

- **Firebase Auth** — Email/password authentication with an approval workflow (new users are `pending` until a church admin approves them)
- **Firebase Storage** — Hosts word card images and newsletter content organized in folder structures
- **Newsletter System** — Each newsletter has a `config.json` with trilingual captions, publish date, and image references

```
Firebase Storage
├── word_cards/
│   ├── folder_1/
│   │   ├── image1.jpg
│   │   └── image2.jpg
│   └── folder_2/
│       └── ...
└── newsletters/
    ├── 2025-03/
    │   ├── config.json    ← {captions: {cn, en, kr}, publishDate, isPublished}
    │   ├── page1.jpg
    │   └── page2.jpg
    └── ...
```

**What's next:** I'm exploring replacing Firebase Storage with **Notion Integration** (free API) for content management, while keeping Firebase Auth. This would let our church's media team update newsletter content directly from Notion — no code deployment needed.

### Data Flow: App ↔ Widget

The main app and widget extension communicate through **App Group shared UserDefaults**:

```
┌──────────────┐         App Group SharedDefaults         ┌──────────────┐
│   Main App   │ ──── widget_verse_reference ──────────── │    Widget    │
│              │ ──── widget_verse_cn / en / kr ────────── │  Extension   │
│  VerseData   │ ──── widget_verse_timestamp ──────────── │  WidgetData  │
│   Service    │ ──── widget_sync_mode ────────────────── │   Manager    │
│              │ ──── widget_is_fixed ─────────────────── │              │
│              │ ──── selectedLanguage ────────────────── │              │
└──────────────┘                                          └──────────────┘
```

The widget can operate in two modes:
- **Synced mode** — Uses verse data written by the main app
- **Independent mode** — Falls back to its own `widget_verses.json` dataset when the main app hasn't been opened recently

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI Framework | SwiftUI |
| Widget | WidgetKit (Home Screen + Lock Screen) |
| Backend | Firebase Auth + Firebase Storage |
| Data Persistence | App Group UserDefaults + JSON bundles |
| Architecture | Singleton services + ObservableObject ViewModels |
| Fonts | Custom trilingual font loading |
| Design | Hand-drawn UI concepts by our church sisters, implemented with AI assistance |

---

## Project Structure

```
DanielApp/
├── DanielAppApp.swift              # App entry point, Firebase init, midnight manager setup
├── MainTabView.swift               # 5-tab navigation (Verse, Cards, Newsletter, Praise, Connect)
├── VerseOfTheDayView.swift         # Main verse display with switch/pin controls
├── VerseData.swift                 # Core verse data service (load, cache, sync)
├── MidnightUpdateManager.swift     # Multi-layer midnight refresh engine
├── LocalizedText.swift             # All UI strings in CN/EN/KR
├── StyleConstants.swift            # Design system (colors, spacing, typography)
├── AuthManager.swift               # Firebase auth with approval workflow
├── FirebaseStorageService.swift    # Image loading, caching, newsletter fetching
├── SharedModels/
│   ├── VerseModels.swift           # Trilingual verse model + book name mapping
│   └── VerseUtilities.swift        # Cross-language reference utilities
├── verses_index.json               # 642 curated verse references
├── verses_merged.json              # 18K+ trilingual verse database
└── fonts/                          # Chinese + Korean custom fonts

daniel wedget/                       # Widget Extension
├── daniel_wedgetBundle.swift       # Widget bundle entry point
├── WidgetConfiguration.swift       # TimelineProvider + timeline logic
├── WidgetDataManager.swift         # Independent verse calculation
├── WidgetLifecycleManager.swift    # Staleness detection + self-healing
├── MainVerseWidget.swift           # Home screen widget UI
├── LockScreenVerseWidget.swift     # Lock screen widget UI
├── SharedModels.swift              # Lightweight models for widget
└── widget_verses.json              # Independent widget verse dataset
```

---

## Screenshots Needed

> **Note to self:** Replace the placeholder images above with actual screenshots.

Here's what I need to capture:

| Screenshot | Description | Filename |
|-----------|-------------|----------|
| Home Screen Widget | Widget on iPhone home screen showing a verse | `screenshots/home_widget.png` |
| Lock Screen Widget | Lock screen with rectangular verse widget | `screenshots/lock_screen_widget.png` |
| Verse of the Day | Main app verse view with full verse card | `screenshots/verse_of_the_day.png` |
| Language Settings | Settings panel showing CN/EN/KR toggle | `screenshots/settings_language.png` |
| Word Card Gallery | Gallery view of hand-drawn word cards | `screenshots/word_cards.png` |
| Newsletter | Church newsletter view with carousel | `screenshots/newsletter.png` |
| Connect View | Community links page | `screenshots/connect.png` |

---

## What I Learned

This project taught me more than just iOS development:

- **WidgetKit is powerful but opaque.** The documentation doesn't tell you about update throttling, and you'll only discover the edge cases by shipping to a real device and checking at 12:01 AM whether your verse actually changed.
- **Vibe coding is real.** I went from zero Swift knowledge to a fully functional, multi-target Xcode project by having conversations with AI. The key is asking good questions and understanding *why* the code works, not just copying it.
- **Trilingual apps are harder than 3x the work.** Font rendering, text length differences, and Bible version discrepancies made this way more complex than I expected.
- **App Group shared data is fragile.** UserDefaults synchronization between an app and its widget extension has subtle timing issues that took weeks to debug.

---

## Setup

1. Clone the repository
2. Open `DanielApp.xcodeproj` in Xcode
3. Add your own `GoogleService-Info.plist` from [Firebase Console](https://console.firebase.google.com/)
4. Update the App Group identifier if needed (`group.com.daniel.DanielApp`)
5. Build and run on a real device (widgets don't work well in Simulator)

---

## Roadmap

- [ ] Notion Integration for newsletter content management
- [ ] Push notifications for daily verse reminders
- [ ] Verse sharing with beautiful card generation
- [ ] Reading plan / devotional tracker
- [ ] Apple Watch complication

---

## Acknowledgments

- **UI Design** — Hand-drawn by talented sisters in our church, brought to life through AI-assisted implementation
- **Verse Curation** — 642 verses carefully selected for daily encouragement
- **Korean Font** — [GowunDodum](https://fonts.google.com/specimen/Gowun+Dodum) by Yanghee Ryu

---

*Built with love, faith, and an unreasonable amount of midnight debugging.* ✝️
