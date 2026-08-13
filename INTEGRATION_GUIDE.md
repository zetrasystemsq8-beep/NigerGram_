# 🚀 Professional Innovation Platform - Integration Guide

## Overview
NigerGram has been transformed from a general content platform into a **Professional Innovation Sharing Platform** (similar to LinkedIn's video section). Innovators can now create podcasts, edit videos professionally, and share breakthroughs in law, technology, healthcare, finance, and more.

---

## 📁 New Files Created

### 1. **Data Models**
- `lib/features/media/models/video_edit_model.dart` - Comprehensive editing parameters

### 2. **Video Editing**
- `lib/features/media/presentation/pages/advanced_video_editor_page.dart` - Professional video editor

### 3. **Podcast Creation**
- `lib/features/media/presentation/pages/podcast_editor_page.dart` - Podcast editor with multi-track audio

### 4. **Audio Recording**
- `lib/features/media/presentation/widgets/voiceover_recorder_widget.dart` - Waveform-based recorder

### 5. **Professional Upload**
- `lib/features/upload/presentation/view/professional_upload_page.dart` - LinkedIn-style upload

---

## 🔧 Setup Instructions

### Step 1: Update Dependencies
```bash
flutter pub get
```

This installs all 40+ new packages including:
- `video_editor` - Timeline editing
- `record` - Audio recording
- `flutter_audio_waveforms` - Waveform visualization
- `google_ml_kit` - AI captions
- `firebase_messaging` - Push notifications

### Step 2: Update Router Configuration

Add these routes to `lib/core/utils/router.dart` (or wherever your router is configured):

```dart
// Import new pages
import 'package:nigergram/features/media/presentation/pages/advanced_video_editor_page.dart';
import 'package:nigergram/features/media/presentation/pages/podcast_editor_page.dart';
import 'package:nigergram/features/upload/presentation/view/professional_upload_page.dart';

// Add to GoRouter routes
final List<RouteBase> routes = [
  // ... existing routes ...
  
  GoRoute(
    path: '/upload/professional',
    name: 'professionalUpload',
    builder: (context, state) => const ProfessionalUploadPage(),
  ),
  
  GoRoute(
    path: '/editor/video/:videoPath',
    name: 'videoEditor',
    builder: (context, state) {
      final videoPath = state.pathParameters['videoPath'];
      return AdvancedVideoEditorPage(videoPath: videoPath ?? '');
    },
  ),
  
  GoRoute(
    path: '/editor/podcast',
    name: 'podcastEditor',
    builder: (context, state) => const PodcastEditorPage(),
  ),
];
```

### Step 3: Update Upload Navigation Button

In your dashboard/home page, replace the old upload button:

```dart
// OLD
FloatingActionButton(
  onPressed: () => context.push('/upload'),
  child: const Icon(Icons.add),
)

// NEW - Click to choose content type
FloatingActionButton(
  onPressed: () => _showUploadOptions(context),
  child: const Icon(Icons.add),
)

void _showUploadOptions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) => Container(
      color: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.video_camera_back, color: Colors.blue),
            title: const Text('Video Innovation'),
            subtitle: const Text('Share your breakthrough'),
            onTap: () {
              Navigator.pop(ctx);
              context.push('/upload/professional');
            },
          ),
          ListTile(
            leading: const Icon(Icons.mic, color: Colors.purple),
            title: const Text('Podcast Episode'),
            subtitle: const Text('Record your story'),
            onTap: () {
              Navigator.pop(ctx);
              context.push('/editor/podcast');
            },
          ),
        ],
      ),
    ),
  );
}
```

### Step 4: Configure Permissions

**Android** - `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.INTERNET" />
```

**iOS** - `ios/Runner/Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>We need microphone access to record voiceovers and podcasts</string>
<key>NSCameraUsageDescription</key>
<string>We need camera access to record innovation videos</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need photo library access to select videos and images</string>
```

### Step 5: Firebase Cloud Messaging (Notifications)

**In `lib/main.dart`:**
```dart
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Request notification permissions
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: true,
    badge: true,
    carPlay: false,
    criticalSound: false,
    provisional: false,
    sound: true,
  );
  
  print('User granted permission: ${settings.authorizationStatus}');
  
  // Handle background messages
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  runApp(const NigerGramApp());
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.messageId}');
}
```

### Step 6: Update Firestore Schema

Create a migration script or manually add these rules to your Firestore:

**Firestore Security Rules:**
```
service cloud.firestore {
  match /databases/{database}/documents {
    // User documents
    match /users/{userId} {
      allow read: if request.auth != null;
      allow create, update: if request.auth != null && request.auth.uid == userId;
    }
    
    // Innovation posts (new collection)
    match /innovations/{innovationId} {
      allow read: if true; // Public read
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null && 
        resource.data.userId == request.auth.uid;
    }
    
    // Video metadata
    match /videos/{videoId} {
      allow read: if true;
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null && 
        resource.data.userId == request.auth.uid;
    }
    
    // User drafts
    match /users/{userId}/drafts/{draftId} {
      allow read, create, update, delete: if request.auth != null && 
        request.auth.uid == userId;
    }
  }
}
```

### Step 7: Update Supabase Storage

**Create new buckets in Supabase:**
1. `innovations-videos` - Professional innovation videos
2. `podcast-audio` - Podcast episodes
3. `innovation-thumbnails` - Thumbnails for innovations

**Supabase RLS Policy for innovations-videos:**
```sql
CREATE POLICY "Users can upload to their folder"
ON storage.objects
FOR INSERT
WITH CHECK (
  auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can update their own files"
ON storage.objects
FOR UPDATE
WITH CHECK (
  auth.uid()::text = (storage.foldername(name))[1]
);
```

---

## 🎯 Feature Documentation

### Advanced Video Editor
**Path:** `lib/features/media/presentation/pages/advanced_video_editor_page.dart`

**Features:**
- ⏱️ **Timeline Scrubbing** - Drag to trim or cut video
- 🎬 **Playback Speed** - 0.5x to 2.0x (7 options)
- 🎨 **Color Grading** - Brightness, Contrast, Saturation (-100 to +100)
- ✨ **14+ Filters** - Noir, Sepia, Vivid, Cool, Warm, HDR, etc.
- 📐 **Aspect Ratio** - 9:16, 1:1, 16:9, 21:9
- 📝 **Text Overlays** - Multiple fonts, colors, positions, timing
- 🎵 **Background Music** - Royalty-free library with volume control
- 🎤 **Voiceover** - Record narration directly
- 📊 **Subtitles** - Manual and auto-generated

**Usage:**
```dart
final result = await Navigator.push<VideoEditModel>(
  context,
  MaterialPageRoute(
    builder: (context) => AdvancedVideoEditorPage(
      videoPath: '/path/to/video.mp4',
    ),
  ),
);

// Result contains all edit parameters
if (result != null) {
  // Apply edits and upload
}
```

### Podcast Editor
**Path:** `lib/features/media/presentation/pages/podcast_editor_page.dart`

**Features:**
- 📋 **Episode Metadata** - Title, description, guest names
- 🎙️ **Multi-Track Audio** - Voiceover, Guest, Music, SFX tracks
- 🔊 **Volume Control** - Per-track volume adjustment
- 🤖 **Auto-Captions** - AI-powered speech-to-text
- 📝 **Manual Captions** - Add/edit captions manually
- 🎯 **Templates** - Quick start with industry templates
- ⚙️ **Quality Presets** - 128kbps, 192kbps, 320kbps
- 💾 **Export Options** - MP3, WAV formats

**Usage:**
```dart
final result = await Navigator.push<VideoEditModel>(
  context,
  MaterialPageRoute(
    builder: (context) => const PodcastEditorPage(),
  ),
);
```

### Voiceover Recorder
**Path:** `lib/features/media/presentation/widgets/voiceover_recorder_widget.dart`

**Features:**
- 🎤 **Real-time Recording** - Start/Stop with duration tracking
- 📊 **Waveform Visualization** - Real-time animated waveform
- 🔇 **Noise Reduction** - Toggle noise cancellation
- 🗑️ **Delete/Retry** - Delete and re-record easily

**Usage:**
```dart
VoiceoverRecorderWidget(
  onRecordingComplete: (audioPath, duration) {
    // Handle recorded audio
    print('Recorded: $audioPath, Duration: $duration');
  },
)
```

### Professional Upload Page
**Path:** `lib/features/upload/presentation/view/professional_upload_page.dart`

**Features:**
- 🎬 **Video/Podcast Toggle** - Choose content type
- 💡 **Innovation Title** - Clear, descriptive title
- 🏢 **Industry Sectors** - 12 categories (Tech, Healthcare, Finance, etc.)
- 📊 **Innovation Type** - App, Law, Process, Service, Research, Hardware
- ⚠️ **Problem Statement** - Describe the problem solved
- 📈 **Impact Description** - Who benefits and how
- 🔗 **Research Links** - Attach papers and references
- #️⃣ **Professional Tags** - Searchable tags
- 📝 **Auto-Save Drafts** - Every 30 seconds
- ✏️ **Integrated Editors** - Access video/podcast editors
- 📤 **Upload Progress** - Real-time progress tracking

---

## 🔐 Best Practices

### Security
✅ Always validate user input before database operations
✅ Use Firebase Security Rules to protect data
✅ Never store sensitive data in plaintext
✅ Implement rate limiting for uploads
✅ Use HTTPS for all API calls

### Performance
✅ Compress videos before upload (already implemented)
✅ Use lazy loading for innovation feeds
✅ Cache thumbnails locally
✅ Limit audio track count to 5 per podcast
✅ Use preload_page_view for smooth scrolling

### UX
✅ Show upload progress to users
✅ Auto-save drafts every 30 seconds
✅ Provide clear error messages
✅ Add loading indicators during processing
✅ Test on low-bandwidth connections

---

## 🧪 Testing Checklist

### Video Editor
- [ ] Load video successfully
- [ ] Trim video using timeline
- [ ] Apply all filters
- [ ] Change playback speed
- [ ] Adjust color grading (brightness, contrast, saturation)
- [ ] Add text overlay
- [ ] Change aspect ratio
- [ ] Add background music
- [ ] Verify audio levels
- [ ] Export edited video

### Podcast Editor
- [ ] Add episode metadata
- [ ] Add multiple audio tracks (voiceover, guest, music)
- [ ] Adjust volume per track
- [ ] Mute/unmute tracks
- [ ] Auto-generate captions
- [ ] Manually add captions
- [ ] Apply podcast template
- [ ] Select audio quality
- [ ] Export podcast

### Voiceover Recorder
- [ ] Start recording
- [ ] See waveform animation
- [ ] Stop recording
- [ ] Play back recording
- [ ] Delete recording
- [ ] Re-record successfully
- [ ] Test noise reduction toggle

### Upload
- [ ] Select video from gallery
- [ ] Record video from camera
- [ ] Fill in all fields
- [ ] Apply video edits
- [ ] Add podcast configuration
- [ ] See draft auto-save
- [ ] Upload successfully
- [ ] Verify in Firestore

---

## 🐛 Troubleshooting

### "Permission Denied" Error
```
Solution: Request permissions at runtime using permission_handler
```

### "Memory Exhausted" During Video Processing
```
Solution: Reduce quality setting or video resolution
Increase max heap size: flutter run --verbose
```

### "Audio Recording Failed"
```
Solution: Check microphone permission, restart app
Verify AudioSession is initialized properly
```

### "Waveform Not Displaying"
```
Solution: Ensure flutter_audio_waveforms is properly installed
Check if recording is actually capturing audio
```

### "Auto-Caption Not Working"
```
Solution: Enable Google ML Kit in Firebase Console
Check internet connectivity
Verify language is supported
```

---

## 📊 Firestore Collection Schema

### `/innovations/{innovationId}`
```json
{
  "title": "string",
  "problemStatement": "string",
  "impact": "string",
  "category": "Technology | Healthcare | Finance | ...",
  "innovationType": "App | Law | Process | Service | Research | Hardware",
  "contentType": "video | podcast",
  "videoKey": "string (Supabase path)",
  "videoUrl": "string (public URL)",
  "userId": "string",
  "username": "string",
  "profileImageUrl": "string",
  "tags": ["string"],
  "researchLink": "string (optional)",
  "videoEdits": "string (serialized VideoEditModel)",
  "podcastEdits": "string (serialized VideoEditModel)",
  "likeCount": "number",
  "commentCount": "number",
  "shareCount": "number",
  "viewCount": "number",
  "timestamp": "serverTimestamp",
  "isVerified": "boolean",
  "status": "published | pending | archived"
}
```

---

## 🚀 Deployment Checklist

- [ ] All dependencies added to pubspec.yaml
- [ ] Router configured with new routes
- [ ] Permissions added to AndroidManifest.xml and Info.plist
- [ ] Firebase/Supabase buckets created
- [ ] Firestore Security Rules updated
- [ ] Environment variables configured
- [ ] Testing completed (all features working)
- [ ] Performance optimization applied
- [ ] Analytics tracking added
- [ ] Crash reporting enabled
- [ ] Build APK/IPA successfully
- [ ] Tested on multiple devices

---

## 📚 Additional Resources

- [Flutter Video Player Docs](https://pub.dev/packages/video_player)
- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [Google ML Kit](https://pub.dev/packages/google_ml_kit)
- [Supabase Storage](https://supabase.com/docs/guides/storage)
- [FFmpeg Kit](https://pub.dev/packages/ffmpeg_kit_flutter)
- [Record Audio Package](https://pub.dev/packages/record)

---

## 💬 Support & Questions

For issues or questions:
1. Check this guide first
2. Review Firestore logs in Firebase Console
3. Check Flutter console for error messages
4. Test on a physical device (not just emulator)
5. Review package documentation

---

**Version:** 1.0.0  
**Last Updated:** August 13, 2026  
**Platform:** Flutter 3.0+
