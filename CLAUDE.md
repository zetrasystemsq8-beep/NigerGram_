# CLAUDE.md

## 🎯 Project Overview

**Flutter Video Feed** - Ultra-performant TikTok-style video feed with **INTERACTIVE MEDIA FEED** and Clean Architecture.

**Purpose:** Showcase project for personal branding and job opportunities (NOT production app)

**What Makes This Unique:**
- 🎥 Ultra-performant video feed (60 FPS, optimized memory)
- 🎮 **INTERACTIVE MEDIA FEED**: Hotspots, polls, quizzes on videos
- 🏗️ Clean Architecture (Feature-First, Layer-Within)
- 📱 Full responsive design system (no hardcoded values)

**Status:** Under active transformation - see PROJECT_STATUS.md

---

## 🏗️ Architecture: Feature-First, Layer-Within

### Structure
```
lib/
├── features/
│   └── video_feed/
│       ├── data/           # Firebase, external APIs
│       ├── domain/         # Business logic (pure Dart)
│       └── presentation/   # UI and state management
└── core/
    ├── design_system/
    ├── utils/extensions/
    └── di/
```

### Data Flow
```
User Input → Presentation → Domain → Data → Firebase
           ← Presentation ← Domain ← Data ← Response
```

### Layer Rules
- **Domain**: NO external dependencies (no Firebase, no Flutter, pure Dart)
- **Data**: Depends ONLY on Domain
- **Presentation**: Depends ONLY on Domain

---

## 📦 Key Technologies

**State Management:** flutter_bloc, equatable
**Error Handling:** fpdart (Either pattern)
**Video:** video_player, flutter_cache_manager, preload_page_view
**Backend:** Firebase (Firestore only)
**DI:** get_it
**Navigation:** go_router
**Caching:** cached_network_image (optional)

---

## 🎮 Interactive Media Feed (USP)

### What It Is
Videos with interactive overlays that users can tap:
- **Hotspots**: Tappable dots that reveal info
- **Polls**: Vote while watching
- **Quizzes**: Answer questions (optional)

### Data Structure
```dart
class InteractiveElement {
  final String type;           // 'hotspot', 'poll', 'quiz'
  final double x, y;           // Position (0.0-1.0, relative)
  final int showAtSecond;      // When to appear
  final Map<String, dynamic> data; // Element-specific content
}
```

### Implementation
- Position using relative coordinates (responsive)
- Show/hide based on video time
- Stack overlay on video player
- Simple, impressive implementation

---

## 🎨 Responsive Design System

**Reference:** iPhone 16 Pro Max (430×932)
**File:** `lib/core/utils/extensions/build_context_responsive_extensions.dart`

### Methods
```dart
// Sizing
context.w(200)          // Responsive width
context.h(100)          // Responsive height
context.fontSize(18)    // Responsive font
context.square(24)      // Perfect square

// Spacing
context.hSpace(16)      // Vertical SizedBox
context.wSpace(20)      // Horizontal SizedBox

// Padding
context.padAll(16)
context.padHorizontal(12)
context.padVertical(8)

// Radius
context.radiusAll(12)
context.radiusTop(8)
```

### Usage
```dart
// ✅ CORRECT
Container(
  width: context.w(200),
  height: context.h(100),
  padding: context.padAll(16),
  decoration: BoxDecoration(
    borderRadius: context.radiusAll(12),
  ),
  child: Text(
    'Text',
    style: TextStyle(fontSize: context.fontSize(16)),
  ),
)

// ❌ FORBIDDEN
Container(width: 200, height: 100)
SizedBox(height: 24)
Text('Text', style: TextStyle(fontSize: 16))
```

---

## 💻 Code Patterns

### Repository Pattern
```dart
// Domain (interface)
abstract interface class VideoFeedRepository {
  Future<Either<String, List<VideoEntity>>> fetchVideos();
  Future<Either<String, List<VideoEntity>>> fetchMoreVideos();
}

// Data (implementation)
class VideoFeedRepositoryImpl implements VideoFeedRepository {
  VideoFeedRepositoryImpl({required this.firestore});
  final FirebaseFirestore firestore;

  @override
  Future<Either<String, List<VideoEntity>>> fetchVideos() async {
    try {
      final snapshot = await firestore
        .collection('videos')
        .limit(10)
        .get();

      final videos = snapshot.docs
        .map((doc) => VideoResponseModel.fromFirestore(doc).toEntity())
        .toList();

      return Right(videos);
    } on FirebaseException catch (e) {
      return Left('Failed to load videos: ${e.message}');
    } catch (e) {
      return const Left('An unexpected error occurred');
    }
  }
}
```

### UseCase Pattern
```dart
class FetchVideosUseCase {
  FetchVideosUseCase({required this.repository});
  final VideoFeedRepository repository;

  Future<Either<String, List<VideoEntity>>> call() async {
    // Add validation/business logic if needed
    return await repository.fetchVideos();
  }
}
```

### State Pattern
```dart
class VideoFeedState extends Equatable {
  const VideoFeedState({
    this.isLoading = false,
    this.isSuccess = false,
    this.errorMessage = '',
    this.videos = const [],
    this.currentIndex = 0,
  });

  final bool isLoading;
  final bool isSuccess;
  final String errorMessage;
  final List<VideoEntity> videos;
  final int currentIndex;

  VideoFeedState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? errorMessage,
    List<VideoEntity>? videos,
    int? currentIndex,
  }) => VideoFeedState(
    isLoading: isLoading ?? this.isLoading,
    isSuccess: isSuccess ?? this.isSuccess,
    errorMessage: errorMessage ?? this.errorMessage,
    videos: videos ?? this.videos,
    currentIndex: currentIndex ?? this.currentIndex,
  );

  @override
  List<Object?> get props => [isLoading, isSuccess, errorMessage, videos, currentIndex];
}
```

### Entity (Domain)
```dart
class VideoEntity extends Equatable {
  const VideoEntity({
    required this.id,
    required this.username,
    required this.description,
    required this.videoUrl,
    required this.profileImageUrl,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.timestamp,
    this.interactiveElements = const [],
  });

  final String id;
  final String username;
  final String description;
  final String videoUrl;
  final String profileImageUrl;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final DateTime timestamp;
  final List<InteractiveElement> interactiveElements;

  @override
  List<Object?> get props => [
    id, username, description, videoUrl, profileImageUrl,
    likeCount, commentCount, shareCount, timestamp, interactiveElements
  ];
}
```

### Model (Data)
```dart
class VideoResponseModel {
  const VideoResponseModel({
    required this.id,
    required this.username,
    required this.description,
    required this.videoUrl,
    required this.profileImageUrl,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.timestamp,
  });

  final String id;
  final String username;
  final String description;
  final String videoUrl;
  final String profileImageUrl;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final Timestamp timestamp;

  factory VideoResponseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VideoResponseModel(
      id: doc.id,
      username: data['username'] ?? '',
      description: data['description'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? '',
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      shareCount: data['shareCount'] ?? 0,
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }

  VideoEntity toEntity() => VideoEntity(
    id: id,
    username: username,
    description: description,
    videoUrl: videoUrl,
    profileImageUrl: profileImageUrl,
    likeCount: likeCount,
    commentCount: commentCount,
    shareCount: shareCount,
    timestamp: timestamp.toDate(),
  );
}
```

---

## ⚡ Performance Best Practices

### Video Performance
- **Max 3 video controllers** at once (current + 2 preloaded)
- **LRU disposal strategy** - dispose oldest when creating new
- **Immediate disposal** when video scrolls off-screen
- **Preload 2 videos ahead** for smooth scrolling
- **RepaintBoundary** around video player widget
- **Target: 60 FPS, <300MB memory**

### Widget Performance
- Use `const` constructors everywhere
- Proper `keys` for PageView items
- `BlocSelector` instead of `BlocBuilder` when possible
- Extract complex widgets to separate files

### Memory Management
```dart
class VideoController {
  // Max 3 controllers
  static const maxControllers = 3;
  final Map<int, VideoPlayerController> _controllers = {};

  void dispose(int index) {
    _controllers[index]?.dispose();
    _controllers.remove(index);
  }

  void disposeOldest() {
    if (_controllers.length >= maxControllers) {
      final oldest = _controllers.keys.first;
      dispose(oldest);
    }
  }
}
```

---

## 🔧 Dependency Injection

```dart
// lib/core/di/dependency_injector.dart
void injectionSetup() {
  // Core
  getIt.registerLazySingleton(() => FirebaseFirestore.instance);

  // Repositories
  getIt.registerLazySingleton<VideoFeedRepository>(
    () => VideoFeedRepositoryImpl(firestore: getIt()),
  );

  // UseCases
  getIt.registerLazySingleton(
    () => FetchVideosUseCase(repository: getIt()),
  );
  getIt.registerLazySingleton(
    () => FetchMoreVideosUseCase(repository: getIt()),
  );

  // Cubits (factory for new instances)
  getIt.registerFactory(
    () => VideoFeedCubit(
      fetchVideosUseCase: getIt(),
      fetchMoreVideosUseCase: getIt(),
    ),
  );
}
```

---

## 📁 File Organization

### Naming Convention
```
# Features
lib/features/[feature]/
  domain/
    entities/[feature]_entity.dart
    repositories/[feature]_repository.dart
    usecases/[action]_[feature]_usecase.dart
  data/
    models/response/[type]_response_model.dart
    repository_impl/[feature]_repository_impl.dart
  presentation/
    bloc/[feature]_cubit.dart
    bloc/[feature]_state.dart
    view/[feature]_view.dart
    view/widgets/[feature]_view_[widget].dart
```

### Example
```
lib/features/video_feed/
  domain/
    entities/video_entity.dart
    repositories/video_feed_repository.dart
    usecases/fetch_videos_usecase.dart
    usecases/fetch_more_videos_usecase.dart
  data/
    models/response/video_response_model.dart
    repository_impl/video_feed_repository_impl.dart
  presentation/
    bloc/video_feed_cubit.dart
    bloc/video_feed_state.dart
    view/video_feed_view.dart
    view/widgets/video_feed_view_item.dart
    view/widgets/video_feed_view_player.dart
```

---

## 🚫 STRICT RULES

### 1. NO Hardcoded Values
```dart
❌ SizedBox(height: 24)
❌ Container(width: 200)
❌ TextStyle(fontSize: 16)

✅ context.hSpace(24)
✅ Container(width: context.w(200))
✅ TextStyle(fontSize: context.fontSize(16))
```

### 2. NO Build Methods
```dart
❌ Widget _buildHeader() { ... }

✅ Create separate widget file:
   video_feed_view_header.dart
```

### 3. NO Exceptions in Business Logic
```dart
❌ throw Exception('Error');

✅ return const Left('Error message');
```

### 4. NO Cross-Layer Imports
```dart
❌ Domain importing Data or Presentation
❌ Data importing Presentation

✅ Domain is pure Dart (no external deps)
✅ Data imports Domain only
✅ Presentation imports Domain only
```

### 5. NO Video Controller Leaks
```dart
❌ Forgetting to dispose controllers

✅ @override
   void dispose() {
     _controller.dispose();
     super.dispose();
   }
```

### 6. MAX 3 Video Controllers
```dart
❌ Creating unlimited controllers

✅ Dispose oldest when creating new
✅ Keep current + 2 preloaded max
```

---

## 📋 Commands

```bash
# Analysis
fvm flutter analyze

# Dependencies
fvm flutter pub get

# Clean build (if needed)
fvm flutter clean
fvm flutter pub get
```

---

## 📚 Project Management

**ALWAYS check PROJECT_STATUS.md before starting work**

Contains:
- Current phase and progress
- Detailed task breakdowns
- Next steps
- Validation checklists

**Current Phase:** Phase 1 - Clean Architecture Conversion
**Timeline:** 9-13 sessions over 2-3 weeks

---

## 🎯 Success Criteria

### Must Have:
- [ ] Clean Architecture implemented correctly
- [ ] Zero hardcoded values (all responsive)
- [ ] 60 FPS video playback
- [ ] Memory < 300MB
- [ ] Interactive media feed working
- [ ] 0 analyzer warnings

### Nice to Have:
- [ ] More GitHub stars
- [ ] Job opportunities from showcase

---

## 🔄 Development Flow

### Creating a Feature:
1. Create domain layer (entities, repositories, usecases)
2. Create data layer (models, repository_impl)
3. Create presentation layer (bloc, view, widgets)
4. Register in DI
5. Test and validate

### Before Committing:
1. Run `fvm flutter analyze`
2. Fix all warnings
3. Test on device
4. Verify responsive values used

---

## 📝 Key Decisions

### Scope:
- Demo/showcase project (NOT production)
- No auth required
- Only video feed active (dashboard/profile are placeholders)
- Firebase/Firestore only (no other backend)

### Architecture:
- Feature-First, Layer-Within
- Either pattern for errors
- UseCases for business logic
- Keep it simple, don't over-engineer

### Performance:
- 60 FPS target
- <300MB memory target
- Max 3 video controllers
- Proper disposal critical

### Interactive Feature:
- 2-3 types: hotspot, poll, (quiz optional)
- Relative positioning (responsive)
- Time-based show/hide
- Simple but impressive

---

**Project Owner:** @alperefesahin
**Status:** Active Development - Architecture Transformation
**Next:** Start Phase 1 - Add fpdart & create feature structure
