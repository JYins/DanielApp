# Firebase Product Design: Connect, Resources, Bible Reader, Favorites

Date: 2026-06-07

## Product Design Brief

Use the existing Daniel App warmth: calm church utility, cream/orange devotional tone, trilingual surfaces, and the current four-tab shell.

Design target:

- Connect becomes a signed-in church community surface with realtime posts, announcements, newsletters, comments, and reactions.
- Resources grows into a richer library: PDF hymnbooks/documents, useful links, Bible study/seminar materials, and a built-in Bible reader.
- The Bible reader and Daily Verse share one favorite/note system. Daily Verse no longer needs separate read/like as primary actions.
- Signed-out users can read public resources and Bible text. Guest favorites can stay local. Cloud favorites and all notes require login.
- A Favorites page groups saved items by date and can later filter by verses, resources, PDFs, and Connect posts.

## Can Firebase Do This?

Yes. Firebase is enough for the next phases:

- Firebase Auth: account login, approval, custom claims, branch/region roles.
- Firestore: realtime Connect feeds, comments, reactions, resources metadata, favorites, notes, reading progress.
- Firebase Storage: PDFs, images, newsletter media, hymnbook files.
- Cloud Functions: server-side permission checks, counters, notifications, moderation hooks, claim sync.
- Firebase Emulator: local rules/function tests before production changes.

Potential later add-ons:

- FCM for push notifications on comments, announcements, and branch messages.
- Algolia or Typesense if Bible/resource search outgrows Firestore/local JSON search.
- Remote Config for feature flags such as enabling Connect comments by branch.

## Connect Design

### Navigation

Connect should become three focused areas:

1. Announcements
   - Official posts from global, region, or branch admins.
   - Realtime comments can be enabled per post.
   - Pinned items appear first.

2. Newsletter
   - Continues to reuse the existing `newsletters` collection.
   - Newsletter comments are optional; if enabled, they should use the same comment system as Connect posts.

3. Community
   - Member-visible branch/region discussion posts.
   - First version can be admin-created posts with member comments.
   - Later versions can allow approved members to create posts, pending moderation.

### Connect Firestore Schema

```text
connectPosts/{postId}
connectPosts/{postId}/comments/{commentId}
connectPosts/{postId}/reactions/{uid}
newsletters/{newsletterId}
newsletters/{newsletterId}/comments/{commentId}
newsletters/{newsletterId}/reactions/{uid}
```

`connectPosts/{postId}` fields:

- `type`: `announcement | community | message_placeholder`
- `audienceScope`: `global | region | branch`
- `orgId`, `regionId?`, `branchId?`
- `title.zh/en/ko`
- `body.zh/en/ko`
- `mediaUrls[]`
- `authorUid`, `authorName`, `authorRole`
- `isPinned`, `isPublished`, `commentsEnabled`
- `reactionCounts.like`, `reactionCounts.pray`, `reactionCounts.amen`
- `commentCount`
- `moderationStatus`: `published | pending | hidden`
- `createdAt`, `updatedAt`, `publishedAt`

`comments/{commentId}` fields:

- `authorUid`, `authorName`
- `body`
- `language`
- `moderationStatus`: `published | pending | hidden`
- `createdAt`, `updatedAt`

`reactions/{uid}` fields:

- `uid`
- `type`: `like | pray | amen`
- `createdAt`, `updatedAt`

### Connect Rules

- Published global announcements: approved users can read.
- Region posts: approved users in the same region, region admins, global admins.
- Branch posts: approved users in the same branch, branch admins, region admins for that region, global admins.
- Comments: approved users can create comments only under readable published posts.
- Comment edits/deletes: owner can edit/delete own comment; scoped admins can hide comments in their scope.
- Counters should be maintained by Cloud Functions to avoid trusting client counts.

## Hymnbook / PDF Reader Design

Use Firebase Storage for files and Firestore for metadata. The iOS app should render PDFs with PDFKit for a native reading experience.

Expected reader features:

- Page thumbnails or page scrubber.
- Search within PDF when text is embedded.
- Current page persistence.
- Download/cache for offline church use.
- Share/open externally when needed.
- Favorite whole PDF or a specific page.
- Notes can attach to a PDF page for signed-in users.

Schema:

```text
resources/{resourceId}
resourceFiles/{fileId}
users/{uid}/readingProgress/{targetId}
```

`resourceFiles/{fileId}` fields:

- `resourceId`
- `storagePath`
- `downloadUrl?`
- `fileType`: `pdf | image | audio | link`
- `title.zh/en/ko`
- `pageCount?`
- `sizeBytes?`
- `isPublished`
- `createdAt`, `updatedAt`

## Bible Reader Design

The Bible reader can start from the bundled `verses_merged.json` so signed-out reading stays fast and offline. Firebase stores only personal overlays: favorites, notes, and reading progress.

UI structure:

- Top selector: language, book, chapter.
- Main list: verse number and verse text.
- Verse row actions: favorite, note, copy/share.
- Logged-out: can read and optionally save local favorites.
- Logged-in: favorites, notes, and progress sync to Firestore.

The Resources tab can include a first-class "Bible Reader" resource entry. It should open a native reader, not a web wrapper.

## Unified Favorites And Notes

Daily Verse should use the same favorite model as the Bible reader. Replace the separate primary `read` and `like` mental model with:

- Favorite: useful for Daily Verse and Bible Reader.
- Note: login required.
- Read/progress: internal state only where it helps reading progress, not a main social action.

Guest behavior:

- Bible reading works.
- Public resources work.
- Guest favorites can be local-only in App Group/UserDefaults.
- On login, offer to sync guest favorites into Firestore.
- Notes require login because they are personal, durable, and should not be lost.

Firestore schema:

```text
users/{uid}/favorites/{favoriteId}
users/{uid}/notes/{noteId}
users/{uid}/readingProgress/{targetId}
```

`favorites/{favoriteId}` fields:

- `targetType`: `verse | resource | pdfPage | connectPost | newsletter`
- `targetId`
- `reference?`: Bible reference such as `John 3:16`
- `resourceId?`
- `pageNumber?`
- `title.zh/en/ko`
- `snippet.zh/en/ko`
- `dateKey`: `YYYY-MM-DD`
- `createdAt`, `updatedAt`

`notes/{noteId}` fields:

- `targetType`: `verse | resource | pdfPage | connectPost | newsletter`
- `targetId`
- `reference?`
- `body`
- `language`
- `isPrivate`: true
- `createdAt`, `updatedAt`

`readingProgress/{targetId}` fields:

- `targetType`: `bible | pdf | resource`
- `book?`, `chapter?`, `verse?`
- `resourceId?`, `pageNumber?`
- `updatedAt`

## Favorites Page

Add a Favorites page reachable from Settings and optionally from Resources.

Default grouping:

- Today
- Yesterday
- This Week
- Earlier, grouped by date

Card types:

- Verse favorite: reference, verse snippet, note indicator.
- PDF page favorite: resource title, page number.
- Resource favorite: title/subtitle.
- Connect favorite: post title and source.

Useful filters later:

- All
- Verses
- Resources
- PDFs
- Connect
- With Notes

## Suggested Implementation Phases

### Phase 4: Unified Verse Favorites - Implemented Locally

- Add `FavoriteService` and `NoteService`.
- Migrate Daily Verse favorite to `users/{uid}/favorites`.
- Keep guest favorites local and sync on login.
- De-emphasize or remove read/like UI.
- Add Favorites page with date grouping.

Status: the first implementation now uses `FavoriteService` as the shared boundary for verse favorites and notes. Daily Verse favorite/note actions and the Resources Bible Reader use the same local-first store and owner-only Firestore paths. Notes require login; guest favorites remain local.

### Phase 5: Bible Reader - Implemented Locally

- Add native Bible Reader under Resources.
- Use bundled verse JSON for reading.
- Connect favorites and notes to the shared services.
- Add reading progress.

Status: a native SwiftUI Bible Reader is available from Resources. It reads bundled Bible data, supports book/chapter selection, verse favorites, and signed-in notes. Firestore rules and emulator integration tests now cover owner-only reading progress paths; automatic progress persistence can be expanded in a later refinement.

### Phase 6: PDF Hymnbook Reader

- Extend `resources` with PDF metadata.
- Add PDFKit reader, caching, page progress, page favorites, and page notes.
- Add admin upload path for PDF resources.

### Phase 7: Connect Realtime Community

- Add `connectPosts`, comments, reactions, and scoped rules.
- Keep newsletters collection, optionally add newsletter comments/reactions.
- Add Cloud Functions for counters/moderation.
- Add notification hooks later.

## Open Product Choices

- Whether members can create Connect posts in the first realtime phase or only comment on admin posts.
- Whether comments should be branch-only by default.
- Whether guest favorites should always sync automatically after login or ask first.
- Whether notes support rich text later or stay plain text in the first version.
