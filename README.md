# NigerGram

NigerGram is a mobile-first short video and social application built with Flutter. It focuses on fast video feeds, in-app uploading, profiles, and social interactions — designed for the Nigerian market but built to scale globally.

This repository contains the Flutter app (UI, business logic) plus infra-related files used for Supabase and Firebase integration.

## Author

Created by: Oyedele Toluwani ("Connect Baba")

## Stack

- Language / Framework: Flutter (Dart)
- Backend services:
  - Firebase (Auth, Firestore) — primary auth and user metadata
  - Supabase Storage — object storage for videos and images (used for public URLs / CDN)
- Notable packages (from `pubspec.yaml`):
  - firebase_core, firebase_auth, cloud_firestore
  - supabase_flutter
  - image_picker, video_player, video_compress
  - flutter_bloc, go_router

## Repository layout (important paths)

```
lib/                              # Flutter app source
  features/                       # Feature modules: auth, profile, upload, media, etc.
supabase/migrations/              # Supabase SQL migrations (policies for storage)
android/, ios/                    # Platform-specific projects
pubspec.yaml                      # Dart/Flutter dependencies
README.md                         # (this file)
LICENSE                           # Project license
```

## Quickstart — run the app locally

Prerequisites
- Flutter (stable channel, matching the project SDK constraints). See Flutter docs: https://flutter.dev
- Firebase project with Android/iOS apps configured (google-services.json / GoogleService-Info.plist)
- Supabase project for Storage

Steps
1. Clone the repo

```bash
git clone git@github.com:zetrasystemsq8-beep/NigerGram_.git
cd NigerGram_
```

2. Install dependencies

```bash
flutter pub get
```

3. Configure Firebase
- Place `android/app/google-services.json` and/or `ios/Runner/GoogleService-Info.plist` (DO NOT commit secrets to git).
- Ensure `lib/firebase_options.dart` values match your Firebase project (apiKey, projectId, appId).
- Ensure Firestore rules allow authenticated users to update their own `users/{uid}` documents (example rules below).

Firestore minimal rules (example — set via Firebase Console → Firestore → Rules):

```
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && request.auth.uid == userId;
      allow update: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

4. Configure Supabase
- In the code we initialize Supabase in `lib/main.dart` via a URL and anon key. For production, use secure environment variables or CI secrets.
- Apply the Supabase Storage Row-Level Security migration included in the repo to allow users to write their own images under `users/{uid}/`:

  - File: `supabase/migrations/2026-06-24-01_images_rls.sql`
  - Open Supabase Dashboard → SQL Editor → New query and paste/run the SQL in that file.

The migration creates three policies that allow authenticated INSERT/UPDATE/DELETE only for objects whose path starts with `users/{auth.uid()}/`.

5. Run the app

```bash
flutter run
# or build an apk
flutter build apk --debug --no-tree-shake-icons
```

## How image & video uploads work (important)

- Videos are uploaded to the `videos` bucket in Supabase storage with unique filenames (uid + timestamp) to avoid collisions.
- Profile photos and cover images are uploaded to the `images` bucket under a per-user folder `users/{uid}/` with unique names. This avoids Android upsert/file-lock collisions and allows safe ownership policies on the storage side.
- After a successful upload, the app writes two fields into Firestore `users/{uid}` doc:
  - `profilePicUrl` / `coverUrl` — public URL to the uploaded object
  - `profilePicPath` / `coverPath` — storage path (used to delete old files)

## Applying the image RLS policy (one-time)

If you didn't run the migration earlier, do it now in the Supabase SQL editor. The SQL file is in the repository:

```
supabase/migrations/2026-06-24-01_images_rls.sql
```

Open your Supabase project → SQL Editor → paste the file contents and run.

## CI / Building APK

This repository includes a GitHub Actions workflow that builds an APK. If the Actions job fails during Flutter compilation, inspect the logs for syntax errors or missing configuration files (e.g., Firebase options).

Common CI checklist:
- Ensure `lib/firebase_options.dart` is correct for the project used in CI.
- Add any secrets (google-services.json) to Actions via repository secrets if required by your workflow.
- Ensure Supabase migrations/policies were applied if tests rely on them.

## Contributing

Contributions welcome. Please:
- Fork the repository
- Create a feature branch
- Open a PR with a clear description and testing steps

## Contact / Creator

Project created by Oyedele Toluwani (Connect Baba).

If you need help, open an issue or contact the author.

## License

See the `LICENSE` file in the repository.
