# Daniel App Admin Web

The admin portal manages the Canada-pilot church data. The Resources page is intentionally global-admin-only because Resources v1 is a shared public library, not branch-specific content.

## Local setup

Copy `.env.example` to `.env.local` and provide all six public Firebase web-app configuration values from Firebase Console → Project settings → Your apps → Web app. These identify the Firebase project; they are not service-account credentials. Never put a service-account JSON or private key in this app. The portal stops with a clear error when any value is missing instead of silently connecting with a placeholder app ID.

For the checked Firebase project, prefer generating the ignored local file from the official CLI output instead of copying values by hand:

```bash
firebase apps:sdkconfig WEB <web-app-id> --project <project-id> --out /tmp/firebase-web-config.json
node scripts/firebase-write-admin-env.js /tmp/firebase-web-config.json
```

```bash
npm install
npm run dev
```

Use the Firebase Emulator Suite for development. The root `firebase.json` configures Auth, Firestore, Storage, and Functions emulators.

## Resources workflow

1. Sign in with a `global_admin` account and open `/resources`.
2. Add a trilingual title, subtitle, action label, and description.
3. Choose one of the five shared categories and optionally add an `https://` link or a PDF under 50 MB.
4. Leave the item as a draft while checking it in Admin; publish it when it is ready for every app user.
5. The iOS Resources tab queries published documents from `resources`, ordered by `sortOrder`, and falls back to its bundled seed only when Firebase is unavailable or empty.

Published Resources are public during the Canada pilot, including their linked PDF files. Church-only communication belongs in branch-scoped Announcements, Newsletter, and KakaoTalk—not in Resources. Replacing or removing a PDF updates Firestore first and deletes the old Storage object only after the save succeeds, so canceling an edit cannot break a live resource.

## Validation

```bash
npm run build
```

Firestore and Storage rules must be validated in the emulators before any production deploy. Production resource seeding is handled by the root `scripts/firebase-seed-production-resources.js` dry-run/confirmation workflow.
