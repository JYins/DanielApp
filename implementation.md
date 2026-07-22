# Implementation Notes: Daniel App Canada Pilot

## Branch

- Branch: `codex/canada-pilot-v1`
- Purpose: preserve the completed Figma direction, then implement the secure four-church Canada pilot across iOS, Firebase, and the admin portal.
- History: earlier sections document the work completed on `codex/figma-design-merge`; the authoritative Canada-pilot scope and validation are in the dated 2026-07-22 section below.

## Product Goal

The app is moving from a devotional app for "Daniel and his Friends" into a scalable branch-church app. The first-phase navigation is:

`Daily Verse → Connect → Resources → Settings`

## Current Scope

- Keep Daily Verse as the devotional home.
- Rename the church communication tab to Connect.
- Use Connect for announcements, weekly newsletters, and a prepared messages surface.
- Reuse existing Firebase `newsletters` and `AuthManager` for Connect.
- Replace the first-level Resources experience with a church resource directory backed by a Firebase-ready service boundary and local seed fallback.
- Keep Word Cards and Praise code/services available for future reuse, but remove them from the first-level Resources concept.
- Keep all new visible strings trilingual: Chinese, English, and Korean.

## Out Of Scope

- Admin portal redesign or CRUD for the new Resources library.
- Final regional role hierarchy.
- Backend/database cleanup.
- Firestore security rule migration.

## Implementation Decisions

- `MainTabView` stays as the single app shell and uses four tabs: Daily Verse, Connect, Resources, Settings.
- `ChurchCommunicationView` now acts as Connect. It has Announcements, Newsletter, and Messages tabs.
- Connect data source: Announcements and Newsletter both reuse `NewsletterViewModel`, which attaches a Firestore listener to the existing Firebase `newsletters` collection with `published == true` and sorts by `publishDate` descending.
- Announcements: the current `Newsletter` model does not expose a `type` field, so this first phase presents the same published newsletter stream as shorter announcement-style cards with caption, publish date, and source label. If the backend later adds an announcement type or collection, the UI boundary is already separated by `ConnectNewsletterMode.announcement`.
- Newsletter: the same published Firebase newsletter stream is presented as weekly newsletter cards with caption, publish date, image preview, and loading/empty/error/content states.
- Auth: Announcements and Newsletter remain gated by `AuthManager.hasContentAccess()` only. No UID, church id, branch id, or new role hierarchy is hard-coded in this UI phase.
- Messages is a polished coming-soon surface with the product message "Branch and group messages will be available after church access is configured." It deliberately does not connect realtime chat until branch/group access rules are designed in a backend/admin branch.
- `ChurchResourcesView` now depends on `ChurchResourceService` instead of reading a hard-coded seed array directly. The page remains a directory with a header, search, category filters, a featured resource, grid cards, detail pages, loading, empty, and offline fallback states.
- `ChurchResourceService` first exposes local seed data so Resources is usable while Firestore loads, then attempts to read published documents from Firestore `resources`. If Firestore errors, rules deny the query, the collection does not exist, the collection is empty, or decoding returns no resources, the service keeps the page populated from `LocalChurchResourceSeed`.
- Resources are public in this phase. Signed-out users can open the Resources tab, browse local fallback data, search, filter, and view details. The model includes `accessLevel` for future private resources, but this UI branch does not hard-code branch, region, or role authorization.
- Firestore resource schema target: `resources/{resourceId}` with `id: String`, `type: String`, `category: String`, `title: { zh, en, ko }`, `subtitle: { zh, en, ko }`, `description: { zh, en, ko }`, `actionTitle: { zh, en, ko }`, `url: String?`, `content: String?`, `icon: String`, `isPublished: Bool`, `sortOrder: Int`, `updatedAt: Timestamp`, and `createdAt: Timestamp`. The client also accepts optional `accessLevel: String` for later public/private separation.
- `LocalChurchResourceSeed` now uses the same `ChurchResource` model shape as Firestore-backed resources for Hymnbook, Church Documents, Useful Links, Bible Study, and Bible Seminar. Word Cards and Praise remain legacy/reusable areas, not first-level Resources entries.
- Legacy `ConnectView` and `WordCardGalleryView` are retained and marked in comments instead of deleted.
- `.firebase/` is ignored so local Firebase cache/output is not accidentally committed.
- Graphify is installed globally for Codex and project-scoped in this repository. A no-LLM AST/code graph was generated with `graphify update . --no-cluster`.
- Settings now persists language, font size, notifications, and light/dark appearance through shared app preferences.
- Appearance is now a three-state preference: follow system, light, or dark. New installs default to follow system so the app adapts to iOS light/dark mode; older saved `darkModeEnabled` values migrate to the matching explicit light/dark mode.
- The shared design tokens now use adaptive light/dark colors so Daily Verse, Connect, Resources, Settings, and shared controls actually render in the active appearance instead of only changing the system color scheme.
- Settings account actions are connected: signed-out users can open Login/Register, signed-in users get a confirmation before sign-out, pending accounts show their review state, account errors surface in an alert, and Help/FAQ opens a real in-app sheet instead of a dead row.
- Login screen copy used from Settings is now trilingual for Chinese, English, and Korean, and its field surfaces use shared adaptive design colors.
- Manual Bible selection now reads actual books, chapters, and verses from the full `verses_merged.json` dataset instead of hard-coded chapter/verse estimates.
- Automatic daily verse selection remains date-driven from `verses_index.json`; manual references are ignored while automatic mode is active except for same-day temporary verse switches.
- Daily Verse now has local read, favorite, and like state for each verse reference. These states use App Group shared defaults so the app and future widget/shared surfaces can read the same engagement data.
- Daily Verse engagement now uses `VerseEngagementService` as the single local-first source for read, favorite, and like state. The legacy shared-defaults keys remain unchanged:
  - `daniel.readVerseReferences`
  - `daniel.favoriteVerseReferences`
  - `daniel.likedVerseReferences`
- Signed-in engagement sync writes to Firestore at `users/{uid}/verseEngagement/{reference}` with `reference`, `isRead`, `isFavorite`, `isLiked`, `createdAt`, and `updatedAt`. The document id uses the verse reference, with `/` replaced by the full-width slash character only if needed for Firestore path safety; the stored `reference` field remains unchanged.
- Engagement conflict strategy is `updatedAt` based: local data loads first, legacy local states are backfilled with local timestamps, newer remote records replace local records, and newer or missing local records are pushed back to Firebase. Empty remote data triggers a local push instead of clearing local state.
- The home header keeps the globe as the language-cycle control. Connect, Resources, and Settings headers no longer show the extra globe icon; language changes remain available from the home header and Settings language controls.
- The verse user button now shows a clearer signed-in/guest status dot and has localized accessibility labels.
- TestFlight package metadata is now bumped to app/widget version `1.0.2` with build `2`; Settings reads the app version/build from the bundle instead of showing a hard-coded `1.0`.
- Bible manual selection and reader chapter selection now use the English canonical chapter count as the chapter source of truth. This prevents Chinese/Korean `n/a` gaps or language-specific missing rows from truncating books such as Isaiah.
- Daily Verse selection still comes from `verses_index.json`, but the stable index now includes a year-based offset so the same calendar day is less likely to repeat the same verse across years.
- `verses_index.json` was expanded from 641 to 689 valid local references. New references were chosen from encouragement/hope themed topical lists and then verified against the bundled `verses_merged.json`; no external verse text was added.

## Files Changed

- `AGENTS.md`: updated current navigation, Connect/Resources rules, Firebase reuse boundaries, legacy-page policy, and Graphify workflow.
- `README.md`: updated public project direction, feature list, Firebase usage, and project structure.
- `DanielApp/README.md`: replaced stale source notes with current SwiftUI shell/service notes.
- `implementation.md`: this branch record.
- `.gitignore`: ignores `.firebase/`.
- `DanielApp/MainTabView.swift`: fixed tab order/semantics and Connect icon.
- `DanielApp/LocalizedText.swift`: changed `communicationTab` display text to Connect and added shared trilingual Resources UI strings.
- `DanielApp/ChurchCommunicationView.swift`: polished Connect into a first usable church communication center using `NewsletterViewModel`, with header, fixed Announcements/Newsletter/Messages tabs, access gating, announcement cards, weekly newsletter cards, localized empty/error/loading states, and a credible Messages coming-soon state.
- `DanielApp/ChurchResourceService.swift`: added the Firebase-ready resource model, Firestore `resources` fetch boundary, local seed fallback, and migration-shaped `LocalChurchResourceSeed`.
- `DanielApp/ChurchResourcesView.swift`: rebuilt as a service-driven resource directory with filters, search, detail pages, loading/fallback/empty states, and clear external link actions.
- `DanielApp/ConnectView.swift`: marked as legacy.
- `DanielApp/WordCardGalleryView.swift`: marked as legacy.
- `DanielApp/VerseData.swift`: added data-driven Bible book/chapter/verse selection helpers.
- `DanielApp/VerseData.swift`: changed Bible chapter availability to the English canonical chapter count and changed date-based daily selection to the shared stable yearly rotation helper.
- `DanielApp/SharedModels/VerseUtilities.swift`: added the shared stable daily verse index helper used by the app and widget utilities.
- `DanielApp/VerseWidget.swift`: aligned widget fallback/date selection with the shared stable daily verse index helper.
- `DanielApp/verses_index.json`: expanded the automatic daily verse pool and normalized old numeric book names to the app's Roman-numeral reference format.
- `DanielApp.xcodeproj/project.pbxproj`: bumped app/widget marketing version to `1.0.2` and build number to `2`.
- `DanielApp/VerseEngagementService.swift`: added local-first verse engagement storage and Firebase sync.
- `DanielApp/DanielAppApp.swift`: added app-level preferences for font scale, notifications, and color scheme.
- `DanielApp/DanielAppApp.swift`: upgraded appearance preferences from a dark-mode boolean to system/light/dark color scheme selection with legacy preference migration.
- `DanielApp/AuthManager.swift`: added a safe current authenticated user id helper for user-scoped services.
- `DanielApp/VerseOfTheDayView.swift`: added home language cycling, local read/favorite/like verse engagement, Firebase sync handoff, share action, status chips, and user-button polish.
- `DanielApp/SettingsView.swift`: removed the header globe while keeping the language preference row and trilingual language choices.
- `DanielApp/StyleConstants.swift`: added adaptive design colors for system-following light/dark appearance.
- `DanielApp/SettingsView.swift`: connected account actions, login sheet, sign-out confirmation, in-app Help/FAQ sheet, account error alert, pending-account state, and system/light/dark appearance selection.
- `DanielApp/LoginView.swift`: localized the login screen for Chinese, English, and Korean and updated input backgrounds for dark appearance.

## Validation Log

- Passed: XcodeBuildMCP `build_run_sim` for scheme `DanielApp` on iPhone 16 Pro / iOS 18.4. App built, installed, and launched as `com.daniel.DanielApp`.
- Passed: XcodeBuildMCP `build_sim` after Settings/manual verse fixes with no warnings or errors.
- Passed: XcodeBuildMCP `build_run_sim` after Settings/manual verse fixes with no warnings or errors.
- Data check: `verses_merged.json` contains Isaiah chapters 1-66, and Isaiah 41 contains verses 1-29 including Isaiah 41:10.
- Graphify setup: installed `uv` with Homebrew, installed official PyPI package `graphifyy` with `uv tool install graphifyy`, ran `graphify install --platform codex`, ran `graphify install --project --platform codex`, installed Graphify git hooks, and generated `graphify-out/graph.json` with `graphify update . --no-cluster`.
- Graphify query used: `graphify query "How are MainTabView, ChurchCommunicationView, ChurchResourcesView, NewsletterViewModel, AuthManager, and localization connected in this SwiftUI app?" --budget 1800`.
- Passed: XcodeBuildMCP `build_run_sim` after Daily Verse engagement/header polish. App built, installed, and launched successfully as `com.daniel.DanielApp`.
- Passed: `xcodebuild -project DanielApp.xcodeproj -scheme DanielApp -destination id=0904B668-B835-4BD8-929F-BAA0F504C5E7 build` after system/light/dark appearance and Settings account wiring. App built successfully on iPhone 16 Pro / iOS 18.4.
- Passed: repeated `xcodebuild -project DanielApp.xcodeproj -scheme DanielApp -destination id=0904B668-B835-4BD8-929F-BAA0F504C5E7 build` after replacing the support mail placeholder with an in-app Help/FAQ sheet. Build succeeded on iPhone 16 Pro / iOS 18.4.
- UI check: homepage screenshot confirmed the globe remains only in the home header, and the verse card renders read, favorite, like, and share actions without visible overlap on iPhone 16 Pro.
- Accessibility check: XcodeBuildMCP runtime snapshot confirmed localized targets for Mark as Read, Save/Favorite Verse, Like Verse, Share Verse, and the home language switch.
- Interaction check: tapped favorite and like in the simulator. The verse card updated immediately to show the localized `已收藏` and `已点赞` status chips, and the buttons changed to cancel states.

- Passed: XcodeBuildMCP `build_run_sim` after `VerseEngagementService`. App built, installed, and launched successfully as `com.daniel.DanielApp` on iPhone 17 / iOS 26.3. Build diagnostics showed only pre-existing warnings in unrelated files.
- Passed: unauthenticated Simulator interaction for Daily Verse engagement. Tapped favorite, like, and mark-read while signed out; the card immediately showed `已收藏`, `已点赞`, and `已读` status chips and the controls changed to cancel/read states without login errors or a crash.
- Not verified: signed-in Firebase engagement sync. The simulator session did not include a test account or confirmed writable Firestore environment. The implemented path is `users/{uid}/verseEngagement/{reference}`, and unauthenticated use remains local-only.
- Passed: XcodeBuildMCP `build_run_sim` after Connect polish on iPhone 17 / iOS 26.3. App built, installed, and launched successfully as `com.daniel.DanielApp`. Build diagnostics had no errors; remaining warnings are pre-existing `MainTabView` `onChange(of:perform:)` deprecation warnings.
- Passed: Simulator UI snapshot opened the Connect bottom tab successfully while signed out. The header showed Connect copy with no top globe, retained the user/login button, and displayed fixed Announcements, Newsletter, and Messages tabs.
- Passed: Signed-out Announcements and Newsletter states showed localized access explanations and a login entry through the existing `AuthManager.hasContentAccess()` gate without crashing.
- Passed: Simulator interaction opened Messages and displayed the first-phase coming-soon state: branch/group messages are delayed until church access is configured, with no realtime chat dependency.
- Partially verified: Firebase empty state cannot be triggered from the signed-out simulator because content is gated before `NewsletterViewModel` loads. The signed-in content path renders `ConnectEmptyCard` when `viewModel.newsletters` is empty, but a signed-in no-data Firebase account was not available in this session.
- Graphify query used before Resources service work: `graphify query "How are ChurchResourcesView, resource seed models, Firebase services, AuthManager, MainTabView, and localization connected?"`.
- Confirmed before editing: Resources was documented as a local seed church resource library, with Firestore resource collections/admin CRUD out of scope at that time.
- Passed: XcodeBuildMCP `build_run_sim` after adding `ChurchResourceService` and the service-driven Resources view on iPhone 17 / iOS 26.3. App built, installed, and launched successfully as `com.daniel.DanielApp`. Diagnostics had no errors; remaining warnings are pre-existing `onChange(of:perform:)` deprecation warnings in `NewsletterView.swift`, `MainTabView.swift`, and `PraiseView.swift`.
- Passed: signed-out Simulator UI opened Resources without an auth gate. Because Firestore `resources` was unavailable or empty, the page displayed the localized local fallback banner and retained the Hymnbook, Church Documents, Useful Links, Bible Study, and Bible Seminar directory.
- Passed: Resources category filtering by Useful Links narrowed the grid without crashing.
- Passed: Resources search with `seminar` inside the Useful Links category showed the localized no-results state. Chinese keyboard input could not be injected by the automation tool because AXe typing only supports US keyboard characters.
- Passed: Resource detail navigation opened the Useful Links detail page, and tapping the external link button successfully handed off to Safari/YouTube without crashing.
- Passed: `graphify update . --no-cluster` after code changes. The sandboxed attempt failed with `Operation not permitted`, then the approved escalated run rebuilt `graphify-out/graph.json` with 1465 nodes and 25674 edges.

### Version, Bible Picker, and Daily Verse Pool: 2026-06-09

- Graphify discovery used before coding: `graphify query "Where are iOS app version/build settings, Bible chapter/verse picker logic, Bible JSON loading, and daily verse selection data/services implemented?"`. The query was not sufficiently scoped, so ordinary code search located `project.pbxproj`, `SettingsView`, `BibleReaderView`, `VerseData`, `VerseUtilities`, `VerseWidget`, and `verses_index.json`.
- Web research source for new daily references: OpenBible topical lists for encouragement and hope. Only references were used; verse text remains sourced from the bundled local JSON.
- Passed: local JSON validation confirmed `verses_index.json` has 689 references, all 689 exist in `verses_merged.json`, Isaiah has 66 chapters, and `Isaiah 41:10` exists.
- Passed: XcodeBuildMCP `build_sim` for scheme `DanielApp` on iPhone 16 Pro / iOS 18.4 after the version, picker, and daily verse changes. Build succeeded with no warnings or errors.
- Passed: `graphify update . --force` after the normal sandboxed attempt failed with `Operation not permitted` and the escalated non-force run refused to overwrite a smaller rebuilt graph. The forced local graph update rebuilt `graphify-out` with 1960 nodes, 3373 edges, and 112 communities.

## Follow-Up Work

- Add an LLM API key such as `GEMINI_API_KEY` or `GOOGLE_API_KEY` if full semantic Graphify extraction is desired; current graph is AST/code-only.
- Decide whether Connect Announcements and Newsletter should split into separate Firestore collections.
- Build admin-web CRUD for the Firestore `resources` collection, including trilingual field editing, publishing, sort order, icon selection, URL/content validation, and future `accessLevel` management.
- Add Firestore security rules for `resources` so public published resources are readable by signed-out users while private/unpublished resources remain protected for future admin/member workflows.
- Decide whether Word Cards and Praise become Resources subitems again or remain separate legacy modules.
- Add branch/region role models in a separate backend-focused branch.
- Add Firestore security rules for `users/{uid}/verseEngagement/{reference}` in a backend-focused branch so each member can only read/write their own engagement records.

## Firebase Dev/Test Environment Update

### Firebase Configuration Check

- `GoogleService-Info.plist` exists locally and the app bundle id matches `com.daniel.DanielApp`.
- `FirebaseApp.configure()` is called from `DanielApp/DanielAppApp.swift`.
- Firebase Auth, Firestore, Storage, and Analytics are already linked in the Xcode project through Swift Package Manager.
- `GoogleService-Info.plist` remains ignored. No real Firebase secret was added by this work.
- `GoogleService-Info.example.plist` remains the setup reference for developers who need to supply their own local Firebase config.

### Emulator Configuration

- Added/updated `firebase.json` for local Auth and Firestore emulators on `127.0.0.1:9099` and `127.0.0.1:8080`, with Emulator UI on `127.0.0.1:4000`.
- Added `firestore.rules` coverage for:
  - owner-only `users/{uid}/verseEngagement/{reference}` read/write/delete,
  - public reads for published `resources`,
  - protected `newsletters` reads through the current approved-user/admin model,
  - admin-only resource/newsletter writes.
- Added `firestore.indexes.json` resource index for `isPublished + sortOrder`.
- Added repeatable scripts:
  - `scripts/firebase-emulator-start.sh`
  - `scripts/firebase-seed-test-data.js`
  - `scripts/run-ios-tests.sh`
- Seed data includes approved/member/admin emulator Auth users, user profiles, one engagement document, one newsletter, and two published resources. The seed script refuses to run unless emulator host variables are set.

### Service/Test Architecture

- `VerseEngagementService` now supports injected remote store, current user id provider, and `UserDefaults`, keeping read/favorite/like local-first and syncing to `users/{uid}/verseEngagement/{reference}` when signed in.
- `ChurchResourceService` now supports injected remote store and local seed fallback, and exposes reusable search/category filtering.
- `NewsletterViewModel` now has a small remote-store boundary and an explicit `NewsletterLoadState` for loading, empty, permission denied, error, and content states.
- SwiftUI views continue to consume service/view-model state instead of directly operating on Firestore.

### Validation Log: 2026-06-05

- Passed: `firebase emulators:start --only firestore,auth` through `scripts/firebase-emulator-start.sh`; Auth, Firestore, and Emulator UI started on the configured local ports.
- Passed: emulator seed script with explicit local emulator env vars. Data seeded into the local Firebase project id from `GoogleService-Info.plist`.
- Passed: `scripts/run-ios-tests.sh` on iPhone 16 Pro / iOS 18.4. Result: 16 tests passed, 0 failed.
- Unit tests passed:
  - `VerseEngagementServiceTests`: signed-out local writes, signed-in remote push, remote-newer merge, local-newer merge, empty remote preserving local state.
  - `ChurchResourceServiceTests`: Firebase success, Firebase failure fallback, empty collection fallback, search, category filtering.
  - `NewsletterViewModelTests`: expressive loading/empty/error/content states and permission-denied behavior.
- Emulator integration tests passed:
  - engagement write/read round trip,
  - newsletter seed read through `NewsletterViewModel`,
  - resource seed read through `ChurchResourceService`,
  - Firestore rules for own engagement writes, denying other-user engagement writes, published resources, and protected newsletters.
- Passed: XcodeBuildMCP `build_run_sim` with `-UseFirebaseEmulator`; app built, installed, and launched as `com.daniel.DanielApp`.
- Simulator smoke passed:
  - Daily Verse opened and displayed the current verse.
  - Read/favorite/like buttons were tappable; read state changed immediately to `Read`.
  - Home globe switched Chinese UI to English.
  - Connect opened without crashing, showed Announcements/Newsletter/Messages, and Messages displayed the coming-soon state.
  - Resources opened without crashing, read emulator seed resources, accepted search text, showed category controls, and opened a resource detail page.
  - Settings opened as a full page, showed language and automatic/manual update controls, and returning to Daily Verse still displayed the verse.
  - Connect, Resources, and Settings headers did not expose the home globe control.
- Partial UI note: the Resources featured card remains visible while search/category filters are active; the list/detail path works, but the featured section can be refined later if product wants search/filter to affect every visible resource card.
- Not completed: `graphify update . --no-cluster` after this Firebase test pass. The sandboxed run failed with `Operation not permitted`; the required escalated rerun was blocked by the current Codex approval/usage limit, so the existing graph may lag behind these latest test and Firebase setup edits.

### Production Firebase Deployment: 2026-06-05

- Confirmed Firebase CLI reauth for `jeremyyin1225@gmail.com`.
- Confirmed production project `daniel1-ca1e7` is selected and has iOS app `Danieapp`.
- Confirmed Firestore database `projects/daniel1-ca1e7/databases/(default)` exists.
- With explicit user approval, deployed only Firestore rules and indexes:
  - `firebase deploy --only firestore:rules,firestore:indexes --project daniel1-ca1e7`
- Deployment result: `firestore.rules` compiled successfully, rules were released to `cloud.firestore`, and indexes from `firestore.indexes.json` deployed successfully for the default database.
- Post-deploy verification:
  - `firebase firestore:databases:list --project daniel1-ca1e7` returned the default database.
  - `firebase firestore:indexes --project daniel1-ca1e7` returned the expected `newsletters`, `resources`, and `wordCards` composite indexes.
- No production seed data was written.

### Production Feature Connection: 2026-06-05

- Production Firestore status before resource initialization:
  - `resources`: 0 documents.
  - `newsletters`: existing production documents available for Connect.
  - `users`: existing production profiles available for `AuthManager` and content access checks.
- Added `scripts/firebase-seed-production-resources.js`:
  - defaults to dry-run,
  - refuses to run when emulator env vars are set,
  - requires `--confirm-production-resources` for production writes,
  - uses Firebase CLI login state instead of committing service account credentials.
- With explicit user approval, upserted the first-phase production `resources` documents into project `daniel1-ca1e7`:
  - `hymnbook`
  - `church-documents`
  - `useful-links`
  - `bible-study`
  - `bible-seminar`
- Post-write status from the production connection script:
  - `resources`: 5 documents.
  - `newsletters`: 4 documents.
  - `users`: 5 documents.
- Verified the app query shape against production Firestore REST:
  - `resources` where `isPublished == true`, ordered by `sortOrder`, returned all 5 resource documents in the expected order.
- Production service connection status:
  - Daily Verse engagement: rules and client service path are live; documents are created under each signed-in user at interaction time.
  - Connect: `NewsletterViewModel` can use the existing `newsletters` collection; production already has content.
  - Resources: `ChurchResourceService` can now use production `resources` instead of falling back to local seed.

### Remaining Work

- Keep production `GoogleService-Info.plist` local and uncommitted.
- Admin CRUD for `resources` is not built in this branch.
- Final branch/region authorization and private resources are still future backend/admin work.
- UI automation does not assert favorite/like selected-state text because the current accessibility snapshot exposes the button labels but not a stable selected-state label for those two icons.

## Firebase Login And Branch-Church System Update: 2026-06-06

### Scope

- Designed a normalized Firebase branch-church model without removing the legacy profile fields currently used by the iOS app and admin dashboard.
- Kept `users/{uid}.role == "admin"` compatible for existing admin accounts and introduced `accessRole` for scoped authorization:
  - `global_admin`
  - `region_admin`
  - `branch_admin`
  - `member`
- Added branch assignment fields to iOS `UserProfile` parsing and registration defaults:
  - `orgId`
  - `regionId`, `regionName`
  - `branchId`, `branchName`
  - `role`, `accessRole`
  - `membershipStatus`
- Updated admin-web so user approval also sets `membershipStatus`, admin checks recognize `global_admin`, and expanded user rows can assign a branch and scoped access role.
- Updated admin-web auth/navigation so approved `global_admin`, `region_admin`, and `branch_admin` users can enter the admin dashboard with scoped navigation. Global-only content management pages remain hidden and route-guarded for non-global admins.
- Added admin-web `Branches` page so global admins can manage Firebase-backed regions and local branches with trilingual names, active state, sort order, country/city/timezone, and branch-region mapping.
- Updated admin-web `Users` actions so approval/revoke, role changes, and branch assignment write `users/{uid}` and `branchMemberships/{branchId}_{uid}` together through a Firestore batch. Moving a user to a new branch marks the previous membership as `revoked`.
- Added callable Cloud Function `setUserAccessAdmin` so user approval, scoped role changes, branch assignment, `branchMemberships`, and Firebase Auth custom claims are maintained by a server-side admin boundary. The admin web prefers this callable and falls back to client batch writes only when the function is not deployed yet.
- Expanded `setUserAccessAdmin` so delegated changes are enforced server-side: global admins can manage all users, region admins can manage users in their own region and assign `member` or `branch_admin`, and branch admins can approve/revoke only member users in their own branch. Scoped admins cannot change themselves, manage higher admins, move users outside scope, or grant global/region roles.
- Updated iOS registration so new users can select an active Firebase-backed `branches` document through `RegistrationBranchViewModel` and an injectable `RegistrationBranchRemoteStore`, keeping Firestore access outside the SwiftUI view. The selected branch writes normalized `orgId`, `regionId`, `branchId`, `regionName`, and `branchName` fields while preserving legacy `churchCountry/churchName`; manual church entry remains available when branches cannot be loaded.
- Updated Settings so signed-in and pending users can see their Firebase-backed branch, region, scoped access role, and membership review status as read-only profile information. Admins still maintain these fields through Firebase/admin tooling.
- Updated Cloud Functions admin checks so existing `admin` and new `global_admin` callers can use admin-only deletion paths.

### Firestore Collections

The proposed production schema is:

```
organizations/{orgId}
regions/{regionId}
branches/{branchId}
branchMemberships/{branchId}_{uid}
users/{uid}
```

`users/{uid}` remains the app’s login/profile source of truth. `branchMemberships` is the normalized lookup collection for future scoped admin pages and branch-specific content filtering.

### Rules And Indexes

- `firestore.rules` now includes helper functions for:
  - legacy/global admin checks,
  - approved member checks,
  - region admin reads,
  - branch admin reads,
  - owner-only verse engagement.
- `organizations`, `regions`, and active `branches` can be read for app/admin setup; writes remain global-admin only. Public branch reads must query `isActive == true`; admin/protected reads are evaluated first so admin list pages can still inspect inactive rows.
- `branchMemberships` can be read by the member, global admins, and matching region/branch admins; writes remain global-admin only until emulator tests cover more delegated mutation paths.
- Added structure validation for `organizations`, `regions`, `branches`, and `branchMemberships`; delete operations remain global-admin only and no longer run create/update validation against a missing `request.resource`.
- `firestore.indexes.json` adds composite indexes for active branch registration lookup, region/branch listing, and membership queries by `userId`, `branchId`, `regionId`, `status`, and `accessRole`.

### Production Initialization Script

Added `scripts/firebase-bootstrap-global-admin.js` and `scripts/firebase-seed-branch-system.js`.

`scripts/firebase-bootstrap-global-admin.js`:

- Defaults to dry-run.
- Supports `--check` to list existing Firestore global admin candidates.
- Supports `--email` or `--uid` to select an existing Firebase Auth/Firestore user profile.
- Requires `--confirm-global-admin` before production writes.
- Refuses to run if `FIRESTORE_EMULATOR_HOST` or `FIREBASE_AUTH_EMULATOR_HOST` is set.
- Upserts the Daniel organization, a safe region/branch membership for the target admin, patches `users/{uid}`, and writes Firebase Auth custom claims.
- Preserves existing Auth custom claims unless they conflict with the required Daniel admin claims.

`scripts/firebase-seed-branch-system.js`:

- Defaults to dry-run.
- Requires `--confirm-branch-system` before production writes.
- Refuses to run if `FIRESTORE_EMULATOR_HOST` or `FIREBASE_AUTH_EMULATOR_HOST` is set.
- Uses Firebase CLI login state and refreshes the access token through firebase-tools.
- Patches user docs through Firestore `updateMask` so existing profile fields are not overwritten.
- Upserts organization, region, branch, and branch membership documents.

Added `scripts/firebase-cli-auth.js` so production scripts can load Firebase CLI auth from local/global module resolution or common Homebrew install paths instead of relying on a single hard-coded path.

Dry-run result against production project `daniel1-ca1e7`:

```
Users scanned: 5
Regions to upsert: 2
Branches to upsert: 2
Membership documents to upsert: 5
User profile documents to patch: 5
```

The dry-run preserved the existing production text values, including one region value currently stored as `加` and one branch fallback generated from missing/blank branch data.

Global admin bootstrap dry-run result against production project `daniel1-ca1e7`:

```
Global admin candidates: 1
lUW8SfY4sZXg3oaCO7WV5T7GX2m2 | admin@daniel.com | approved=true | role=admin | accessRole=(none)
```

The dry-run for `admin@daniel.com` confirmed that the Auth user exists and would set `accessRole: "global_admin"`, `membershipStatus: "active"`, `isApproved: true`, Auth custom claims, and a safe `unassigned-region/unassigned-branch` membership until the production branch seed assigns more complete branch data.

### Validation Log: 2026-06-06

- Ran `git status --short` before work.
- Ran Graphify query for the AuthManager/admin/rules/branch relationships. Graphify returned limited scoped results, so source search was used for detailed implementation discovery.
- Re-read `AGENTS.md` and `implementation.md` before edits.
- Verified Firebase CLI project access with `firebase projects:list`.
- Ran production branch seed dry-run:
  - `node scripts/firebase-seed-branch-system.js --project daniel1-ca1e7`
  - Result: dry-run only, no production writes.
- Passed script syntax checks:
  - `node --check scripts/firebase-seed-branch-system.js`
  - `node --check scripts/firebase-seed-production-resources.js`
- Added first global admin bootstrap script and Firebase CLI auth helper:
  - `scripts/firebase-bootstrap-global-admin.js`
  - `scripts/firebase-cli-auth.js`
- Passed bootstrap/helper syntax and help checks:
  - `node --check scripts/firebase-cli-auth.js`
  - `node --check scripts/firebase-bootstrap-global-admin.js`
  - `node --check scripts/firebase-seed-branch-system.js`
  - `node --check scripts/firebase-seed-production-resources.js`
  - `node scripts/firebase-bootstrap-global-admin.js --help`
- Production read-only bootstrap checks:
  - `node scripts/firebase-bootstrap-global-admin.js --project daniel1-ca1e7 --check`
  - Result: found one existing global admin candidate, `admin@daniel.com`, with legacy `role=admin`.
  - `node scripts/firebase-bootstrap-global-admin.js --project daniel1-ca1e7 --email admin@daniel.com`
  - Result: dry-run only, confirmed matching Firebase Auth user and printed planned Firestore/Auth custom claim updates. No production writes were made.
- Passed: `graphify update . --no-cluster` after adding the bootstrap script and docs. The sandboxed run failed with `Operation not permitted`, then the approved escalated run rebuilt `graphify-out/graph.json`; the final rerun reported 1872 nodes and 33138 edges.
- Passed expanded emulator seed script syntax check:
  - `node --check scripts/firebase-seed-test-data.js`
- Passed admin-web production build:
  - `npm run build` in `admin-web`
- Passed emulator-backed iOS tests:
  - `firebase emulators:exec --only firestore,auth "FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 GCLOUD_PROJECT=daniel1-ca1e7 node scripts/firebase-seed-test-data.js && scripts/run-ios-tests.sh" --project daniel1-ca1e7`
  - Result: `** TEST SUCCEEDED **`, 16 tests passed.
- After adding branch/region tests and admin Branches UI, reran:
  - `node --check scripts/firebase-seed-test-data.js`
  - `npm run build` in `admin-web`
  - `firebase emulators:exec --only firestore,auth "FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 GCLOUD_PROJECT=daniel1-ca1e7 node scripts/firebase-seed-test-data.js && scripts/run-ios-tests.sh" --project daniel1-ca1e7`
  - Result: `** TEST SUCCEEDED **`, 18 tests passed.
  - New passing tests:
    - `testBranchAndRegionScopedRules`
    - `testOnlyGlobalAdminCanWriteBranchStructure`
- After wiring `Users` admin actions to synchronize `branchMemberships`, reran:
  - `npm run build` in `admin-web`
  - `firebase emulators:exec --only firestore,auth "FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 GCLOUD_PROJECT=daniel1-ca1e7 node scripts/firebase-seed-test-data.js && scripts/run-ios-tests.sh" --project daniel1-ca1e7`
  - Result: `** TEST SUCCEEDED **`, 19 tests passed.
  - New passing test:
    - `testOnlyGlobalAdminCanAssignUserBranchAndMembership`
- Added `scripts/firebase-test-callable-admin.js` for Functions emulator validation of `setUserAccessAdmin`.
- Passed Functions/admin validation:
  - `npm run build` in `functions`
  - `node --check scripts/firebase-test-callable-admin.js`
  - `npm run build` in `admin-web`
  - `firebase emulators:exec --only firestore,auth,functions "FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 FUNCTIONS_EMULATOR_HOST=127.0.0.1:5001 GCLOUD_PROJECT=daniel1-ca1e7 node scripts/firebase-seed-test-data.js && FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 FUNCTIONS_EMULATOR_HOST=127.0.0.1:5001 GCLOUD_PROJECT=daniel1-ca1e7 node scripts/firebase-test-callable-admin.js" --project daniel1-ca1e7`
  - Result: callable updated user profile, upserted membership, and custom claims in the emulator.
- After adding scoped region-admin and branch-admin enforcement to the callable and admin-web dashboard:
  - Passed: `npm run build` in `functions`.
  - Passed: `npm run build` in `admin-web`.
  - Passed: `node --check scripts/firebase-seed-test-data.js`.
  - Passed: `node --check scripts/firebase-test-callable-admin.js`.
  - Passed: Functions emulator scoped-admin validation:
    - `firebase emulators:exec --only firestore,auth,functions "FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 FUNCTIONS_EMULATOR_HOST=127.0.0.1:5001 GCLOUD_PROJECT=daniel1-ca1e7 node scripts/firebase-seed-test-data.js && FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 FUNCTIONS_EMULATOR_HOST=127.0.0.1:5001 GCLOUD_PROJECT=daniel1-ca1e7 node scripts/firebase-test-callable-admin.js" --project daniel1-ca1e7`
    - Result: global admin branch assignment passed, branch admin same-branch member approval passed, branch admin cross-branch/escalation attempts were rejected, region admin same-region branch-admin assignment passed, and region admin outside-region/global-admin escalation attempts were rejected.
  - Passed: full emulator-backed iOS tests after the new scoped admin seed:
    - `firebase emulators:exec --only firestore,auth "FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 GCLOUD_PROJECT=daniel1-ca1e7 node scripts/firebase-seed-test-data.js && scripts/run-ios-tests.sh" --project daniel1-ca1e7`
    - Result: `** TEST SUCCEEDED **`, 26 tests passed, 0 failed.
  - Passed: `graphify update . --no-cluster` after the scoped admin changes. The sandboxed run failed with `Operation not permitted`, then the approved escalated run rebuilt `graphify-out/graph.json` with 1838 nodes and 26098 edges.
- After the callable/admin-web update, reran emulator-backed iOS tests:
  - `firebase emulators:exec --only firestore,auth "FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 GCLOUD_PROJECT=daniel1-ca1e7 node scripts/firebase-seed-test-data.js && scripts/run-ios-tests.sh" --project daniel1-ca1e7`
  - Result: `** TEST SUCCEEDED **`, 19 tests passed.
- After adding the Firebase-backed branch picker to iOS registration:
  - Passed: `npm run build` in `functions`.
  - Passed: `npm run build` in `admin-web`.
  - Passed: `node --check scripts/firebase-test-callable-admin.js`.
  - Passed: XcodeBuildMCP `build_run_sim` with `-UseFirebaseEmulator`; app built, installed, and launched as `com.daniel.DanielApp`.
- After moving registration branch loading behind `RegistrationBranchViewModel` and `RegistrationBranchRemoteStore`:
  - Passed: XcodeBuildMCP `build_run_sim` with `-UseFirebaseEmulator`; app built, installed, and launched as `com.daniel.DanielApp`.
  - Passed: XcodeBuildMCP `test_sim`; result was 15 passed, 0 failed, 8 skipped because the Firebase emulator was not running in that runner.
  - First full emulator-backed rerun caught a real rules/query issue: public branch list reads failed because the client queried only `order(by: "sortOrder")` while rules required active branches. The fix changed the client to query `isActive == true` and added the matching `branches(isActive, sortOrder)` index while guarding active reads in `firestore.rules`.
  - Passed: full emulator-backed iOS tests with Auth and Firestore emulators:
    - `firebase emulators:exec --only firestore,auth "FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 GCLOUD_PROJECT=daniel1-ca1e7 node scripts/firebase-seed-test-data.js && scripts/run-ios-tests.sh" --project daniel1-ca1e7`
    - Result: `** TEST SUCCEEDED **`, 23 tests passed, 0 failed.
    - New passing tests:
      - `RegistrationBranchServiceTests.testLoadsActiveBranchesFromInjectedStore`
      - `RegistrationBranchServiceTests.testFailureExposesErrorWithoutCrashing`
      - `RegistrationBranchServiceTests.testLoadBranchesOnlyRunsOnce`
      - `FirebaseEmulatorIntegrationTests.testRegistrationBranchStoreReadsSeededBranches`
  - Passed: `graphify update . --no-cluster` after code changes. The sandboxed run failed with `Operation not permitted`, then the approved escalated run rebuilt `graphify-out/graph.json` with 1812 nodes and 19196 edges.
- After adding Settings branch/access profile display:
  - Passed: XcodeBuildMCP `build_run_sim` with `-UseFirebaseEmulator`; app built, installed, and launched as `com.daniel.DanielApp`.
  - Passed: XcodeBuildMCP `test_sim`; result was 18 passed, 0 failed, 8 skipped because the Firebase emulator was not running in that runner.
  - Passed: full emulator-backed iOS tests with Auth and Firestore emulators:
    - `firebase emulators:exec --only firestore,auth "FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 GCLOUD_PROJECT=daniel1-ca1e7 node scripts/firebase-seed-test-data.js && scripts/run-ios-tests.sh" --project daniel1-ca1e7`
    - Result: `** TEST SUCCEEDED **`, 26 tests passed, 0 failed.
    - New passing tests:
      - `UserProfileAccessDisplayTests.testDisplaysBranchRegionRoleAndStatus`
      - `UserProfileAccessDisplayTests.testFallsBackToLegacyChurchFieldsAndPendingStatus`
      - `UserProfileAccessDisplayTests.testMissingBranchAndRegionAreLocalized`
  - Passed: `graphify update . --no-cluster` after Settings profile display changes. The sandboxed run failed with `Operation not permitted`, then the approved escalated run rebuilt `graphify-out/graph.json` with 1827 nodes and 22631 edges.
- Passed XcodeBuildMCP simulator build/run:
  - project: `DanielApp.xcodeproj`
  - scheme: `DanielApp`
  - simulator: `iPhone 16 Pro`
  - result: build, install, and launch succeeded for `com.daniel.DanielApp`.
- Attempted production deploy of the new branch/login rules and indexes, but the Codex approval reviewer blocked it because this specific new production rules/index deployment requires explicit user approval after surfacing the risk.

### Production Branch/Login Deployment: 2026-06-07

With explicit user approval, production branch/login setup was completed for Firebase project `daniel1-ca1e7`.

- Ran:
  - `node scripts/firebase-bootstrap-global-admin.js --project daniel1-ca1e7 --email admin@daniel.com --confirm-global-admin`
  - Result: `admin@daniel.com` / `lUW8SfY4sZXg3oaCO7WV5T7GX2m2` now has Firestore profile fields and Firebase Auth custom claims for `accessRole: "global_admin"`, `role: "admin"`, `orgId: "daniel-branch-church"`, `regionId: "unassigned-region"`, `branchId: "unassigned-region-unassigned-branch"`, `membershipStatus: "active"`, and `isApproved: true`.
- Ran:
  - `firebase deploy --only firestore:rules,firestore:indexes,functions --project daniel1-ca1e7`
  - Result: production Firestore rules/indexes deployed, `setUserAccessAdmin` created, and `ping` / `deleteUserAdmin` updated.
  - Deployment warnings: Node.js 20 runtime is deprecated after 2026-04-30 and will be decommissioned on 2026-10-30; `firebase-functions` SDK 4.9.0 is outdated and should be upgraded in a follow-up.
- Cleaned unused Firestore rules helpers that caused deploy warnings, then reran:
  - `firebase deploy --only firestore:rules --project daniel1-ca1e7`
  - Result: production `firestore.rules` compiled and deployed cleanly.
- Ran:
  - `node scripts/firebase-seed-branch-system.js --project daniel1-ca1e7 --confirm-branch-system`
  - Result: production branch seed completed.
  - Final production counts: `organizations: 1`, `regions: 2`, `branches: 2`, `branchMemberships: 5`, `users: 5`.
- Verified production state:
  - `node scripts/firebase-seed-branch-system.js --project daniel1-ca1e7 --check`
  - `node scripts/firebase-bootstrap-global-admin.js --project daniel1-ca1e7 --email admin@daniel.com`
  - `firebase functions:list --project daniel1-ca1e7`
  - Result: `setUserAccessAdmin`, `deleteUserAdmin`, and `ping` are callable functions in `us-central1`; `admin@daniel.com` Auth custom claims include `accessRole: "global_admin"`.
- Local emulator validation after production deploy:
  - Passed: callable scoped admin test with Auth, Firestore, and Functions emulators.
  - Passed: full emulator-backed iOS tests with Auth and Firestore emulators. Result: `** TEST SUCCEEDED **`, 26 tests passed, 0 failed.
- Passed: `graphify update . --no-cluster` after production deployment notes and Product Design documentation. The sandboxed run failed with `Operation not permitted`, then the approved escalated run rebuilt `graphify-out/graph.json` with 1893 nodes and 36678 edges.

### Product Design: Connect And Resources Next Phases

- Added `firebase-product-design.md` using the Product Design workflow brief from the user request.
- The design confirms Firebase can support:
  - realtime Connect posts, comments, and reactions through Firestore listeners,
  - scoped branch/region/global visibility with the existing Auth/custom-claim model,
  - PDF hymnbooks and documents through Firebase Storage plus Firestore metadata,
  - a native Bible reader backed by local Bible JSON for public reading,
  - shared cloud favorites, notes, and reading progress under `users/{uid}`,
  - local guest favorites that can sync after login, while notes require login.
- Proposed next implementation phases:
  - unified `FavoriteService` / `NoteService`,
  - Bible Reader under Resources,
  - PDFKit Hymnbook reader,
  - Connect realtime community posts/comments/reactions.

### Unified Favorites And Bible Reader: 2026-06-07

- Implemented the first Product Design slice for shared Daily Verse and Resources favorites.
- Added `FavoriteService` with dependency-injected remote favorite store, remote note store, current uid provider, and `UserDefaults`.
- Added local-first guest favorites with signed-in Firestore sync to `users/{uid}/favorites/{favoriteId}`.
- Added login-required notes at `users/{uid}/notes/{noteId}`. Signed-out users can still read Bible/resource content and save local favorites.
- Added owner-only Firestore rules for:
  - `users/{uid}/favorites/{favoriteId}`
  - `users/{uid}/notes/{noteId}`
  - `users/{uid}/readingProgress/{targetId}`
- Added native SwiftUI `BibleReaderView` under Resources, backed by bundled Bible JSON through `VerseDataService`.
- Added `FavoritesView`, reachable from Resources and Settings, grouped by saved date.
- Updated `ModernVerseCard` so the primary Daily Verse action is the shared Favorite/Note model; legacy read/like engagement remains in `VerseEngagementService` for compatibility and existing tests.
- Updated Firestore rules and emulator integration tests for favorites, notes, and reading progress.
- Production note: these new favorites/notes/readingProgress rules were validated locally only. They were not deployed to production Firebase in this phase.

Validation:

- Passed: XcodeBuildMCP `test_sim` without emulator. Result: 21 passed, 0 failed, 9 skipped because emulator-only tests were intentionally skipped in that runner.
- Passed: full emulator-backed iOS tests with Auth and Firestore emulators:
  - `firebase emulators:exec --only firestore,auth "FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 GCLOUD_PROJECT=daniel1-ca1e7 node scripts/firebase-seed-test-data.js && scripts/run-ios-tests.sh" --project daniel1-ca1e7`
  - Result: `** TEST SUCCEEDED **`, 30 tests passed, 0 failed.
  - New passing tests:
    - `FavoriteServiceTests.testGuestFavoriteWritesLocalOnly`
    - `FavoriteServiceTests.testSignedInFavoritePushesRemote`
    - `FavoriteServiceTests.testSignedInNotePushesRemoteAndGuestNoteIsRejected`
    - `FirebaseEmulatorIntegrationTests.testFirestoreRulesForFavoritesNotesAndReadingProgress`
- Passed: XcodeBuildMCP `build_run_sim`; app built, installed, and launched successfully as `com.daniel.DanielApp`.

### Remaining Work

- Upgrade Cloud Functions from Node.js 20 before its 2026-10-30 decommission date and update `firebase-functions` from 4.9.0 in a focused follow-up.
- Continue the new Product Design plan with PDFKit Hymnbook reading, Connect realtime posts/comments/reactions, and richer reading progress behavior.
- Direct client Firestore delegated writes remain intentionally closed by rules. Region/branch admin user management should continue to go through `setUserAccessAdmin`.

### Figma Authentication And Church Onboarding Merge: 2026-07-21

Purpose:

- Began the design-to-code merge from Figma file `Daniel App Jeremy Copy` (`Og4PRB5CEEkFwC7jxAXqCk`).
- Used exact design context and screenshots for Login `446:2854`, Signup Step 1 `451:3169`, Signup Step 2 `453:3319`, Signup Step 3 `453:3464`, and Signup success `454:2919`.
- Extracted the full top-level Figma inventory: 105 frames covering Daily Verse, Resources, Group/Connect, Settings, authentication, and state variants.

Product decisions:

- The three Figma signup screens collect name/phone, email, and password/terms, but the Figma success screen grants immediate community membership without selecting a church or waiting for approval.
- Added a separate Church Access stage before account submission. It reuses Firebase-backed active branch selection, supports manual fallback, requests a church confirmation contact, and preserves `membershipStatus: pending` plus admin approval.
- Replaced the Figma success claim with a pending-review state explaining that the church admin must confirm membership and assign groups before scoped Connect content unlocks.
- Kept Google visible because it exists in Figma, but it currently displays an honest configuration notice. The local Firebase plist does not contain `CLIENT_ID` or `REVERSED_CLIENT_ID`, so Google authentication cannot be completed safely until the Firebase iOS configuration is replaced and the Google provider is enabled.
- Implemented Apple authentication rather than leaving a fake button. New Apple users without a Firestore profile are routed into the name/church completion flow instead of bypassing membership approval.

Files changed in this slice:

- `DanielApp/LoginView.swift`
  - Rebuilt the 430-point authentication shell, brand header, language menu, form fields, remember-email option, reset-password entry, provider row, account prompt, and contextual bottom tab bar.
  - Added reusable authentication components shared by registration.
  - Added Sign in with Apple using `AuthenticationServices`, a cryptographically random nonce, SHA-256, and a Firebase Apple credential.
- `DanielApp/RegistrationView.swift`
  - Replaced the legacy long single-page form with progressive onboarding.
  - Matched the first three Figma stages, then added the missing Church Access stage and pending-review completion state.
  - Preserved `RegistrationBranchViewModel`, Firebase branch fields, manual church fallback, and Chinese/English/Korean copy.
- `DanielApp/AuthManager.swift`
  - Added Firebase Apple credential sign-in.
  - Added provider-profile completion detection and Firestore profile creation without creating a second Firebase Auth user.
- `DanielApp/DanielApp.entitlements`
  - Added the Sign in with Apple entitlement.

Validation:

- Passed a full unsigned iOS Simulator build after the Login/Registration rewrite.
- Passed a second build after Apple provider onboarding.
- Passed a third incremental build after aligning Signup Steps 2 and 3 with their exact Figma frames and inserting Church Access.
- Command: `xcodebuild -project DanielApp.xcodeproj -scheme DanielApp -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/DanielAppDerivedData -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build`.

Follow-up:

- The UI/UX designer should add explicit Figma frames for Church Access, invitation-code states, pending approval, rejection/help, group assignment, and approved onboarding completion.
- Complete Google sign-in after a valid Firebase iOS plist supplies the Google client identifiers. Add the official GoogleSignIn package only when that configuration is available.
- Enable Sign in with Apple for `com.daniel.DanielApp` in the Apple Developer portal before a signed device/archive validation.
- Continue exact-node implementation in slices: Daily Verse, Resources, Connect announcement/feed/chat decisions, then Settings/account states.

Additional validation and design review on 2026-07-21:

- Confirmed Figma read access and retrieved implementation context for Daily Verse `74:600`, Resources `74:726`, and Connect Announcements `74:1396` in addition to the authentication frames above.
- Confirmed the primary Resources frame contains Hymnbook, Bible Seminar, Bible Study, Q & A, and Relevant Links, while the current SwiftUI page preserves those directory concepts and also exposes the native Bible Reader and Favorites tools.
- Confirmed the primary Connect announcement frame contains Announcements, Newsletter, and Messenger tabs. The current first phase keeps Announcements and Newsletter Firebase-backed and intentionally leaves realtime messaging unimplemented pending the KakaoTalk-versus-native-chat product decision.
- Figma Starter MCP quota was reached before exact context could be retrieved for Connect Feed `74:1451`, Connect Chat `74:1521`, and Settings `74:1576`. Those screens must not be described as pixel-verified until the quota resets or the Figma plan permits more calls.
- Passed `npm run build` in `functions`.
- Passed `npm run build` in `admin-web`; Vite reported only its existing large-chunk advisory for the 780.53 kB JavaScript bundle.
- Passed the full unsigned iOS Simulator build again after all authentication/onboarding changes: `** BUILD SUCCEEDED **`.
- Firebase Auth and Firestore emulators started successfully and repeatable test data seeded successfully. The iOS test bundle built, but Xcode's simulator test runner stalled while materializing/launching the worker and produced no test cases. The run was cleanly interrupted after repeated no-output intervals; this attempt is recorded as runner timeout, not as a passing test suite. Previous 30-test emulator validation remains the last completed suite before this authentication slice.
- Ran `graphify update .` after code changes; the escalated run rebuilt the AST graph with 2,009 nodes, 3,485 edges, and 118 communities.

### Canada Four-Church International Pilot: 2026-07-22

Branch and rollback:

- Preserved the complete Figma merge worktree in commit `12efa4bd7f7e2bd226f3374ac5268de5c03aec1c` with message `chore: checkpoint Figma merge before Canada pilot`.
- Added annotated tag `checkpoint/figma-merge-2026-07-22` and created `codex/canada-pilot-v1` from that checkpoint.
- Safe recovery command: `git switch -c codex/recovery-2026-07-22 checkpoint/figma-merge-2026-07-22`.
- The branch and tag are local only at this point. The GitHub push was intentionally not completed because repository visibility/trust was not confirmed during the safety review.

Product scope:

- Registration now writes only name, email, optional phone, and base access fields. Legacy sensitive profile fields remain decode-compatible but are not collected or written by the new onboarding UI.
- Email/password users must verify email before redeeming a church token. Apple/provider users complete the same minimal profile and church-access flow.
- New profiles begin as `membershipStatus: unassigned`. A valid token creates only a `pending` member membership; only an administrator action through `setUserAccessAdmin` can make it active.
- Users may skip the token and keep public Daily Verse and Resources access. Unassigned, pending, revoked, loading, error, and recovery states are available in Chinese, English, and Korean.
- Connect v1 is intentionally limited to branch announcements, weekly newsletters, and a protected KakaoTalk group link. Native chat, comments, reactions, groups, and group assignment remain out of scope.

Backend and security:

- Added callable Functions `createBranchInvite`, `listBranchInvites`, `revokeBranchInvite`, and `redeemBranchInvite`.
- Invite codes are 16-character Crockford Base32 values displayed as `XXXX-XXXX-XXXX-XXXX`. Firestore stores only a SHA-256 hash; plaintext is returned once and is never persisted.
- An invite defaults to 90 days and 250 uses. Creating a replacement revokes the previous active token. Redemption is transactional, idempotent per user/invite, and protects the concurrent final use.
- `branchInvites` and `inviteRedemptions` are completely client-denied by Firestore Rules. Invite metadata is returned through the scoped callable without hashes or plaintext.
- Newsletters, announcements, and `branchConnect/{branchId}` are branch-isolated. Active members can read only their own branch; branch admins can manage only their branch; global admins retain cross-branch management.
- Canonical `branchConnect` fields are `branchId`, `groupNameZh`, `groupNameEn`, `groupNameKo`, `kakaoURL`, and `isActive`.

Admin v1:

- Simplified navigation to Dashboard, Members, Churches (global), Announcements & Newsletter, Invite & KakaoTalk, and Resources.
- Members writes use only `setUserAccessAdmin`; the direct client Firestore fallback was removed so profile fields and Auth claims cannot drift.
- The member UI focuses on unassigned/pending/active/revoked state and hides legacy sensitive profile fields.
- Invite management supports create/rotate, copy-once, metadata list, and revoke. KakaoTalk settings use the same canonical fields as iOS.
- Announcement/newsletter records require `branchId` and `contentType`; branch admins query and edit only their branch.

Files introduced in this slice:

- `DanielApp/ChurchInviteService.swift`
- `DanielAppTests/ChurchInviteViewModelTests.swift`
- `DanielAppTests/BranchConnectViewModelTests.swift`
- `admin-web/src/pages/BranchAccess.tsx`
- `scripts/firebase-test-branch-invites.js`

Validation:

- Passed Functions TypeScript production build: `npm run build`.
- Passed Admin production build: `npm run build`; Vite reports only the existing bundle-size advisory.
- Passed unsigned iOS Simulator build with FirebaseFunctions linked: `** BUILD SUCCEEDED **`.
- Passed Auth + Firestore + Functions Emulator suites against demo project `demo-daniel-canada`: existing scoped-admin callable tests plus invite format, hash-only persistence, rotation, revoke, invalid/expired/exhausted/unverified handling, idempotency, concurrent final use, and cross-branch newsletter/Kakao access denial.
- Passed the final complete iOS XCTest run against local Auth and Firestore emulators using project namespace `daniel1-ca1e7`, iPhone 17 / iOS 26.3.1, and parallel testing disabled: 35 tests, 0 failures, `** TEST SUCCEEDED **`. This includes the focused ChurchInvite formatting, submission, invalid-input, and recoverable-error tests.
- A first iPhone 16 Pro / iOS 18.4 attempt stalled before launching tests and was not counted. A diagnostic iPhone 17 run using the wrong demo namespace launched 32 tests but failed 8 emulator tests because the app and seed data used different project IDs; the corrected namespace run passed completely.
- Final `graphify update .` passed after code, tests, and documentation changes: 2,163 nodes, 3,803 edges, and 129 communities.
- No production Firebase data, rules, indexes, Functions, or hosting were deployed.

Release boundary:

- Production setup remains a separate explicitly approved deployment step after review. It must use dry-run branch initialization first, then create the four Canadian branches, scoped branch admins, canonical KakaoTalk configuration, and one token per branch before TestFlight distribution.
- Google Sign-In was configuration-blocked at the end of this Canada-pilot slice; the production-readiness follow-up below records its later provider, plist, SDK, and callback configuration. Apple Sign-In still requires production signed-device/archive validation.

### Production Google Sign-In Readiness: 2026-07-22

- Added the official `GoogleSignIn` Swift package and compiled against resolved version 9.2.0.
- Replaced the Google placeholder action with the real Google SDK flow, Firebase credential exchange, cancellation handling, and Chinese/English/Korean configuration errors.
- New Google users reuse the existing external-provider profile completion and church-token approval path; signing out now clears both Firebase and Google SDK state.
- Added app URL handling through `GIDSignIn.sharedInstance.handle` without removing the existing Daniel verse/widget deep links.
- Moved the app to an explicit `DanielApp/Info.plist` so the `danielapp` deep-link scheme and the Google reversed-client callback scheme coexist predictably. The source Info plist is excluded from Copy Bundle Resources and processed once by Xcode.
- Corrected the app font declarations to the two font files that actually exist in the target.
- Confirmed the ignored local Firebase plist now contains `CLIENT_ID` and `REVERSED_CLIENT_ID`, without printing or committing the real plist.
- Passed plist validation and a complete unsigned iOS Simulator build. Verified in the built app bundle that the Google callback scheme matches the local Firebase config and that the `danielapp` scheme is preserved.
- Remaining runtime validation: complete one interactive Google account sign-in on a signed simulator/device, then confirm both an existing-profile login and a first-time profile-completion path. This cannot be proven by compile-time validation alone.

### Production Pilot Deployment And TestFlight Upload: 2026-07-22

Completed production configuration:

- Enabled the Google provider in Firebase Authentication and downloaded a fresh ignored `GoogleService-Info.plist` containing the real iOS client identifiers. No real plist, service-account JSON, private key, or Admin SDK credential is tracked.
- Registered the Firebase Web app `Daniel Admin` and generated the ignored `admin-web/.env.local` from official Firebase CLI output. Removed the previously tracked `admin-web/.env` from Git and replaced it with a safe `.env.example` contract.
- Upgraded Functions to Node.js 22, `firebase-functions` 7.3.0, and `firebase-admin` 14.2.0, and converted Admin SDK initialization to the modular APIs.
- Deployed Functions, Firestore Rules, Firestore indexes, Storage Rules, and Admin Hosting to `daniel1-ca1e7` after the complete emulator suite and a production dry run passed.
- Verified all seven callable Functions are deployed on Node.js 22 and the Admin portal responds at `https://daniel1-ca1e7.web.app`.
- Archived and uploaded iOS `1.0.2 (3)` to App Store Connect. Xcode reported `Upload succeeded` and the package entered processing. Third-party Firebase/Google binary dSYM warnings remain, but did not block the upload.

Resources simplification:

- Resources v1 is one shared, public, published library managed only by `global_admin`; it is not duplicated per church and has no unused member-access selector.
- Published Firestore resource documents and their PDFs are publicly readable. Drafts remain denied. Resource create/update/delete and PDF upload/delete remain global-admin-only.
- URLs are limited to `http`/`https`, PDFs are limited to under 50 MiB, and PDF replacement/removal is ordered so a canceled or failed edit cannot break the currently published file.
- The production project already contains five resource documents, so no duplicate seed write was performed.

Validation completed before production deployment:

- Functions production build passed after the Node.js 22 dependency upgrade.
- Admin production build passed; Vite's approximately 770 kB main-bundle advisory remains a non-blocking P2 route-splitting opportunity.
- Auth, Firestore, Functions, and Storage Emulator tests passed, including invite hashing/rotation/revocation/exhaustion/concurrent-final-use, scoped-admin denial, cross-branch isolation, public published-resource reads, draft denial, PDF type/size limits, and global-admin-only uploads.
- Final signed-independent iOS Simulator XCTest run completed with `** TEST SUCCEEDED **`, including the added Resources URL and draft-access cases.
- Release archive `1.0.2 (3)` completed with `** ARCHIVE SUCCEEDED **`; App Store Connect upload completed with `** EXPORT SUCCEEDED **`.

Production boundary still requiring church-supplied data:

- Four Canadian branches were not invented or written. The repository does not contain the four exact church names, cities, stable branch IDs, branch-admin emails, or KakaoTalk URLs.
- The legacy `scripts/firebase-seed-branch-system.js` dry run targets two old/non-pilot branches and would patch five existing users, so it was deliberately not confirmed for the Canada pilot.
- Once an explicit four-row pilot manifest is supplied and reviewed, run a new manifest-scoped dry run, create only those branches/admin assignments/KakaoTalk records/tokens, and then invite the four church tester groups in TestFlight.

Design evidence boundary:

- The Resources implementation continues the already retrieved Figma frame `74:726` and the repository's established cream-card/orange-accent design system.
- A fresh Figma MCP context request was blocked by the Figma Starter plan call limit. No screen changed in this slice is claimed as newly pixel-verified.
