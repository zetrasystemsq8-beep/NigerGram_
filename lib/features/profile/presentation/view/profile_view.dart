// lib/features/profile/presentation/view/profile_view.dart
import 'dart:io';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM
// ─────────────────────────────────────────────────────────────────────────────

class NGColors {
  static const background = Color(0xFF000000);
  static const surface = Color(0xFF0F0F14);
  static const surfaceLight = Color(0xFF1A1A24);
  static const accent = Color(0xFFFF0050);
  static const accentGold = Color(0xFFFFD700);
  static const accentBlue = Color(0xFF0088FF);
  static const accentPurple = Color(0xFF8B00FF);
  static const accentGreen = Color(0xFF00C853);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB0B0B8);
  static const textMuted = Color(0xFF6A6A74);
  static const divider = Color(0xFF1E1E28);
  static const success = Color(0xFF00C853);
  static const error = Color(0xFFFF1744);
  static const warning = Color(0xFFFFD600);
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class ProfileView extends StatefulWidget {
  final String? userId;
  const ProfileView({super.key, this.userId});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> with TickerProviderStateMixin {
  
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  
  late AnimationController _storyPulseController;
  late Animation<double> _storyPulseAnimation;
  late AnimationController _storyRotateController;
  late Animation<double> _storyRotateAnimation;
  
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _walletData;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isCurrentUser = true;
  bool _isFollowing = false;
  bool _isBlocked = false;
  bool _isFollowLoading = false;
  bool _isUploadingContent = false;
  double _uploadProgress = 0.0;
  String _uploadLabel = '';
  bool _isTabLoading = false;
  bool _hasActiveStory = false;
  int _storyCount = 0;
  double _walletBalance = 0.0;
  String _walletCurrency = 'NGN';
  String _profileTheme = 'default';
  Color _accentColor = NGColors.accent;
  List<Map<String, dynamic>> _achievements = [];
  bool _allowDuet = true;
  bool _allowStitch = true;
  bool _allowDownload = true;
  
  // NEW: Story Highlights
  List<Map<String, dynamic>> _storyHighlights = [];
  
  // NEW: Bio Links
  List<Map<String, dynamic>> _bioLinks = [];
  
  List<Map<String, dynamic>> _pinnedVideos = [];
  List<Map<String, dynamic>> _userVideos = [];
  List<Map<String, dynamic>> _privateVideos = [];
  List<Map<String, dynamic>> _bookmarkedVideos = [];
  List<Map<String, dynamic>> _likedVideos = [];
  List<Map<String, dynamic>> _draftVideos = [];
  List<Map<String, dynamic>> _qaItems = [];
  
  static const int _pageSize = 18;
  DocumentSnapshot? _lastVideoDoc;
  bool _hasMoreVideos = true;
  bool _isLoadingMore = false;
  
  String get _targetUserId =>
      widget.userId ?? FirebaseAuth.instance.currentUser!.uid;
  String get _currentUid =>
      FirebaseAuth.instance.currentUser?.uid ?? '';
  final _supabase = Supabase.instance.client;
  
  // ─────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────
  
  @override
  void initState() {
    super.initState();
    _isCurrentUser = widget.userId == null || widget.userId == _currentUid;
    
    _storyPulseController = AnimationController(
      duration: const Duration(milliseconds: 1500), vsync: this,
    )..repeat(reverse: true);
    _storyPulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _storyPulseController, curve: Curves.easeInOut),
    );
    
    _storyRotateController = AnimationController(
      duration: const Duration(seconds: 8), vsync: this,
    )..repeat();
    _storyRotateAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(_storyRotateController);
    
    _tabController = TabController(length: _isCurrentUser ? 6 : 5, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    _loadAll();
  }
  
  @override
  void dispose() {
    _storyPulseController.dispose();
    _storyRotateController.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _onTabChanged() {
    if (!_tabController.indexIsChanging) setState(() {});
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 400 &&
        !_isLoadingMore && _hasMoreVideos && _tabController.index == 0) {
      _loadMorePublicVideos();
    }
  }
  
  void _applyTheme() {
    switch (_profileTheme) {
      case 'gold': _accentColor = NGColors.accentGold; break;
      case 'blue': _accentColor = NGColors.accentBlue; break;
      case 'purple': _accentColor = NGColors.accentPurple; break;
      case 'green': _accentColor = NGColors.accentGreen; break;
      default: _accentColor = NGColors.accent;
    }
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // DATA LOADING - UPDATED with Highlights & Bio Links
  // ─────────────────────────────────────────────────────────────────────────
  
  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _hasError = false; });
    try {
      await _loadUserData();
      if (_userData == null && !_isCurrentUser) throw Exception("User not found");
      if (_userData?['profileTheme'] != null) {
        _profileTheme = _userData!['profileTheme'];
        _applyTheme();
      }
      _allowDuet = _userData?['allowDuet'] ?? true;
      _allowStitch = _userData?['allowStitch'] ?? true;
      _allowDownload = _userData?['allowDownload'] ?? true;
      
      await Future.wait([
        if (_isCurrentUser) _loadWalletBalance().catchError((_) {}),
        _loadPinnedVideos().catchError((_) {}),
        _loadPublicVideos().catchError((_) {}),
        if (_isCurrentUser) _loadPrivateVideos().catchError((_) {}),
        if (_isCurrentUser) _loadBookmarkedVideos().catchError((_) {}),
        if (_isCurrentUser) _loadDrafts().catchError((_) {}),
        if (_isCurrentUser) _loadQAItems().catchError((_) {}),
        _loadLikedVideos().catchError((_) {}),
        if (!_isCurrentUser) _checkFollowStatus().catchError((_) {}),
        if (!_isCurrentUser) _checkBlockStatus().catchError((_) {}),
        _checkStoryStatus().catchError((_) {}),
        _loadAchievements().catchError((_) {}),
        // NEW: Load story highlights
        _loadStoryHighlights().catchError((_) {}),
        // NEW: Load bio links from user data
        _loadBioLinks().catchError((_) {}),
      ]);
    } catch (e) {
      debugPrint('Profile load error: $e');
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // NEW: STORY HIGHLIGHTS
  // ─────────────────────────────────────────────────────────────────────────
  
  Future<void> _loadStoryHighlights() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(_targetUserId)
        .collection('story_highlights')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .get();
    
    if (mounted) {
      setState(() {
        _storyHighlights = snap.docs.map((d) => d.data()).toList();
      });
    }
  }
  
  Future<void> _addStoryHighlight(String storyId, String thumbnailUrl, String title) async {
    if (!_isCurrentUser) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .collection('story_highlights')
          .add({
        'storyId': storyId,
        'thumbnailUrl': thumbnailUrl,
        'title': title,
        'timestamp': FieldValue.serverTimestamp(),
      });
      await _loadStoryHighlights();
      if (mounted) _showSnack('Story added to highlights!', isSuccess: true);
    } catch (e) {
      if (mounted) _showSnack('Failed to add highlight', isSuccess: false);
    }
  }
  
  Future<void> _removeStoryHighlight(String highlightId) async {
    if (!_isCurrentUser) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .collection('story_highlights')
          .doc(highlightId)
          .delete();
      await _loadStoryHighlights();
      if (mounted) _showSnack('Highlight removed', isSuccess: true);
    } catch (e) {
      if (mounted) _showSnack('Failed to remove highlight', isSuccess: false);
    }
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // NEW: BIO LINKS
  // ─────────────────────────────────────────────────────────────────────────
  
  Future<void> _loadBioLinks() async {
    // Bio links are stored in the user document
    final bioLinks = _userData?['bioLinks'] as List<dynamic>? ?? [];
    if (mounted) {
      setState(() {
        _bioLinks = bioLinks.map((link) => {
          'url': link['url'] ?? '',
          'title': link['title'] ?? 'Link',
          'icon': link['icon'] ?? '🌐',
        }).toList();
      });
    }
  }
  
  Future<void> _addBioLink(String url, String title, String icon) async {
    if (!_isCurrentUser) return;
    
    try {
      final newLink = {'url': url, 'title': title, 'icon': icon};
      final updatedLinks = List<Map<String, dynamic>>.from(_bioLinks)..add(newLink);
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .update({'bioLinks': updatedLinks});
      
      await _loadBioLinks();
      if (mounted) _showSnack('Link added to bio!', isSuccess: true);
    } catch (e) {
      if (mounted) _showSnack('Failed to add link', isSuccess: false);
    }
  }
  
  Future<void> _removeBioLink(int index) async {
    if (!_isCurrentUser) return;
    
    try {
      final updatedLinks = List<Map<String, dynamic>>.from(_bioLinks)..removeAt(index);
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .update({'bioLinks': updatedLinks});
      
      await _loadBioLinks();
      if (mounted) _showSnack('Link removed', isSuccess: true);
    } catch (e) {
      if (mounted) _showSnack('Failed to remove link', isSuccess: false);
    }
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // EXISTING DATA LOADING METHODS
  // ─────────────────────────────────────────────────────────────────────────
  
  Future<void> _refreshCurrentTab() async {
    setState(() => _isTabLoading = true);
    try {
      switch (_tabController.index) {
        case 0: await _loadPublicVideos(); break;
        case 1: await _loadPinnedVideos(); break;
        case 2: if (_isCurrentUser) await _loadPrivateVideos(); else await _loadBookmarkedVideos(); break;
        case 3: if (_isCurrentUser) await _loadQAItems(); else await _loadLikedVideos(); break;
        case 4: if (_isCurrentUser) await _loadDrafts(); else await _loadBookmarkedVideos(); break;
        case 5: if (_isCurrentUser) await _loadLikedVideos(); break;
      }
    } finally {
      if (mounted) setState(() => _isTabLoading = false);
    }
  }
  
  Future<void> _loadUserData() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(_targetUserId).get();
    if (mounted) setState(() => _userData = doc.data());
  }
  
  Future<void> _loadWalletBalance() async {
    if (!_isCurrentUser) return;
    final doc = await FirebaseFirestore.instance.collection('wallets').doc(_currentUid).get();
    if (doc.exists && mounted) {
      final data = doc.data()!;
      setState(() {
        _walletData = data;
        _walletBalance = (data['balance'] ?? 0.0).toDouble();
        _walletCurrency = data['currency'] ?? 'NGN';
      });
    }
  }
  
  Future<void> _checkStoryStatus() async {
    final snap = await FirebaseFirestore.instance
        .collection('users').doc(_targetUserId).collection('stories')
        .where('expiresAt', isGreaterThan: DateTime.now().millisecondsSinceEpoch)
        .limit(1).get();
    if (mounted) setState(() {
      _hasActiveStory = snap.docs.isNotEmpty;
      _storyCount = snap.docs.length;
    });
  }
  
  Future<void> _loadAchievements() async {
    final snap = await FirebaseFirestore.instance
        .collection('users').doc(_targetUserId).collection('achievements').limit(10).get();
    if (mounted) setState(() => _achievements = snap.docs.map((d) => d.data()).toList());
  }
  
  Future<void> _loadPinnedVideos() async {
    final snap = await FirebaseFirestore.instance
        .collection('videos').where('userId', isEqualTo: _targetUserId)
        .where('isPinned', isEqualTo: true).orderBy('timestamp', descending: true).limit(3).get();
    if (mounted) setState(() => _pinnedVideos = snap.docs.map((d) => d.data()).toList());
  }
  
  Future<void> _loadPublicVideos() async {
    final snap = await FirebaseFirestore.instance
        .collection('videos').where('userId', isEqualTo: _targetUserId)
        .where('isPrivate', isEqualTo: false).orderBy('timestamp', descending: true).limit(_pageSize).get();
    _lastVideoDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
    _hasMoreVideos = snap.docs.length == _pageSize;
    if (mounted) setState(() => _userVideos = snap.docs.map((d) => d.data()).toList());
  }
  
  Future<void> _loadMorePublicVideos() async {
    if (_lastVideoDoc == null || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('videos').where('userId', isEqualTo: _targetUserId)
          .where('isPrivate', isEqualTo: false).orderBy('timestamp', descending: true)
          .startAfterDocument(_lastVideoDoc!).limit(_pageSize).get();
      if (mounted) setState(() {
        _userVideos.addAll(snap.docs.map((d) => d.data()));
        _isLoadingMore = false;
        if (snap.docs.isNotEmpty) {
          _lastVideoDoc = snap.docs.last;
          _hasMoreVideos = snap.docs.length == _pageSize;
        } else {
          _hasMoreVideos = false;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }
  
  Future<void> _loadPrivateVideos() async {
    final snap = await FirebaseFirestore.instance
        .collection('videos').where('userId', isEqualTo: _targetUserId)
        .where('isPrivate', isEqualTo: true).orderBy('timestamp', descending: true).get();
    if (mounted) setState(() => _privateVideos = snap.docs.map((d) => d.data()).toList());
  }
  
  Future<void> _loadBookmarkedVideos() async {
    final bookmarkSnap = await FirebaseFirestore.instance
        .collection('users').doc(_targetUserId).collection('bookmarks')
        .orderBy('timestamp', descending: true).limit(50).get();
    if (bookmarkSnap.docs.isEmpty) {
      if (mounted) setState(() => _bookmarkedVideos = []);
      return;
    }
    final videoIds = bookmarkSnap.docs.map((d) => d.id).toList();
    final chunks = <List<String>>[];
    for (var i = 0; i < videoIds.length; i += 30) {
      chunks.add(videoIds.sublist(i, i + 30 > videoIds.length ? videoIds.length : i + 30));
    }
    final List<Map<String, dynamic>> videos = [];
    for (final chunk in chunks) {
      final snap = await FirebaseFirestore.instance
          .collection('videos').where(FieldPath.documentId, whereIn: chunk).get();
      videos.addAll(snap.docs.map((d) => d.data()));
    }
    if (mounted) setState(() => _bookmarkedVideos = videos);
  }
  
  Future<void> _loadLikedVideos() async {
    final likeSnap = await FirebaseFirestore.instance
        .collection('users').doc(_targetUserId).collection('likes')
        .orderBy('timestamp', descending: true).limit(50).get();
    if (likeSnap.docs.isEmpty) {
      if (mounted) setState(() => _likedVideos = []);
      return;
    }
    final videoIds = likeSnap.docs.map((d) => d.id).toList();
    final chunks = <List<String>>[];
    for (var i = 0; i < videoIds.length; i += 30) {
      chunks.add(videoIds.sublist(i, i + 30 > videoIds.length ? videoIds.length : i + 30));
    }
    final List<Map<String, dynamic>> videos = [];
    for (final chunk in chunks) {
      final snap = await FirebaseFirestore.instance
          .collection('videos').where(FieldPath.documentId, whereIn: chunk).get();
      videos.addAll(snap.docs.map((d) => d.data()));
    }
    if (mounted) setState(() => _likedVideos = videos);
  }
  
  Future<void> _loadDrafts() async {
    final snap = await FirebaseFirestore.instance
        .collection('users').doc(_targetUserId).collection('drafts')
        .orderBy('timestamp', descending: true).get();
    if (mounted) setState(() => _draftVideos = snap.docs.map((d) => d.data()).toList());
  }
  
  Future<void> _loadQAItems() async {
    final snap = await FirebaseFirestore.instance
        .collection('users').doc(_targetUserId).collection('qa')
        .orderBy('timestamp', descending: true).limit(50).get();
    if (mounted) setState(() => _qaItems = snap.docs.map((d) => d.data()).toList());
  }
  
  Future<void> _checkFollowStatus() async {
    if (_currentUid.isEmpty) return;
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(_currentUid).collection('following').doc(_targetUserId).get();
    if (mounted) setState(() => _isFollowing = doc.exists);
  }
  
  Future<void> _checkBlockStatus() async {
    if (_currentUid.isEmpty) return;
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(_currentUid).collection('blocked').doc(_targetUserId).get();
    if (mounted) setState(() => _isBlocked = doc.exists);
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // FOLLOW / UNFOLLOW
  // ─────────────────────────────────────────────────────────────────────────
  
  Future<void> _toggleFollow() async {
    if (_currentUid.isEmpty || _isFollowLoading) return;
    HapticFeedback.mediumImpact();
    setState(() => _isFollowLoading = true);
    final batch = FirebaseFirestore.instance.batch();
    final followingRef = FirebaseFirestore.instance.collection('users').doc(_currentUid).collection('following').doc(_targetUserId);
    final followerRef = FirebaseFirestore.instance.collection('users').doc(_targetUserId).collection('followers').doc(_currentUid);
    final targetUserRef = FirebaseFirestore.instance.collection('users').doc(_targetUserId);
    final currentUserRef = FirebaseFirestore.instance.collection('users').doc(_currentUid);
    try {
      if (_isFollowing) {
        batch.delete(followingRef);
        batch.delete(followerRef);
        batch.update(targetUserRef, {'followers': FieldValue.increment(-1)});
        batch.update(currentUserRef, {'following': FieldValue.increment(-1)});
      } else {
        final now = FieldValue.serverTimestamp();
        batch.set(followingRef, {'timestamp': now});
        batch.set(followerRef, {'timestamp': now});
        batch.update(targetUserRef, {'followers': FieldValue.increment(1)});
        batch.update(currentUserRef, {'following': FieldValue.increment(1)});
      }
      await batch.commit();
      await _loadUserData();
      if (mounted) setState(() => _isFollowing = !_isFollowing);
    } catch (e) {
      debugPrint('Follow error: $e');
    } finally {
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // BLOCK / REPORT
  // ─────────────────────────────────────────────────────────────────────────
  
  Future<void> _toggleBlock() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NGColors.surface,
        title: Text(_isBlocked ? 'Unblock User?' : 'Block User?', style: const TextStyle(color: NGColors.textPrimary)),
        content: Text(_isBlocked ? 'They will be able to see your profile and interact again.' : 'They won\'t be able to see your profile, message you, or interact with your content.', style: const TextStyle(color: NGColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: NGColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_isBlocked ? 'Unblock' : 'Block', style: const TextStyle(color: NGColors.error))),
        ],
      ),
    );
    if (confirm != true) return;
    HapticFeedback.heavyImpact();
    try {
      if (_isBlocked) {
        await FirebaseFirestore.instance.collection('users').doc(_currentUid).collection('blocked').doc(_targetUserId).delete();
      } else {
        await FirebaseFirestore.instance.collection('users').doc(_currentUid).collection('blocked').doc(_targetUserId).set({'timestamp': FieldValue.serverTimestamp()});
        if (_isFollowing) await _toggleFollow();
      }
      if (mounted) setState(() => _isBlocked = !_isBlocked);
    } catch (e) {
      debugPrint('Block error: $e');
    }
  }
  
  Future<void> _reportProfile() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NGColors.surface,
        title: const Text('Report Profile', style: TextStyle(color: NGColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _reportOption(ctx, 'Inappropriate Content'),
            _reportOption(ctx, 'Spam / Fake Account'),
            _reportOption(ctx, 'Harassment'),
            _reportOption(ctx, 'Impersonation'),
            _reportOption(ctx, 'Other'),
          ],
        ),
      ),
    );
    if (reason != null) {
      await FirebaseFirestore.instance.collection('reports').add({
        'reportedUserId': _targetUserId,
        'reportedBy': _currentUid,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      if (mounted) _showSnack('Report submitted. Thank you!', isSuccess: true);
    }
  }
  
  Widget _reportOption(BuildContext ctx, String text) {
    return ListTile(
      title: Text(text, style: const TextStyle(color: NGColors.textPrimary)),
      onTap: () => Navigator.pop(ctx, text),
    );
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // VIDEO UPLOAD
  // ─────────────────────────────────────────────────────────────────────────
  
  Future<void> _pickAndUploadVideo(bool makePrivate) async {
    if (_currentUid.isEmpty) return;
    HapticFeedback.heavyImpact();
    final XFile? videoFile = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 3));
    if (videoFile == null) return;
    final File file = File(videoFile.path);
    final int fileSize = await file.length();
    const int maxSizeBytes = 100 * 1024 * 1024;
    if (fileSize > maxSizeBytes) {
      if (mounted) _showSnack('Video too large (${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB). Max 100MB.', isSuccess: false);
      return;
    }
    setState(() { _isUploadingContent = true; _uploadProgress = 0.05; _uploadLabel = 'Preparing upload...'; });
    try {
      final String videoId = FirebaseFirestore.instance.collection('videos').doc().id;
      final String storagePath = 'videos/$_currentUid/$videoId.mp4';
      setState(() { _uploadLabel = 'Uploading to Supabase...'; _uploadProgress = 0.1; });
      await _supabase.storage.from('videos').uploadBinary(
        storagePath, await file.readAsBytes(),
        fileOptions: const FileOptions(contentType: 'video/mp4', upsert: false),
      );
      setState(() { _uploadProgress = 0.85; _uploadLabel = 'Generating CDN URL...'; });
      final String videoUrl = _supabase.storage.from('videos').getPublicUrl(storagePath);
      setState(() { _uploadProgress = 0.92; _uploadLabel = 'Saving to database...'; });
      await FirebaseFirestore.instance.collection('videos').doc(videoId).set({
        'videoId': videoId, 'userId': _currentUid, 'videoUrl': videoUrl,
        'thumbnailUrl': '', 'isPrivate': makePrivate, 'isPinned': false,
        'allowDuet': _allowDuet, 'allowStitch': _allowStitch, 'allowDownload': _allowDownload,
        'likeCount': 0, 'commentCount': 0, 'shareCount': 0, 'viewCount': 0,
        'fileSizeBytes': fileSize, 'timestamp': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance.collection('users').doc(_currentUid).update({'videoCount': FieldValue.increment(1)});
      setState(() { _uploadProgress = 1.0; _uploadLabel = 'Upload complete!'; });
      await Future.delayed(const Duration(milliseconds: 400));
      await _loadAll();
      if (mounted) _showSnack(makePrivate ? 'Saved to private vault!' : 'Published to your profile!', isSuccess: true);
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) _showSnack('Upload failed', isSuccess: false);
    } finally {
      if (mounted) setState(() { _isUploadingContent = false; _uploadProgress = 0.0; _uploadLabel = ''; });
    }
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // DELETE & PIN VIDEO
  // ─────────────────────────────────────────────────────────────────────────
  
  Future<void> _deleteVideo(String videoId) async {
    HapticFeedback.mediumImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NGColors.surface,
        title: const Text('Delete Video', style: TextStyle(color: NGColors.textPrimary)),
        content: const Text('This cannot be undone.', style: TextStyle(color: NGColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: NGColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: NGColors.error))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance.collection('videos').doc(videoId).delete();
      try { await _supabase.storage.from('videos').remove(['videos/$_currentUid/$videoId.mp4']); } catch (_) {}
      await FirebaseFirestore.instance.collection('users').doc(_currentUid).update({'videoCount': FieldValue.increment(-1)});
      await _loadAll();
      if (mounted) _showSnack('Video deleted', isSuccess: true);
    } catch (e) {
      if (mounted) _showSnack('Failed to delete', isSuccess: false);
    }
  }
  
  Future<void> _togglePinVideo(String videoId, bool currentlyPinned) async {
    await FirebaseFirestore.instance.collection('videos').doc(videoId).update({'isPinned': !currentlyPinned});
    await _loadPinnedVideos();
    if (mounted) _showSnack(currentlyPinned ? 'Removed from pinned' : 'Pinned to profile!', isSuccess: true);
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // AVATAR & COVER - SUPABASE
  // ─────────────────────────────────────────────────────────────────────────
  
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
      _uploadLabel = 'Uploading photo...';
      _uploadProgress = 0.3;
    });

    try {
      final file = File(img.path);
      final String filePath = '$_currentUid/avatar.jpg';
      
      await _supabase.storage
          .from('images')
          .uploadBinary(
            filePath, 
            await file.readAsBytes(),
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      final String url = _supabase.storage
          .from('images')
          .getPublicUrl(filePath);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .update({'profilePicUrl': url});

      await _loadUserData();
      if (mounted) _showSnack('Profile photo updated!', isSuccess: true);
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) _showSnack('Failed to update photo', isSuccess: false);
    } finally {
      if (mounted) setState(() {
        _isUploadingContent = false;
        _uploadProgress = 0.0;
        _uploadLabel = '';
      });
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
      _uploadLabel = 'Uploading cover...';
      _uploadProgress = 0.3;
    });

    try {
      final file = File(img.path);
      final String filePath = 'users/$_currentUid/cover.jpg';
      
      await _supabase.storage
          .from('images')
          .uploadBinary(
            filePath, 
            await file.readAsBytes(),
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      final String url = _supabase.storage
          .from('images')
          .getPublicUrl(filePath);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .update({'coverUrl': url});

      await _loadUserData();
      if (mounted) _showSnack('Cover updated!', isSuccess: true);
    } catch (e) {
      debugPrint('Cover upload error: $e');
      if (mounted) _showSnack('Failed to update cover', isSuccess: false);
    } finally {
      if (mounted) setState(() {
        _isUploadingContent = false;
        _uploadProgress = 0.0;
        _uploadLabel = '';
      });
    }
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // EDIT PROFILE
  // ─────────────────────────────────────────────────────────────────────────
  
  Future<void> _saveProfile({
    required String name, required String username, required String bio,
    required String insta, required String youtube, required String theme,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(_currentUid).set({
      'displayName': name.trim(),
      'username': username.trim().toLowerCase().replaceAll('@', ''),
      'bio': bio.trim(),
      'instagramLink': insta.trim(),
      'youtubeLink': youtube.trim(),
      'profileTheme': theme,
    }, SetOptions(merge: true));
    await _loadAll();
  }
  
  void _showEditSheet() {
    HapticFeedback.mediumImpact();
    final nameCtrl = TextEditingController(text: _userData?['displayName'] ?? '');
    final userCtrl = TextEditingController(text: _userData?['username'] ?? '');
    final bioCtrl = TextEditingController(text: _userData?['bio'] ?? '');
    final instaCtrl = TextEditingController(text: _userData?['instagramLink'] ?? '');
    final ytCtrl = TextEditingController(text: _userData?['youtubeLink'] ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;
    
    final ValueNotifier<String> selectedTheme = ValueNotifier(_profileTheme);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NGColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 20),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: NGColors.divider, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 20),
                    const Text('Edit Profile', style: TextStyle(color: NGColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    TextFormField(controller: nameCtrl, style: const TextStyle(color: NGColors.textPrimary, fontSize: 14), decoration: _inputDeco('Display Name'), validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                    const SizedBox(height: 12),
                    TextFormField(controller: userCtrl, style: const TextStyle(color: NGColors.textPrimary, fontSize: 14), decoration: _inputDeco('Username')),
                    const SizedBox(height: 12),
                    TextFormField(controller: bioCtrl, style: const TextStyle(color: NGColors.textPrimary, fontSize: 14), decoration: _inputDeco('Bio'), maxLines: 3),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: instaCtrl,
                      style: const TextStyle(color: NGColors.textPrimary, fontSize: 14),
                      decoration: _inputDeco('Instagram (username or URL)'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        final trimmed = value.trim();
                        if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
                          try {
                            Uri.parse(trimmed);
                            return null;
                          } catch (_) {
                            return 'Invalid URL format';
                          }
                        }
                        if (RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(trimmed)) {
                          return null;
                        }
                        return 'Enter a valid username or URL';
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: ytCtrl,
                      style: const TextStyle(color: NGColors.textPrimary, fontSize: 14),
                      decoration: _inputDeco('YouTube (URL or channel handle)'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        final trimmed = value.trim();
                        if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
                          try {
                            Uri.parse(trimmed);
                            return null;
                          } catch (_) {
                            return 'Invalid URL format';
                          }
                        }
                        if (RegExp(r'^@?[a-zA-Z0-9_-]+$').hasMatch(trimmed)) {
                          return null;
                        }
                        return 'Enter a valid YouTube URL or handle';
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Profile Theme', style: TextStyle(color: NGColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<String>(
                      valueListenable: selectedTheme,
                      builder: (context, theme, _) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _themeOption(setSheet, selectedTheme, 'default', 'Default', NGColors.accent),
                            _themeOption(setSheet, selectedTheme, 'gold', 'Gold', NGColors.accentGold),
                            _themeOption(setSheet, selectedTheme, 'blue', 'Blue', NGColors.accentBlue),
                            _themeOption(setSheet, selectedTheme, 'purple', 'Purple', NGColors.accentPurple),
                            _themeOption(setSheet, selectedTheme, 'green', 'Green', NGColors.accentGreen),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: saving ? null : () async {
                        if (!formKey.currentState!.validate()) return;
                        setSheet(() => saving = true);
                        try {
                          await _saveProfile(
                            name: nameCtrl.text, username: userCtrl.text,
                            bio: bioCtrl.text, insta: instaCtrl.text,
                            youtube: ytCtrl.text, theme: selectedTheme.value,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          setSheet(() => saving = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: _accentColor, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: NGColors.textPrimary, strokeWidth: 2)) : const Text('Save Changes', style: TextStyle(color: NGColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
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
  
  Widget _themeOption(StateSetter setSheet, ValueNotifier<String> selectedTheme, String value, String label, Color color) {
    return GestureDetector(
      onTap: () {
        selectedTheme.value = value;
        setSheet(() {});
      },
      child: Column(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color, shape: BoxShape.circle,
              border: selectedTheme.value == value ? Border.all(color: NGColors.textPrimary, width: 3) : null,
            ),
            child: selectedTheme.value == value ? const Icon(Icons.check, color: NGColors.textPrimary, size: 18) : null,
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: selectedTheme.value == value ? color : NGColors.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // UI HELPERS
  // ─────────────────────────────────────────────────────────────────────────
  
  void _showUploadSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: NGColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: NGColors.divider, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Upload Video', style: TextStyle(color: NGColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ListTile(
            leading: const CircleAvatar(backgroundColor: NGColors.surfaceLight, child: Icon(Icons.public_rounded, color: NGColors.success)),
            title: const Text('Public Video', style: TextStyle(color: NGColors.textPrimary, fontWeight: FontWeight.w600)),
            subtitle: const Text('Visible to everyone', style: TextStyle(color: NGColors.textMuted, fontSize: 12)),
            onTap: () { Navigator.pop(ctx); _pickAndUploadVideo(false); },
          ),
          ListTile(
            leading: const CircleAvatar(backgroundColor: NGColors.surfaceLight, child: Icon(Icons.lock_outline_rounded, color: NGColors.accent)),
            title: const Text('Private Video', style: TextStyle(color: NGColors.textPrimary, fontWeight: FontWeight.w600)),
            subtitle: const Text('Only visible to you', style: TextStyle(color: NGColors.textMuted, fontSize: 12)),
            onTap: () { Navigator.pop(ctx); _pickAndUploadVideo(true); },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
  
  void _showSettingsSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: NGColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: NGColors.divider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Privacy Settings', style: TextStyle(color: NGColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Allow Duet', style: TextStyle(color: NGColors.textPrimary)),
              subtitle: const Text('Others can duet with your videos', style: TextStyle(color: NGColors.textMuted, fontSize: 12)),
              value: _allowDuet, activeColor: _accentColor,
              onChanged: (val) async { setSheet(() => _allowDuet = val); await FirebaseFirestore.instance.collection('users').doc(_currentUid).update({'allowDuet': val}); },
            ),
            SwitchListTile(
              title: const Text('Allow Stitch', style: TextStyle(color: NGColors.textPrimary)),
              subtitle: const Text('Others can stitch your videos', style: TextStyle(color: NGColors.textMuted, fontSize: 12)),
              value: _allowStitch, activeColor: _accentColor,
              onChanged: (val) async { setSheet(() => _allowStitch = val); await FirebaseFirestore.instance.collection('users').doc(_currentUid).update({'allowStitch': val}); },
            ),
            SwitchListTile(
              title: const Text('Allow Download', style: TextStyle(color: NGColors.textPrimary)),
              subtitle: const Text('Others can download your videos', style: TextStyle(color: NGColors.textMuted, fontSize: 12)),
              value: _allowDownload, activeColor: _accentColor,
              onChanged: (val) async { setSheet(() => _allowDownload = val); await FirebaseFirestore.instance.collection('users').doc(_currentUid).update({'allowDownload': val}); },
            ),
            const SizedBox(height: 24),
          ],
        );
      }),
    );
  }
  
  void _showVideoOptions(Map<String, dynamic> video) {
    showModalBottomSheet(
      context: context,
      backgroundColor: NGColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: NGColors.divider, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.push_pin, color: NGColors.accentGold),
            title: Text(video['isPinned'] == true ? 'Unpin from Profile' : 'Pin to Profile', style: const TextStyle(color: NGColors.textPrimary)),
            onTap: () { Navigator.pop(ctx); _togglePinVideo(video['videoId'], video['isPinned'] == true); },
          ),
          ListTile(
            leading: const Icon(Icons.share, color: NGColors.textPrimary),
            title: const Text('Share Video', style: TextStyle(color: NGColors.textPrimary)),
            onTap: () { Navigator.pop(ctx); Share.share('Watch this video on NigerGram!\nhttps://nigergram.app/video/${video['videoId']}'); },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: NGColors.error),
            title: const Text('Delete Video', style: TextStyle(color: NGColors.error)),
            onTap: () { Navigator.pop(ctx); _deleteVideo(video['videoId']); },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
  
  void _showAnalytics() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: NGColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: NGColors.divider, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(children: [Icon(Icons.analytics_rounded, color: _accentColor, size: 22), const SizedBox(width: 8), const Text('Profile Analytics', style: TextStyle(color: NGColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold))]),
            const SizedBox(height: 24),
            _analyticsRow('Total Videos', '${_userData?['videoCount'] ?? 0}'),
            _analyticsRow('Total Views', '${_userData?['totalViews'] ?? 0}'),
            _analyticsRow('Followers', '${_userData?['followers'] ?? 0}'),
            _analyticsRow('Following', '${_userData?['following'] ?? 0}'),
            _analyticsRow('Total Likes', '${_userData?['likes'] ?? 0}'),
            _analyticsRow('Wallet Balance', '$_walletCurrency ${_formatBalance(_walletBalance)}'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
  
  Widget _analyticsRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: NGColors.textSecondary, fontSize: 14)),
      Text(value, style: const TextStyle(color: NGColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
    ]),
  );
  
  InputDecoration _inputDeco(String hint) => InputDecoration(
    labelText: hint, labelStyle: const TextStyle(color: NGColors.textMuted),
    filled: true, fillColor: NGColors.surfaceLight,
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NGColors.divider)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _accentColor)),
  );
  
  void _showSnack(String msg, {required bool isSuccess}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: NGColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
      backgroundColor: isSuccess ? NGColors.success : NGColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      duration: const Duration(seconds: 3),
    ));
  }
  
  String _formatBalance(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // SOCIAL LINKS - FIXED
  // ─────────────────────────────────────────────────────────────────────────
  
  Future<void> _openSocialLink(String url) async {
    if (url.trim().isEmpty) return;
    
    final String formattedUrl = _formatSocialLink(url);
    
    try {
      final uri = Uri.parse(formattedUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          _showSnack('Cannot open link: $url', isSuccess: false);
        }
      }
    } catch (e) {
      debugPrint('Error opening social link: $e');
      if (mounted) {
        _showSnack('Invalid link format', isSuccess: false);
      }
    }
  }
  
  String _formatSocialLink(String url) {
    String trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('@')) {
      trimmed = trimmed.substring(1);
    }
    if (RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(trimmed)) {
      return 'https://instagram.com/$trimmed';
    }
    return 'https://$trimmed';
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // MAIN BUILD - UPDATED with Highlights & Bio Links
  // ─────────────────────────────────────────────────────────────────────────
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: NGColors.background, body: Center(child: CircularProgressIndicator(color: NGColors.accent)));
    }
    
    if (_hasError) {
      return Scaffold(
        backgroundColor: NGColors.background,
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.wifi_off_rounded, color: NGColors.textMuted, size: 64),
          const SizedBox(height: 16),
          const Text('Failed to load profile', style: TextStyle(color: NGColors.textSecondary, fontSize: 15)),
          const SizedBox(height: 24),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _accentColor), onPressed: _loadAll, child: const Text('Retry', style: TextStyle(color: NGColors.textPrimary))),
        ])),
      );
    }
    
    if (_isBlocked && !_isCurrentUser) {
      return Scaffold(
        backgroundColor: NGColors.background,
        appBar: AppBar(backgroundColor: NGColors.background, title: const Text('Profile Unavailable', style: TextStyle(color: NGColors.textPrimary))),
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.block, color: NGColors.textMuted, size: 64),
          const SizedBox(height: 16),
          const Text('You have blocked this user', style: TextStyle(color: NGColors.textSecondary, fontSize: 15)),
          const SizedBox(height: 24),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _accentColor), onPressed: _toggleBlock, child: const Text('Unblock', style: TextStyle(color: NGColors.textPrimary))),
        ])),
      );
    }
    
    return Scaffold(
      backgroundColor: NGColors.background,
      body: Stack(
        children: [
          RefreshIndicator(
            color: _accentColor, backgroundColor: NGColors.surface, onRefresh: _loadAll,
            child: NestedScrollView(
              controller: _scrollController,
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    expandedHeight: 200, backgroundColor: NGColors.background, pinned: true,
                    actions: [
                      if (_isCurrentUser) ...[
                        IconButton(icon: Icon(Icons.account_balance_wallet_outlined, color: _accentColor), tooltip: '$_walletCurrency ${_formatBalance(_walletBalance)}', onPressed: () => context.push('/wallet')),
                      ],
                      if (_isCurrentUser) IconButton(icon: const Icon(Icons.settings, color: NGColors.textSecondary), onPressed: _showSettingsSheet),
                      if (_isCurrentUser) IconButton(icon: Icon(Icons.analytics_outlined, color: _accentColor), onPressed: _showAnalytics),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: NGColors.textPrimary), color: NGColors.surface,
                        onSelected: (val) {
                          if (val == 'share') Share.share('Check out ${_userData?['displayName'] ?? 'this profile'} on NigerGram!\nhttps://nigergram.app/profile/$_targetUserId');
                          if (val == 'block') _toggleBlock();
                          if (val == 'report') _reportProfile();
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'share', child: Row(children: [Icon(Icons.share, color: NGColors.textPrimary, size: 18), SizedBox(width: 8), Text('Share Profile', style: TextStyle(color: NGColors.textPrimary))])),
                          if (!_isCurrentUser) ...[
                            PopupMenuItem(value: 'block', child: Row(children: [Icon(Icons.block, color: NGColors.error, size: 18), SizedBox(width: 8), Text(_isBlocked ? 'Unblock' : 'Block', style: TextStyle(color: NGColors.error))])),
                            const PopupMenuItem(value: 'report', child: Row(children: [Icon(Icons.flag, color: NGColors.warning, size: 18), SizedBox(width: 8), Text('Report', style: TextStyle(color: NGColors.warning))])),
                          ],
                        ],
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: GestureDetector(
                        onTap: _updateCover,
                        child: Stack(fit: StackFit.expand, children: [
                          _userData?['coverUrl'] != null && _userData!['coverUrl'].toString().isNotEmpty
                              ? CachedNetworkImage(imageUrl: _userData!['coverUrl'], fit: BoxFit.cover, placeholder: (_, __) => Container(color: NGColors.surface), errorWidget: (_, __, ___) => Container(color: NGColors.surface))
                              : Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [_accentColor.withOpacity(0.3), NGColors.surface], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
                          Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.black54, Colors.transparent, NGColors.background], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
                          if (_isCurrentUser) Positioned(bottom: 8, right: 8, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.camera_alt_rounded, color: NGColors.textPrimary, size: 16))),
                        ]),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          GestureDetector(
                            onTap: _hasActiveStory ? () => context.push('/stories/$_targetUserId') : _updateAvatar,
                            child: AnimatedBuilder(
                              animation: Listenable.merge([_storyPulseController, _storyRotateController]),
                              builder: (context, child) => Transform.scale(
                                scale: _hasActiveStory ? _storyPulseAnimation.value : 1.0,
                                child: CustomPaint(
                                  painter: _hasActiveStory ? _StoryRingPainter(colors: [_accentColor, NGColors.accentGold, NGColors.accentPurple], rotation: _storyRotateAnimation.value) : null,
                                  child: Padding(padding: EdgeInsets.all(_hasActiveStory ? 4.0 : 0), child: child),
                                ),
                              ),
                              child: Stack(children: [
                                CircleAvatar(radius: 46, backgroundColor: NGColors.background, child: CircleAvatar(radius: 43, backgroundColor: NGColors.surfaceLight, backgroundImage: _userData?['profilePicUrl'] != null && _userData!['profilePicUrl'].toString().isNotEmpty ? CachedNetworkImageProvider(_userData!['profilePicUrl']) : null, child: _userData?['profilePicUrl'] == null || _userData!['profilePicUrl'].toString().isEmpty ? const Icon(Icons.person_outline, size: 36, color: NGColors.textMuted) : null)),
                                if (_isCurrentUser) Positioned(bottom: 0, right: 0, child: CircleAvatar(radius: 14, backgroundColor: _accentColor, child: const Icon(Icons.camera_alt, color: NGColors.textPrimary, size: 14))),
                              ]),
                            ),
                          ),
                          const Spacer(),
                          if (_isCurrentUser)
                            OutlinedButton(onPressed: _showEditSheet, style: OutlinedButton.styleFrom(side: const BorderSide(color: NGColors.divider), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)), child: const Text('Edit Profile', style: TextStyle(color: NGColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)))
                          else
                            ElevatedButton(onPressed: _toggleFollow, style: ElevatedButton.styleFrom(backgroundColor: _isFollowing ? NGColors.surfaceLight : _accentColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)), child: _isFollowLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: NGColors.textPrimary, strokeWidth: 2)) : Text(_isFollowing ? 'Following' : 'Follow', style: const TextStyle(color: NGColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold))),
                        ]),
                        const SizedBox(height: 16),
                        Row(children: [
                          Flexible(child: Text(_userData?['displayName'] ?? 'NigerGram Creator', style: const TextStyle(color: NGColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                          if (_userData?['isVerified'] == true) ...[const SizedBox(width: 6), const Icon(Icons.verified_rounded, color: NGColors.accentBlue, size: 18)],
                        ]),
                        const SizedBox(height: 4),
                        Text('@${_userData?['username'] ?? 'user'}', style: TextStyle(color: _accentColor, fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 12),
                        if (_userData?['bio'] != null && _userData!['bio'].toString().isNotEmpty) Text(_userData!['bio'], style: const TextStyle(color: NGColors.textSecondary, fontSize: 13, height: 1.4)),
                        
                        // NEW: Story Highlights
                        if (_storyHighlights.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 70,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _storyHighlights.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, idx) {
                                final highlight = _storyHighlights[idx];
                                return GestureDetector(
                                  onTap: () {
                                    // Show story highlight
                                    // You can navigate to a story viewer
                                  },
                                  onLongPress: _isCurrentUser ? () {
                                    _removeStoryHighlight(highlight['id'] ?? '');
                                  } : null,
                                  child: Column(
                                    children: [
                                      CircleAvatar(
                                        radius: 26,
                                        backgroundColor: NGColors.surfaceLight,
                                        backgroundImage: highlight['thumbnailUrl'] != null
                                            ? CachedNetworkImageProvider(highlight['thumbnailUrl'])
                                            : null,
                                        child: highlight['thumbnailUrl'] == null
                                            ? Icon(Icons.star, color: _accentColor, size: 24)
                                            : null,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        highlight['title'] ?? 'Story',
                                        style: TextStyle(
                                          color: NGColors.textSecondary,
                                          fontSize: 10,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        
                        // NEW: Bio Links
                        if (_bioLinks.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _bioLinks.map((link) {
                              return GestureDetector(
                                onTap: () async {
                                  try {
                                    final uri = Uri.parse(link['url']);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    }
                                  } catch (_) {
                                    if (mounted) _showSnack('Cannot open link', isSuccess: false);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: NGColors.surfaceLight,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        link['icon'] ?? '🔗',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        link['title'] ?? 'Link',
                                        style: TextStyle(
                                          color: NGColors.textPrimary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 8),
                        ],
                        
                        if (_userData?['instagramLink'] != null && _userData!['instagramLink'].toString().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => _openSocialLink(_userData!['instagramLink']),
                            child: const Row(
                              children: [
                                Icon(Icons.camera_alt_outlined, color: Colors.pinkAccent, size: 16),
                                SizedBox(width: 6),
                                Text('Instagram', style: TextStyle(color: Colors.pinkAccent, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                        if (_userData?['youtubeLink'] != null && _userData!['youtubeLink'].toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => _openSocialLink(_userData!['youtubeLink']),
                            child: const Row(
                              children: [
                                Icon(Icons.play_circle_outline, color: Colors.red, size: 16),
                                SizedBox(width: 6),
                                Text('YouTube', style: TextStyle(color: Colors.red, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                        if (_achievements.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(spacing: 8, runSpacing: 4, children: _achievements.map((a) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: NGColors.surfaceLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: _accentColor.withOpacity(0.3))), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(a['icon'] ?? '🏆', style: const TextStyle(fontSize: 12)), const SizedBox(width: 4), Text(a['title'] ?? '', style: const TextStyle(color: NGColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600))]))).toList()),
                        ],
                        const SizedBox(height: 16),
                        Row(children: [
                          _statNode('${_userData?['videoCount'] ?? 0}', 'Videos'), _statSpacer(),
                          _statNode('${_userData?['following'] ?? 0}', 'Following'), _statSpacer(),
                          _statNode('${_userData?['followers'] ?? 0}', 'Followers'), _statSpacer(),
                          _statNode('${_userData?['likes'] ?? 0}', 'Likes'),
                        ]),
                        const SizedBox(height: 20),
                        if (_pinnedVideos.isNotEmpty) ...[
                          Row(children: [const Icon(Icons.push_pin, color: NGColors.accentGold, size: 16), const SizedBox(width: 4), const Text('Pinned', style: TextStyle(color: NGColors.accentGold, fontSize: 13, fontWeight: FontWeight.bold))]),
                          const SizedBox(height: 8),
                          SizedBox(height: 180, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: _pinnedVideos.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (context, idx) {
                            final v = _pinnedVideos[idx];
                            return GestureDetector(
                              onTap: () => context.push('/video/${v['videoId']}'),
                              onLongPress: () => _isCurrentUser ? _showVideoOptions(v) : null,
                              child: Container(width: 120, decoration: BoxDecoration(color: NGColors.surfaceLight, borderRadius: BorderRadius.circular(8)), child: Column(children: [
                                Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(8)), child: v['thumbnailUrl'] != null && v['thumbnailUrl'].toString().isNotEmpty ? CachedNetworkImage(imageUrl: v['thumbnailUrl'], fit: BoxFit.cover, width: double.infinity) : const Center(child: Icon(Icons.play_circle_outline, color: NGColors.textMuted, size: 32)))),
                                Padding(padding: const EdgeInsets.all(6), child: Row(children: [const Icon(Icons.play_arrow_rounded, color: NGColors.textPrimary, size: 12), const SizedBox(width: 2), Text('${v['viewCount'] ?? 0}', style: const TextStyle(color: NGColors.textPrimary, fontSize: 10)), const Spacer(), const Icon(Icons.push_pin, color: NGColors.accentGold, size: 10)])),
                              ])),
                            );
                          })),
                          const SizedBox(height: 20),
                        ],
                      ]),
                    ),
                  ),
                  SliverOverlapAbsorber(
                    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                    sliver: SliverPersistentHeader(pinned: true, delegate: _SliverTabBarDelegate(TabBar(
                      controller: _tabController, isScrollable: true,
                      indicatorColor: _accentColor, labelColor: NGColors.textPrimary, unselectedLabelColor: NGColors.textMuted,
                      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      tabs: [
                        const Tab(text: 'Videos'), const Tab(text: 'Pinned'),
                        if (_isCurrentUser) const Tab(text: 'Private'),
                        const Tab(text: 'Q&A'),
                        if (_isCurrentUser) const Tab(text: 'Drafts'),
                        const Tab(text: 'Likes'),
                      ],
                    ))),
                  ),
                ];
              },
              body: _isTabLoading ? const Center(child: CircularProgressIndicator(color: NGColors.accent)) : TabBarView(controller: _tabController, children: [
                _buildGrid(_userVideos, 'videos'),
                _buildGrid(_pinnedVideos, 'pinned'),
                if (_isCurrentUser) _buildGrid(_privateVideos, 'private'),
                _buildQATab(),
                if (_isCurrentUser) _buildDraftsTab(),
                _buildGrid(_likedVideos, 'likes'),
              ]),
            ),
          ),
          if (_isUploadingContent) _buildUploadOverlay(),
        ],
      ),
      floatingActionButton: _isCurrentUser ? FloatingActionButton(backgroundColor: _accentColor, child: const Icon(Icons.add, color: NGColors.textPrimary, size: 28), onPressed: _showUploadSheet) : null,
    );
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // GRID BUILDER
  // ─────────────────────────────────────────────────────────────────────────
  
  Widget _buildGrid(List<Map<String, dynamic>> items, String tabName) {
    if (items.isEmpty) {
      return RefreshIndicator(color: _accentColor, onRefresh: _refreshCurrentTab, child: ListView(children: [SizedBox(height: MediaQuery.of(context).size.height * 0.5, child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(tabName == 'private' ? Icons.lock_outline : tabName == 'pinned' ? Icons.push_pin : tabName == 'likes' ? Icons.favorite_border : Icons.videocam_outlined, color: NGColors.textMuted, size: 48),
        const SizedBox(height: 12),
        Text(tabName == 'private' ? 'No private videos' : tabName == 'pinned' ? 'No pinned videos' : tabName == 'likes' ? 'No liked videos' : 'No videos yet', style: const TextStyle(color: NGColors.textSecondary, fontSize: 14)),
      ])))]));
    }
    return RefreshIndicator(color: _accentColor, onRefresh: _refreshCurrentTab, child: CustomScrollView(key: PageStorageKey(tabName), slivers: [
      SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
      SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 9 / 14, crossAxisSpacing: 1, mainAxisSpacing: 1),
        delegate: SliverChildBuilderDelegate((context, idx) {
          final item = items[idx];
          return GestureDetector(
            onTap: () => context.push('/video/${item['videoId']}'),
            onLongPress: _isCurrentUser && item['userId'] == _currentUid ? () => _showVideoOptions(item) : null,
            child: Container(color: NGColors.surface, child: Stack(fit: StackFit.expand, children: [
              item['thumbnailUrl'] != null && item['thumbnailUrl'].toString().isNotEmpty ? CachedNetworkImage(imageUrl: item['thumbnailUrl'], fit: BoxFit.cover, placeholder: (_, __) => Container(color: NGColors.surfaceLight), errorWidget: (_, __, ___) => const Center(child: Icon(Icons.play_circle_outline, color: NGColors.textMuted, size: 28))) : const Center(child: Icon(Icons.play_circle_outline, color: NGColors.textMuted, size: 28)),
              if (item['isPrivate'] == true) Positioned(top: 4, right: 4, child: Icon(Icons.lock, color: _accentColor.withOpacity(0.7), size: 12)),
              if (item['isPinned'] == true) Positioned(top: 4, left: 4, child: const Icon(Icons.push_pin, color: NGColors.accentGold, size: 12)),
              Positioned(left: 4, bottom: 4, child: Row(children: [const Icon(Icons.play_arrow_rounded, color: NGColors.textPrimary, size: 14), const SizedBox(width: 2), Text('${item['viewCount'] ?? 0}', style: const TextStyle(color: NGColors.textPrimary, fontSize: 10, fontWeight: FontWeight.bold))])),
            ])),
          );
        }, childCount: items.length),
      ),
    ]));
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // Q&A TAB
  // ─────────────────────────────────────────────────────────────────────────
  
  Widget _buildQATab() {
    if (_qaItems.isEmpty) {
      return RefreshIndicator(color: _accentColor, onRefresh: _refreshCurrentTab, child: ListView(children: [SizedBox(height: MediaQuery.of(context).size.height * 0.5, child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.question_answer_outlined, color: NGColors.textMuted, size: 48),
        const SizedBox(height: 12),
        const Text('No questions yet', style: TextStyle(color: NGColors.textSecondary, fontSize: 14)),
        if (!_isCurrentUser) ...[const SizedBox(height: 16), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _accentColor), onPressed: _askQuestion, child: const Text('Ask a Question', style: TextStyle(color: NGColors.textPrimary)))],
      ])))]));
    }
    return RefreshIndicator(color: _accentColor, onRefresh: _refreshCurrentTab, child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: _qaItems.length + (_isCurrentUser ? 0 : 1), itemBuilder: (context, idx) {
      if (!_isCurrentUser && idx == 0) {
        return Padding(padding: const EdgeInsets.only(bottom: 16), child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: _accentColor), onPressed: _askQuestion, icon: const Icon(Icons.help_outline, color: NGColors.textPrimary), label: const Text('Ask a Question', style: TextStyle(color: NGColors.textPrimary))));
      }
      final item = _qaItems[_isCurrentUser ? idx : idx - 1];
      return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: NGColors.surfaceLight, borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item['question'] ?? '', style: const TextStyle(color: NGColors.textPrimary, fontWeight: FontWeight.w600)),
        if (item['answer'] != null) ...[const SizedBox(height: 8), const Divider(color: NGColors.divider), const SizedBox(height: 8), Text(item['answer'], style: const TextStyle(color: NGColors.textSecondary))],
      ]));
    }));
  }
  
  Future<void> _askQuestion() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(backgroundColor: NGColors.surface, title: const Text('Ask a Question', style: TextStyle(color: NGColors.textPrimary)), content: TextField(controller: controller, style: const TextStyle(color: NGColors.textPrimary), decoration: _inputDeco('Your question...'), maxLines: 3), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: NGColors.textMuted))), TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text('Send', style: TextStyle(color: _accentColor)))]));
    if (result != null && result.trim().isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(_targetUserId).collection('qa').add({'question': result.trim(), 'askedBy': _currentUid, 'timestamp': FieldValue.serverTimestamp(), 'answer': null});
      await _loadQAItems();
      if (mounted) _showSnack('Question sent!', isSuccess: true);
    }
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // DRAFTS TAB
  // ─────────────────────────────────────────────────────────────────────────
  
  Widget _buildDraftsTab() {
    if (_draftVideos.isEmpty) {
      return RefreshIndicator(color: _accentColor, onRefresh: _refreshCurrentTab, child: ListView(children: [SizedBox(height: MediaQuery.of(context).size.height * 0.5, child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.drafts_outlined, color: NGColors.textMuted, size: 48), SizedBox(height: 12), Text('No drafts', style: TextStyle(color: NGColors.textSecondary, fontSize: 14)), SizedBox(height: 4), Text('Unfinished uploads will appear here', style: TextStyle(color: NGColors.textMuted, fontSize: 12))])))]));
    }
    return RefreshIndicator(color: _accentColor, onRefresh: _refreshCurrentTab, child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: _draftVideos.length, itemBuilder: (context, idx) {
      final draft = _draftVideos[idx];
      return ListTile(leading: const Icon(Icons.videocam, color: NGColors.textSecondary), title: Text(draft['title'] ?? 'Untitled Draft', style: const TextStyle(color: NGColors.textPrimary)), subtitle: Text('${draft['progress'] ?? 0}% uploaded', style: const TextStyle(color: NGColors.textMuted)), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.upload, color: NGColors.success), onPressed: () {}), IconButton(icon: const Icon(Icons.delete_outline, color: NGColors.error), onPressed: () {})]));
    }));
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // UPLOAD OVERLAY
  // ─────────────────────────────────────────────────────────────────────────
  
  Widget _buildUploadOverlay() {
    return Container(color: Colors.black.withOpacity(0.85), child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(value: _uploadProgress, color: _accentColor, strokeWidth: 4),
      const SizedBox(height: 24),
      Text(_uploadLabel, style: const TextStyle(color: NGColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: _uploadProgress, color: _accentColor, backgroundColor: NGColors.divider, minHeight: 6)),
      const SizedBox(height: 8),
      Text('${(_uploadProgress * 100).toInt()}%', style: const TextStyle(color: NGColors.textSecondary, fontSize: 12)),
    ]))));
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // STAT HELPERS
  // ─────────────────────────────────────────────────────────────────────────
  
  Widget _statNode(String val, String title) => Row(children: [Text(val, style: const TextStyle(color: NGColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)), const SizedBox(width: 4), Text(title, style: const TextStyle(color: NGColors.textSecondary, fontSize: 13))]);
  Widget _statSpacer() => const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('|', style: TextStyle(color: NGColors.divider)));
}

// ─────────────────────────────────────────────────────────────────────────────
// STORY RING PAINTER
// ─────────────────────────────────────────────────────────────────────────────

class _StoryRingPainter extends CustomPainter {
  final List<Color> colors;
  final double rotation;
  _StoryRingPainter({required this.colors, required this.rotation});
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final gradient = SweepGradient(startAngle: rotation, endAngle: rotation + 2 * math.pi, colors: colors);
    final paint = Paint()..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius))..style = PaintingStyle.stroke..strokeWidth = 3.0;
    canvas.drawCircle(center, radius - 1.5, paint);
  }
  
  @override
  bool shouldRepaint(covariant _StoryRingPainter oldDelegate) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB BAR DELEGATE
// ─────────────────────────────────────────────────────────────────────────────

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _SliverTabBarDelegate(this.tabBar);
  @override double get minExtent => tabBar.preferredSize.height;
  @override double get maxExtent => tabBar.preferredSize.height;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: NGColors.background, child: tabBar);
  @override bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
