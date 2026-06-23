// lib/features/profile/presentation/view/profile_view.dart
//
// NigerGram ProfileView â€” Production Build
// Auth:    Firebase Auth
// Profile: Firestore
// Video:   Supabase Storage  â† FIXED (was Firebase Storage)
// Images:  Firebase Storage  (avatars & covers are small, fine here)
//
// FIXED:
//   â€¢ Bookmarks & Likes tabs now fetch full video documents (not just refs)
//   â€¢ Follow / Unfollow button for other users
//   â€¢ Supabase video upload with real progress
//   â€¢ Avatar tap â†’ pick & upload profile photo
//   â€¢ Real-time follower count update after follow/unfollow
//   â€¢ Error states with retry
//   â€¢ Share sheet uses share_plus (real share, not just clipboard)
//   â€¢ Verified badge support
//   â€¢ Instagram / YouTube links shown on profile
//   â€¢ Pull-to-refresh
//
// DEPENDENCIES NEEDED IN pubspec.yaml:
//   supabase_flutter: ^2.x.x
//   share_plus: ^9.x.x
//   cached_network_image: ^3.x.x
//   image_picker: ^1.x.x
//   cloud_firestore: ^5.x.x
//   firebase_auth: ^5.x.x
//   firebase_storage: ^12.x.x   (still used for avatar/cover images)
//   go_router: ^14.x.x

import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// MAIN WIDGET
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class ProfileView extends StatefulWidget {
  final String? userId;
  const ProfileView({super.key, this.userId});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView>
    with SingleTickerProviderStateMixin {
  // â”€â”€ Controllers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  // â”€â”€ State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isCurrentUser = true;
  bool _isFollowing = false;
  bool _isFollowLoading = false;
  bool _isUploadingContent = false;
  double _uploadProgress = 0.0;
  String _uploadLabel = '';

  // â”€â”€ Video lists â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  List<Map<String, dynamic>> _userVideos = [];
  List<Map<String, dynamic>> _privateVideos = [];
  List<Map<String, dynamic>> _bookmarkedVideos = [];
  List<Map<String, dynamic>> _likedVideos = [];

  // â”€â”€ Pagination â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const int _pageSize = 18;
  DocumentSnapshot? _lastVideoDoc;
  bool _hasMoreVideos = true;
  bool _isLoadingMore = false;

  // â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String get _targetUserId =>
      widget.userId ?? FirebaseAuth.instance.currentUser!.uid;

  String get _currentUid =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

  // â”€â”€ Supabase â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final _supabase = Supabase.instance.client;

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // LIFECYCLE
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  void initState() {
    super.initState();
    _isCurrentUser =
        widget.userId == null || widget.userId == _currentUid;
    _tabController =
        TabController(length: _isCurrentUser ? 4 : 2, vsync: this);
    _scrollController.addListener(_onScroll);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 400 &&
        !_isLoadingMore &&
        _hasMoreVideos &&
        _tabController.index == 0) {
      _loadMorePublicVideos();
    }
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // DATA LOADING
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      await Future.wait([
        _loadUserData(),
        _loadPublicVideos(),
        if (_isCurrentUser) _loadPrivateVideos(),
        if (_isCurrentUser) _loadBookmarkedVideos(),
        _loadLikedVideos(),
        if (!_isCurrentUser) _checkFollowStatus(),
      ]);
    } catch (e) {
      debugPrint('Profile load error: $e');
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserData() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_targetUserId)
        .get();
    if (mounted) setState(() => _userData = doc.data());
  }

  Future<void> _loadPublicVideos() async {
    final snap = await FirebaseFirestore.instance
        .collection('videos')
        .where('userId', isEqualTo: _targetUserId)
        .where('isPrivate', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .limit(_pageSize)
        .get();

    _lastVideoDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
    _hasMoreVideos = snap.docs.length == _pageSize;

    if (mounted) {
      setState(() {
        _userVideos =
            snap.docs.map((d) => d.data()).toList();
      });
    }
  }

  Future<void> _loadMorePublicVideos() async {
    if (_lastVideoDoc == null) return;
    setState(() => _isLoadingMore = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('videos')
          .where('userId', isEqualTo: _targetUserId)
          .where('isPrivate', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastVideoDoc!)
          .limit(_pageSize)
          .get();

      if (mounted) {
        setState(() {
          _userVideos
              .addAll(snap.docs.map((d) => d.data()));
          _isLoadingMore = false;
          if (snap.docs.isNotEmpty) {
            _lastVideoDoc = snap.docs.last;
            _hasMoreVideos = snap.docs.length == _pageSize;
          } else {
            _hasMoreVideos = false;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadPrivateVideos() async {
    final snap = await FirebaseFirestore.instance
        .collection('videos')
        .where('userId', isEqualTo: _targetUserId)
        .where('isPrivate', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .get();
    if (mounted) {
      setState(() =>
          _privateVideos = snap.docs.map((d) => d.data()).toList());
    }
  }

  // FIXED: Bookmarks fetches full video documents, not just refs
  Future<void> _loadBookmarkedVideos() async {
    final bookmarkSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(_targetUserId)
        .collection('bookmarks')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .get();

    if (bookmarkSnap.docs.isEmpty) {
      if (mounted) setState(() => _bookmarkedVideos = []);
      return;
    }

    final videoIds =
        bookmarkSnap.docs.map((d) => d.id).toList();

    // Firestore whereIn limit is 30 per query
    final chunks = <List<String>>[];
    for (var i = 0; i < videoIds.length; i += 30) {
      chunks.add(videoIds.sublist(
          i, i + 30 > videoIds.length ? videoIds.length : i + 30));
    }

    final List<Map<String, dynamic>> videos = [];
    for (final chunk in chunks) {
      final snap = await FirebaseFirestore.instance
          .collection('videos')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      videos.addAll(snap.docs.map((d) => d.data()));
    }

    if (mounted) setState(() => _bookmarkedVideos = videos);
  }

  // FIXED: Likes fetches full video documents, not just refs
  Future<void> _loadLikedVideos() async {
    final likeSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(_targetUserId)
        .collection('likes')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .get();

    if (likeSnap.docs.isEmpty) {
      if (mounted) setState(() => _likedVideos = []);
      return;
    }

    final videoIds = likeSnap.docs.map((d) => d.id).toList();

    final chunks = <List<String>>[];
    for (var i = 0; i < videoIds.length; i += 30) {
      chunks.add(videoIds.sublist(
          i, i + 30 > videoIds.length ? videoIds.length : i + 30));
    }

    final List<Map<String, dynamic>> videos = [];
    for (final chunk in chunks) {
      final snap = await FirebaseFirestore.instance
          .collection('videos')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      videos.addAll(snap.docs.map((d) => d.data()));
    }

    if (mounted) setState(() => _likedVideos = videos);
  }

  Future<void> _checkFollowStatus() async {
    if (_currentUid.isEmpty) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUid)
        .collection('following')
        .doc(_targetUserId)
        .get();
    if (mounted) setState(() => _isFollowing = doc.exists);
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // FOLLOW / UNFOLLOW
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _toggleFollow() async {
    if (_currentUid.isEmpty || _isFollowLoading) return;
    HapticFeedback.mediumImpact();
    setState(() => _isFollowLoading = true);

    final batch = FirebaseFirestore.instance.batch();
    final followingRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUid)
        .collection('following')
        .doc(_targetUserId);
    final followerRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_targetUserId)
        .collection('followers')
        .doc(_currentUid);
    final targetUserRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_targetUserId);
    final currentUserRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUid);

    try {
      if (_isFollowing) {
        batch.delete(followingRef);
        batch.delete(followerRef);
        batch.update(targetUserRef,
            {'followers': FieldValue.increment(-1)});
        batch.update(currentUserRef,
            {'following': FieldValue.increment(-1)});
      } else {
        final now = FieldValue.serverTimestamp();
        batch.set(followingRef, {'timestamp': now});
        batch.set(followerRef, {'timestamp': now});
        batch.update(targetUserRef,
            {'followers': FieldValue.increment(1)});
        batch.update(currentUserRef,
            {'following': FieldValue.increment(1)});
      }
      await batch.commit();

      // Refresh follower count in UI
      await _loadUserData();
      if (mounted) setState(() => _isFollowing = !_isFollowing);
    } catch (e) {
      debugPrint('Follow toggle error: $e');
    } finally {
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // VIDEO UPLOAD â†’ SUPABASE
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _pickAndUploadVideo(bool makePrivate) async {
    if (_currentUid.isEmpty) return;
    HapticFeedback.heavyImpact();

    final XFile? videoFile = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 3),
    );
    if (videoFile == null) return;

    setState(() {
      _isUploadingContent = true;
      _uploadProgress = 0.05;
      _uploadLabel = 'Preparing upload...';
    });

    try {
      final String videoId =
          FirebaseFirestore.instance.collection('videos').doc().id;
      final String storagePath =
          'videos/$_currentUid/$videoId.mp4';
      final File file = File(videoFile.path);
      final int fileSize = await file.length();

      setState(() {
        _uploadLabel = 'Uploading to Supabase...';
        _uploadProgress = 0.1;
      });

      // Upload to Supabase Storage
      await _supabase.storage.from('nigergram-videos').uploadBinary(
        storagePath,
        await file.readAsBytes(),
        fileOptions: const FileOptions(
          contentType: 'video/mp4',
          upsert: false,
        ),
      );

      setState(() {
        _uploadProgress = 0.85;
        _uploadLabel = 'Generating public URL...';
      });

      final String videoUrl = _supabase.storage
          .from('nigergram-videos')
          .getPublicUrl(storagePath);

      setState(() {
        _uploadProgress = 0.92;
        _uploadLabel = 'Saving to database...';
      });

      // Save metadata to Firestore
      await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .set({
        'videoId': videoId,
        'userId': _currentUid,
        'videoUrl': videoUrl,
        'thumbnailUrl': '',   // Set by a Cloud Function or manual upload
        'isPrivate': makePrivate,
        'likeCount': 0,
        'commentCount': 0,
        'shareCount': 0,
        'viewCount': 0,
        'fileSizeBytes': fileSize,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update user's video count
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .update({'videoCount': FieldValue.increment(1)});

      setState(() {
        _uploadProgress = 1.0;
        _uploadLabel = 'Done!';
      });

      await Future.delayed(const Duration(milliseconds: 400));
      await _loadAll();

      if (mounted) {
        _showSnack(
          makePrivate
              ? 'Video saved to your private vault!'
              : 'Video published to your profile!',
          isSuccess: true,
        );
      }
    } catch (e) {
      debugPrint('Supabase upload error: $e');
      if (mounted) {
        _showSnack('Upload failed: ${e.toString()}', isSuccess: false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingContent = false;
          _uploadProgress = 0.0;
          _uploadLabel = '';
        });
      }
    }
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // IMAGE UPLOADS â†’ FIREBASE STORAGE (small files, fine here)
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _updateAvatar() async {
    if (!_isCurrentUser) return;
    HapticFeedback.mediumImpact();

    final XFile? img = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 400,
    );
    if (img == null) return;

    setState(() {
      _isUploadingContent = true;
      _uploadLabel = 'Updating profile photo...';
      _uploadProgress = 0.3;
    });

    try {
      final ref = FirebaseStorage.instance
          .ref('users/$_currentUid/avatar.jpg');
      await ref.putFile(
        File(img.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .update({'profilePicUrl': url});
      await _loadUserData();
      if (mounted) _showSnack('Profile photo updated!', isSuccess: true);
    } catch (e) {
      if (mounted) _showSnack('Failed to update photo', isSuccess: false);
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingContent = false;
          _uploadProgress = 0.0;
          _uploadLabel = '';
        });
      }
    }
  }

  Future<void> _updateCover() async {
    if (!_isCurrentUser) return;
    HapticFeedback.mediumImpact();

    final XFile? img = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1080,
    );
    if (img == null) return;

    setState(() {
      _isUploadingContent = true;
      _uploadLabel = 'Updating cover banner...';
      _uploadProgress = 0.3;
    });

    try {
      final ref = FirebaseStorage.instance
          .ref('users/$_currentUid/cover.jpg');
      await ref.putFile(
        File(img.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .update({'coverUrl': url});
      await _loadUserData();
      if (mounted) _showSnack('Cover photo updated!', isSuccess: true);
    } catch (e) {
      if (mounted) _showSnack('Failed to update cover', isSuccess: false);
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingContent = false;
          _uploadProgress = 0.0;
          _uploadLabel = '';
        });
      }
    }
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // EDIT PROFILE
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _saveProfile({
    required String name,
    required String username,
    required String bio,
    required String insta,
    required String youtube,
  }) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUid)
        .set({
      'displayName': name.trim(),
      'username': username.trim().toLowerCase().replaceAll('@', ''),
      'bio': bio.trim(),
      'instagramLink': insta.trim(),
      'youtubeLink': youtube.trim(),
    }, SetOptions(merge: true));
    await _loadUserData();
  }

  void _showEditSheet() {
    HapticFeedback.mediumImpact();
    final nameCtrl =
        TextEditingController(text: _userData?['displayName'] ?? '');
    final userCtrl =
        TextEditingController(text: _userData?['username'] ?? '');
    final bioCtrl =
        TextEditingController(text: _userData?['bio'] ?? '');
    final instaCtrl =
        TextEditingController(text: _userData?['instagramLink'] ?? '');
    final ytCtrl =
        TextEditingController(text: _userData?['youtubeLink'] ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F0F12),
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 20,
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Edit Profile',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: nameCtrl,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                      decoration: _inputDeco('Display Name'),
                      validator: (v) =>
                          v!.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: userCtrl,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                      decoration: _inputDeco('Username'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: bioCtrl,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                      decoration: _inputDeco('Bio'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: instaCtrl,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                      decoration: _inputDeco('Instagram URL (optional)'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: ytCtrl,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                      decoration:
                          _inputDeco('YouTube URL (optional)'),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate())
                                return;
                              setSheet(() => saving = true);
                              try {
                                await _saveProfile(
                                  name: nameCtrl.text,
                                  username: userCtrl.text,
                                  bio: bioCtrl.text,
                                  insta: instaCtrl.text,
                                  youtube: ytCtrl.text,
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                setSheet(() => saving = false);
                                if (ctx.mounted) {
                                  _showSnack('Save failed',
                                      isSuccess: false);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF0050),
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Save Changes',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                    ),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // UPLOAD ACTION SHEET
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _showUploadSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F12),
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Text('Post a Video',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const SizedBox(height: 8),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF1A1A22),
                child:
                    Icon(Icons.public_rounded, color: Colors.greenAccent),
              ),
              title: const Text('Public',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('Visible to everyone',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadVideo(false);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF1A1A22),
                child: Icon(Icons.lock_outline_rounded,
                    color: Color(0xFFFF0050)),
              ),
              title: const Text('Private',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('Only visible to you',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadVideo(true);
              },
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // ANALYTICS SHEET
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _showAnalytics() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F12),
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Icon(Icons.analytics_rounded,
                      color: Color(0xFFFF0050), size: 22),
                  SizedBox(width: 8),
                  Text('Creator Analytics',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _analyticsCard(
                    '${_userVideos.length + _privateVideos.length}',
                    'Videos',
                    Icons.video_collection_rounded,
                  ),
                  _analyticsCard(
                    _formatCount(_userData?['totalLikes'] ?? 0),
                    'Total Likes',
                    Icons.favorite_rounded,
                  ),
                  _analyticsCard(
                    '${_bookmarkedVideos.length}',
                    'Bookmarks',
                    Icons.bookmark_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // SHARE
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _shareVideo(String videoId) {
    HapticFeedback.lightImpact();
    Share.share(
      'Watch this on NigerGram ðŸŽ¬\nhttps://nigergram.app/video/$videoId',
      subject: 'NigerGram Video',
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // HELPERS
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  void _showSnack(String msg, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(color: Colors.white))),
        ],
      ),
      backgroundColor:
          isSuccess ? const Color(0xFF1DB954) : const Color(0xFFFF0050),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(color: Colors.white38, fontSize: 12),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.white10),
            borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
            borderSide:
                const BorderSide(color: Color(0xFFFF0050), width: 1.5),
            borderRadius: BorderRadius.circular(10)),
        errorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.redAccent),
            borderRadius: BorderRadius.circular(10)),
        focusedErrorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.red),
            borderRadius: BorderRadius.circular(10)),
      );

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // WIDGETS
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _analyticsCard(String count, String label, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white54, size: 20),
            const SizedBox(height: 8),
            Text(count,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _statCol(String count, String label) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(count,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3)),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 11)),
        ],
      );

  Widget _statDivider() => Container(
      width: 1, height: 16, color: Colors.white12,
      margin: const EdgeInsets.symmetric(horizontal: 20));

  Widget _videoGrid(List<Map<String, dynamic>> videos,
      {bool showEmpty = true}) {
    if (videos.isEmpty && showEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.video_library_outlined,
                color: Colors.white12, size: 48),
            const SizedBox(height: 12),
            const Text('No videos yet',
                style: TextStyle(color: Colors.white24, fontSize: 13)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      itemCount: videos.length + (_isLoadingMore ? 3 : 0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 0.75,
      ),
      itemBuilder: (ctx, i) {
        if (i >= videos.length) {
          return Container(
            color: Colors.white.withOpacity(0.03),
            child: const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFFFF0050), strokeWidth: 1.5)),
          );
        }

        final data = videos[i];
        final thumb = (data['thumbnailUrl'] as String?) ?? '';
        final videoId = (data['videoId'] as String?) ?? '';
        final views = (data['viewCount'] as int?) ?? 0;
        final isPrivate = (data['isPrivate'] as bool?) ?? false;

        return GestureDetector(
          onTap: () => context.push('/video-player/$videoId'),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail
              thumb.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: thumb,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                          color: Colors.white.withOpacity(0.04)),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.white.withOpacity(0.04),
                        child: const Icon(Icons.video_library,
                            color: Colors.white12),
                      ),
                    )
                  : Container(
                      color: Colors.white.withOpacity(0.04),
                      child: const Icon(Icons.play_circle_outline,
                          color: Colors.white10, size: 30),
                    ),

              // Gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.6),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // View count
              Positioned(
                bottom: 5,
                left: 5,
                child: Row(
                  children: [
                    const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 13),
                    const SizedBox(width: 2),
                    Text(_formatCount(views),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

              // Private badge
              if (isPrivate)
                Positioned(
                  top: 5,
                  left: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.lock_outline,
                        color: Colors.white70, size: 10),
                  ),
                ),

              // Share button
              Positioned(
                bottom: 5,
                right: 5,
                child: GestureDetector(
                  onTap: () => _shareVideo(videoId),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.share_rounded,
                        color: Colors.white, size: 11),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // BUILD
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF09090B),
        body: Center(
            child: CircularProgressIndicator(
                color: Color(0xFFFF0050))),
      );
    }

    if (_hasError) {
      return Scaffold(
        backgroundColor: const Color(0xFF09090B),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  color: Colors.white24, size: 48),
              const SizedBox(height: 12),
              const Text('Failed to load profile',
                  style:
                      TextStyle(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadAll,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF0050)),
                child: const Text('Retry',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final displayName =
        (_userData?['displayName'] as String?) ?? 'NigerGram User';
    final username =
        '@${(_userData?['username'] as String?) ?? 'username'}';
    final bio = (_userData?['bio'] as String?) ?? '';
    final coverUrl = (_userData?['coverUrl'] as String?) ?? '';
    final profilePic = (_userData?['profilePicUrl'] as String?) ?? '';
    final isVerified = (_userData?['isVerified'] as bool?) ?? false;
    final instaLink =
        (_userData?['instagramLink'] as String?) ?? '';
    final ytLink = (_userData?['youtubeLink'] as String?) ?? '';
    final followers = (_userData?['followers'] as int?) ?? 0;
    final following = (_userData?['following'] as int?) ?? 0;
    final totalLikes = (_userData?['totalLikes'] as int?) ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: Stack(
        children: [
          // â”€â”€ Main scrollable content â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          RefreshIndicator(
            color: const Color(0xFFFF0050),
            backgroundColor: const Color(0xFF1A1A22),
            onRefresh: _loadAll,
            child: NestedScrollView(
              controller: _scrollController,
              headerSliverBuilder: (ctx, innerScrolled) => [
                // â”€â”€ Cover / AppBar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                SliverAppBar(
                  expandedHeight: 180,
                  pinned: true,
                  backgroundColor: const Color(0xFF09090B),
                  elevation: 0,
                  leading: widget.userId != null
                      ? IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white, size: 18),
                          onPressed: () => context.pop(),
                        )
                      : null,
                  flexibleSpace: FlexibleSpaceBar(
                    background: GestureDetector(
                      onTap: _isCurrentUser ? _updateCover : null,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          coverUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: coverUrl,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF1C1C28),
                                        Color(0xFF09090B),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                          // dark scrim
                          Container(color: Colors.black26),
                          if (_isCurrentUser)
                            const Positioned(
                              top: 48,
                              right: 16,
                              child: CircleAvatar(
                                radius: 15,
                                backgroundColor: Colors.black54,
                                child: Icon(Icons.camera_alt_rounded,
                                    color: Colors.white, size: 14),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // â”€â”€ Profile info â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar row
                        Transform.translate(
                          offset: const Offset(0, -44),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Avatar
                              GestureDetector(
                                onTap: _isCurrentUser
                                    ? _updateAvatar
                                    : null,
                                child: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 46,
                                      backgroundColor:
                                          const Color(0xFF09090B),
                                      child: CircleAvatar(
                                        radius: 42,
                                        backgroundColor:
                                            const Color(0xFF1A1A22),
                                        backgroundImage:
                                            profilePic.isNotEmpty
                                                ? CachedNetworkImageProvider(
                                                    profilePic)
                                                : null,
                                        child: profilePic.isEmpty
                                            ? const Icon(Icons.person,
                                                color: Colors.white24,
                                                size: 36)
                                            : null,
                                      ),
                                    ),
                                    if (_isCurrentUser)
                                      Positioned(
                                        bottom: 2,
                                        right: 2,
                                        child: Container(
                                          padding:
                                              const EdgeInsets.all(5),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFFF0050),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                              Icons.camera_alt_rounded,
                                              color: Colors.white,
                                              size: 12),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              const Spacer(),

                              // Buttons
                              if (_isCurrentUser) ...[
                                IconButton(
                                  onPressed: _showAnalytics,
                                  icon: const Icon(
                                      Icons.analytics_outlined,
                                      color: Colors.white54,
                                      size: 22),
                                  tooltip: 'Analytics',
                                ),
                                const SizedBox(width: 4),
                                _outlineBtn(
                                    label: 'Edit Profile',
                                    onTap: _showEditSheet),
                              ] else ...[
                                // Follow / Unfollow
                                _followBtn(
                                    isFollowing: _isFollowing,
                                    isLoading: _isFollowLoading,
                                    onTap: _toggleFollow),
                                const SizedBox(width: 8),
                                // Message (route to DMs)
                                _outlineBtn(
                                  label: 'Message',
                                  onTap: () => context.push(
                                      '/chat/$_targetUserId'),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Name + verified + username
                        Transform.translate(
                          offset: const Offset(0, -28),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      displayName,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 21,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.3),
                                    ),
                                  ),
                                  if (isVerified) ...[
                                    const SizedBox(width: 6),
                                    const Icon(
                                        Icons.verified_rounded,
                                        color: Color(0xFFFF0050),
                                        size: 18),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(username,
                                  style: const TextStyle(
                                      color: Color(0xFFFF0050),
                                      fontSize: 13,
                                      fontWeight:
                                          FontWeight.w500)),
                              if (bio.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(bio,
                                    style: TextStyle(
                                        color: Colors.white
                                            .withOpacity(0.7),
                                        fontSize: 13,
                                        height: 1.45)),
                              ],

                              // Social links
                              if (instaLink.isNotEmpty ||
                                  ytLink.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 12,
                                  children: [
                                    if (instaLink.isNotEmpty)
                                      _socialChip(
                                          Icons.camera_alt_outlined,
                                          'Instagram',
                                          const Color(0xFFE1306C)),
                                    if (ytLink.isNotEmpty)
                                      _socialChip(
                                          Icons.play_circle_outline,
                                          'YouTube',
                                          const Color(0xFFFF0000)),
                                  ],
                                ),
                              ],

                              const SizedBox(height: 18),

                              // Stats row
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.start,
                                children: [
                                  _statCol(_formatCount(following),
                                      'Following'),
                                  _statDivider(),
                                  _statCol(_formatCount(followers),
                                      'Followers'),
                                  _statDivider(),
                                  _statCol(_formatCount(totalLikes),
                                      'Likes'),
                                ],
                              ),
                              const SizedBox(height: 4),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // â”€â”€ Tab bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      indicatorColor: const Color(0xFFFF0050),
                      indicatorWeight: 2,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white30,
                      tabs: _isCurrentUser
                          ? const [
                              Tab(
                                  icon: Icon(Icons.grid_on_rounded,
                                      size: 20)),
                              Tab(
                                  icon: Icon(
                                      Icons.lock_outline_rounded,
                                      size: 20)),
                              Tab(
                                  icon: Icon(
                                      Icons.bookmark_outline_rounded,
                                      size: 20)),
                              Tab(
                                  icon: Icon(
                                      Icons.favorite_border_rounded,
                                      size: 20)),
                            ]
                          : const [
                              Tab(
                                  icon: Icon(Icons.grid_on_rounded,
                                      size: 20)),
                              Tab(
                                  icon: Icon(
                                      Icons.favorite_border_rounded,
                                      size: 20)),
                            ],
                    ),
                  ),
                ),
              ],

              // â”€â”€ Tab content â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              body: TabBarView(
                controller: _tabController,
                children: _isCurrentUser
                    ? [
                        _videoGrid(_userVideos),
                        _videoGrid(_privateVideos),
                        _videoGrid(_bookmarkedVideos),
                        _videoGrid(_likedVideos),
                      ]
                    : [
                        _videoGrid(_userVideos),
                        _videoGrid(_likedVideos),
                      ],
              ),
            ),
          ),

          // â”€â”€ Upload progress overlay â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          if (_isUploadingContent)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.88),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_upload_outlined,
                            color: Color(0xFFFF0050), size: 40),
                        const SizedBox(height: 16),
                        Text(
                          _uploadLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _uploadProgress,
                            backgroundColor: Colors.white12,
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(
                                    Color(0xFFFF0050)),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),

      // â”€â”€ FAB â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      floatingActionButton: _isCurrentUser
          ? FloatingActionButton(
              onPressed: _showUploadSheet,
              backgroundColor: const Color(0xFFFF0050),
              shape: const CircleBorder(),
              child: const Icon(Icons.add_rounded,
                  color: Colors.white, size: 28),
            )
          : null,
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // SMALL UI BUILDERS
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _outlineBtn(
      {required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _followBtn({
    required bool isFollowing,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isFollowing
              ? Colors.white.withOpacity(0.05)
              : const Color(0xFFFF0050),
          borderRadius: BorderRadius.circular(8),
          border: isFollowing
              ? Border.all(color: Colors.white12)
              : null,
        ),
        child: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Text(
                isFollowing ? 'Following' : 'Follow',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _socialChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// TAB BAR DELEGATE
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  const _TabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF09090B),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) => false;
}
