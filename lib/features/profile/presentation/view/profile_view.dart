// lib/features/profile/presentation/view/profile_view.dart
//
// ╔══════════════════════════════════════════════════════════╗
// ║  NIGERGRAM PROFILE — THE ULTIMATE SOCIAL PROFILE      ║
// ║  Better Than TikTok • Better Than Douyin              ║
// ║  Built For Nigeria • Ready For The World             ║
// ╚══════════════════════════════════════════════════════════╝

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
import 'package:nigergram/core/design_system/colors.dart';

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
  
  // Bio Links
  List<Map<String, dynamic>> _bioLinks = [];
  
  // Online status
  bool _isOnline = false;
  
  // Mutual followers count
  int _mutualFollowers = 0;
  
  // 🔥 NEW: Last Active
  String _lastActiveText = '';
  
  // 🔥 NEW: Featured Video
  Map<String, dynamic>? _featuredVideo;
  
  // 🔥 NEW: Block List (count)
  int _blockedCount = 0;
  
  // 🔥 NEW: Profile Views History
  List<Map<String, dynamic>> _profileViewers = [];
  
  // 🔥 NEW: Dark/Light Theme
  bool _isDarkMode = true;
  
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
  
  String get _targetUserId {
    final user = FirebaseAuth.instance.currentUser;
    return widget.userId ?? user?.uid ?? '';
  }
  
  String get _currentUid {
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }
  
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
    _tabController.removeListener(_onTabChanged);
    _storyPulseController.dispose();
    _storyRotateController.dispose();
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
      case 'gold': _accentColor = NGColors.themeGold; break;
      case 'blue': _accentColor = NGColors.themeBlue; break;
      case 'purple': _accentColor = NGColors.themePurple; break;
      case 'green': _accentColor = NGColors.themeGreen; break;
      default: _accentColor = NGColors.accent;
    }
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // DATA LOADING
  // ─────────────────────────────────────────────────────────────────────────
  
  Future<void> _loadAll() async {
    if (!mounted) return;
    
    if (_targetUserId.isEmpty || _currentUid.isEmpty) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
      return;
    }
    
    setState(() { _isLoading = true; _hasError = false; });
    
    try {
      await _loadUserData();
      
      if (_userData == null) {
        throw Exception("User not found");
      }
      
      // Increment profile views
      if (!_isCurrentUser) {
        await _incrementProfileViews();
      }
      
      if (_userData?['profileTheme'] != null) {
        _profileTheme = _userData!['profileTheme'];
        _applyTheme();
      }
      
      if (_userData != null) {
        _allowDuet = _userData?['allowDuet'] ?? true;
        _allowStitch = _userData?['allowStitch'] ?? true;
        _allowDownload = _userData?['allowDownload'] ?? true;
      }
      
      // Load bio links
      _loadBioLinks();
      
      // Check online status
      _checkOnlineStatus();
      
      // Load mutual followers
      if (!_isCurrentUser) {
        _loadMutualFollowers();
      }
      
      // Load last active
      _loadLastActive();
      
      // Load featured video
      await _loadFeaturedVideo();
      
      // Load block count
      if (_isCurrentUser) {
        await _loadBlockCount();
      }
      
      // Load profile viewers
      if (_isCurrentUser) {
        await _loadProfileViewers();
      }
      
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
      ]);
    } catch (e) {
      print('❌ Profile load error: $e');
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // NEW FEATURES: Bio Links, Online Status, Mutual Followers
  // ─────────────────────────────────────────────────────────────────────────
  
  void _loadBioLinks() {
    final links = _userData?['bioLinks'] as List<dynamic>? ?? [];
    setState(() {
      _bioLinks = links.map((link) => {
        'url': link['url'] ?? '',
        'title': link['title'] ?? 'Link',
        'icon': link['icon'] ?? '🔗',
      }).toList();
    });
  }
  
  Future<void> _checkOnlineStatus() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_targetUserId)
          .get();
      final lastActive = doc.data()?['lastActive'] as Timestamp?;
      if (lastActive != null) {
        final diff = DateTime.now().difference(lastActive.toDate());
        setState(() {
          _isOnline = diff.inMinutes < 5;
        });
      }
    } catch (_) {
      _isOnline = false;
    }
  }
  
  Future<void> _loadMutualFollowers() async {
    try {
      final followingSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .collection('following')
          .get();
      
      final followingIds = followingSnapshot.docs.map((doc) => doc.id).toList();
      
      final followersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_targetUserId)
          .collection('followers')
          .get();
      
      final followerIds = followersSnapshot.docs.map((doc) => doc.id).toList();
      
      final mutual = followingIds.where((id) => followerIds.contains(id)).toList();
      
      setState(() {
        _mutualFollowers = mutual.length;
      });
    } catch (_) {
      _mutualFollowers = 0;
    }
  }
  
  Future<void> _incrementProfileViews() async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_targetUserId)
          .update({
            'profileViews': FieldValue.increment(1),
          });
    } catch (_) {}
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // LAST ACTIVE
  // ─────────────────────────────────────────────────────────────────────────
  
  void _loadLastActive() {
    final lastActive = _userData?['lastActive'] as Timestamp?;
    if (lastActive != null) {
      final diff = DateTime.now().difference(lastActive.toDate());
      if (diff.inDays > 0) {
        _lastActiveText = 'Active ${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        _lastActiveText = 'Active ${diff.inHours}h ago';
      } else if (diff.inMinutes > 0) {
        _lastActiveText = 'Active ${diff.inMinutes}m ago';
      } else {
        _lastActiveText = 'Active now';
      }
    } else {
      _lastActiveText = 'Last seen recently';
    }
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // FEATURED VIDEO
  // ─────────────────────────────────────────────────────────────────────────
  
  Future<void> _loadFeaturedVideo() async {
    if (_targetUserId.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('videos')
          .where('userId', isEqualTo: _targetUserId)
          .where('isFeatured', isEqualTo: true)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        setState(() {
          _featuredVideo = snap.docs.first.data();
        });
      }
    } catch (_) {}
  }
  
  Future<void> _setFeaturedVideo(String videoId) async {
    if (_currentUid.isEmpty) return;
    try {
      // Clear previous featured
      final oldFeatured = await FirebaseFirestore.instance
          .collection('videos')
          .where('userId', isEqualTo: _currentUid)
          .where('isFeatured', isEqualTo: true)
          .get();
      for (var doc in oldFeatured.docs) {
        await doc.reference.update({'isFeatured': false});
      }
      // Set new featured
      await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .update({'isFeatured': true});
      await _loadFeaturedVideo();
      if (mounted) _showSnack('Featured video updated!', isSuccess: true);
    } catch (e) {
      if (mounted) _showSnack('Failed to set featured video', isSuccess: false);
    }
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // BLOCK LIST
  // ─────────────────────────────────────────────────────────────────────────
  
  Future<void> _loadBlockCount() async {
    if (_currentUid.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .collection('blocked')
          .count()
          .get();
      setState(() {
        _blockedCount = snap.count ?? 0;
      });
    } catch (_) {}
  }
  
  void _showBlockedUsers() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: NGColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: NGColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Blocked Users',
              style: TextStyle(
                color: NGColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(_currentUid)
                    .collection('blocked')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: NGColors.accent),
                    );
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.block, color: NGColors.textMuted, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'No blocked users',
                            style: TextStyle(
                              color: NGColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(docs[index].id)
                            .get(),
                        builder: (context, userSnap) {
                          if (!userSnap.hasData) return const SizedBox.shrink();
                          final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                          final displayName = userData['displayName'] ?? 'Unknown';
                          final profilePic = userData['profilePicUrl'] ?? '';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: profilePic.isNotEmpty
                                  ? CachedNetworkImageProvider(profilePic)
                                  : null,
                              child: profilePic.isEmpty
                                  ? Icon(Icons.person, color: NGColors.textMuted)
                                  : null,
                            ),
                            title: Text(
                              displayName,
                              style: const TextStyle(color: NGColors.textPrimary),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.block_flipped, color: NGColors.error),
                              onPressed: () async {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(_currentUid)
                                    .collection('blocked')
                                    .doc(docs[index].id)
                                    .delete();
                                _loadBlockCount();
                                if (mounted) {
                                  _showSnack('User unblocked', isSuccess: true);
                                }
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // PROFILE VIEWERS HISTORY
  // ─────────────────────────────────────────────────────────────────────────
  
  Future<void> _loadProfileViewers() async {
    if (_currentUid.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .collection('profile_views')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();
      
      final viewers = <Map<String, dynamic>>[];
      for (var doc in snap.docs) {
        final data = doc.data();
        final viewerId = data['viewerId'] ?? '';
        if (viewerId.isNotEmpty) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(viewerId)
              .get();
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            viewers.add({
              'displayName': userData['displayName'] ?? 'Unknown',
              'profilePic': userData['profilePicUrl'] ?? '',
              'username': userData['username'] ?? '',
              'timestamp': data['timestamp'],
            });
          }
        }
      }
      setState(() {
        _profileViewers = viewers;
      });
    } catch (_) {}
  }
  
  void _showProfileViewers() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: NGColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: NGColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Profile Views',
              style: TextStyle(
                color: NGColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_profileViewers.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.visibility_off, color: NGColors.textMuted, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'No profile views yet',
                        style: TextStyle(
                          color: NGColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _profileViewers.length,
                  itemBuilder: (context, index) {
                    final viewer = _profileViewers[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: viewer['profilePic'].isNotEmpty
                            ? CachedNetworkImageProvider(viewer['profilePic'])
                            : null,
                        child: viewer['profilePic'].isEmpty
                            ? Icon(Icons.person, color: NGColors.textMuted)
                            : null,
                      ),
                      title: Text(
                        viewer['displayName'] ?? 'Unknown',
                        style: const TextStyle(color: NGColors.textPrimary),
                      ),
                      subtitle: Text(
                        '@${viewer['username'] ?? ''}',
                        style: TextStyle(color: NGColors.textMuted, fontSize: 12),
                      ),
                      trailing: Text(
                        _formatTime(viewer['timestamp'] as Timestamp?),
                        style: TextStyle(color: NGColors.textMuted, fontSize: 11),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // DARK/LIGHT THEME TOGGLE
  // ─────────────────────────────────────────────────────────────────────────
  
  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    // Save preference
    if (mounted) {
      _showSnack(
        _isDarkMode ? '🌙 Dark mode enabled' : '☀️ Light mode enabled',
        isSuccess: true,
      );
    }
  }
  
  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final date = timestamp.toDate();
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // EXISTING DATA LOADING METHODS
  // ─────────────────────────────────────────────────────────────────────────
  
  Future<void> _refreshCurrentTab() async {
    setState(() => _isTabLoading = true);
    try {
      final currentIndex = _tabController.index;
      final maxTabs = _isCurrentUser ? 6 : 5;
      
      if (currentIndex >= maxTabs) {
        setState(() => _isTabLoading = false);
        return;
      }
      
      switch (currentIndex) {
        case 0:
          await _loadPublicVideos();
          break;
        case 1:
          await _loadPinnedVideos();
          break;
        case 2:
          if (_isCurrentUser) {
            await _loadPrivateVideos();
          } else {
            await _loadBookmarkedVideos();
          }
          break;
        case 3:
          if (_isCurrentUser) {
            await _loadQAItems();
          } else {
            await _loadLikedVideos();
          }
          break;
        case 4:
          if (_isCurrentUser) {
            await _loadDrafts();
          } else {
            await _loadBookmarkedVideos();
          }
          break;
        case 5:
          if (_isCurrentUser) {
            await _loadLikedVideos();
          } else {
            return;
          }
          break;
      }
    } finally {
      if (mounted) setState(() => _isTabLoading = false);
    }
  }
  
  Future<void> _loadUserData() async {
    if (_targetUserId.isEmpty) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(_targetUserId).get();
    if (mounted) {
      setState(() => _userData = doc.data());
    }
  }
  
  Future<void> _loadWalletBalance() async {
    if (!_isCurrentUser || _currentUid.isEmpty) return;
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
    if (_targetUserId.isEmpty) return;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(_targetUserId)
        .collection('stories')
        .where('expiresAt', isGreaterThan: DateTime.now().millisecondsSinceEpoch)
        .get();
        
    if (mounted) setState(() {
      _hasActiveStory = snap.docs.isNotEmpty;
      _storyCount = snap.docs.length;
    });
  }
  
  Future<void> _loadAchievements() async {
    if (_targetUserId.isEmpty) return;
    final snap = await FirebaseFirestore.instance
        .collection('users').doc(_targetUserId).collection('achievements').limit(10).get();
    if (mounted) setState(() => _achievements = snap.docs.map((d) => d.data()).toList());
  }
  
  Future<void> _loadPinnedVideos() async {
    if (_targetUserId.isEmpty) return;
    final snap = await FirebaseFirestore.instance
        .collection('videos').where('userId', isEqualTo: _targetUserId)
        .where('isPinned', isEqualTo: true).orderBy('timestamp', descending: true).limit(3).get();
    if (mounted) setState(() => _pinnedVideos = snap.docs.map((d) => d.data()).toList());
  }
  
  Future<void> _loadPublicVideos() async {
    if (_targetUserId.isEmpty) return;
    
    print('📹 Loading public videos for userId: $_targetUserId');
    
    try {
      final snap = await FirebaseFirestore.instance
          .collection('videos')
          .where('userId', isEqualTo: _targetUserId)
          .where('isPrivate', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .limit(_pageSize)
          .get();
      
      print('📹 Found ${snap.docs.length} public videos');
      
      _lastVideoDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
      _hasMoreVideos = snap.docs.length == _pageSize;
      
      if (mounted) {
        setState(() {
          _userVideos = snap.docs.map((d) => d.data()).toList();
        });
        print('📹 _userVideos length: ${_userVideos.length}');
      }
    } catch (e) {
      print('❌ Error loading public videos: $e');
    }
  }
  
  Future<void> _loadMorePublicVideos() async {
    if (_lastVideoDoc == null || _isLoadingMore || _targetUserId.isEmpty) return;
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
    if (_targetUserId.isEmpty) return;
    final snap = await FirebaseFirestore.instance
        .collection('videos').where('userId', isEqualTo: _targetUserId)
        .where('isPrivate', isEqualTo: true).orderBy('timestamp', descending: true).get();
    if (mounted) setState(() => _privateVideos = snap.docs.map((d) => d.data()).toList());
  }
  
  Future<void> _loadBookmarkedVideos() async {
    if (_targetUserId.isEmpty) return;
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
    if (_targetUserId.isEmpty) return;
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
    if (_targetUserId.isEmpty) return;
    final snap = await FirebaseFirestore.instance
        .collection('users').doc(_targetUserId).collection('drafts')
        .orderBy('timestamp', descending: true).get();
    if (mounted) setState(() => _draftVideos = snap.docs.map((d) => d.data()).toList());
  }
  
  Future<void> _loadQAItems() async {
    if (_targetUserId.isEmpty) return;
    final snap = await FirebaseFirestore.instance
        .collection('users').doc(_targetUserId).collection('qa')
        .orderBy('timestamp', descending: true).limit(50).get();
    if (mounted) setState(() => _qaItems = snap.docs.map((d) => d.data()).toList());
  }
  
  Future<void> _checkFollowStatus() async {
    if (_currentUid.isEmpty || _targetUserId.isEmpty) return;
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(_currentUid).collection('following').doc(_targetUserId).get();
    if (mounted) setState(() => _isFollowing = doc.exists);
  }
  
  Future<void> _checkBlockStatus() async {
    if (_currentUid.isEmpty || _targetUserId.isEmpty) return;
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(_currentUid).collection('blocked').doc(_targetUserId).get();
    if (mounted) setState(() => _isBlocked = doc.exists);
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // FOLLOW / UNFOLLOW
  // ─────────────────────────────────────────────────────────────────────────
  
  Future<void> _toggleFollow() async {
    if (_currentUid.isEmpty || _isFollowLoading || _targetUserId.isEmpty) return;
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
      print('Follow error: $e');
    } finally {
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // BLOCK / REPORT
  // ─────────────────────────────────────────────────────────────────────────
  
  Future<void> _toggleBlock() async {
    if (_currentUid.isEmpty || _targetUserId.isEmpty) return;
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
      print('Block error: $e');
    }
  }
  
  Future<void> _reportProfile() async {
    if (_currentUid.isEmpty || _targetUserId.isEmpty) return;
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
    
    final XFile? videoFile = await _picker.pickVideo(
      source: ImageSource.gallery, 
      maxDuration: const Duration(minutes: 3),
    );
    if (videoFile == null) return;
    
    final File file = File(videoFile.path);
    final int fileSize = await file.length();
    
    const int maxSizeBytes = 20 * 1024 * 1024; // 20MB
    if (fileSize > maxSizeBytes) {
      if (mounted) _showSnack('Video too large (${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB). Max 20MB.', isSuccess: false);
      return;
    }
    
    setState(() { 
      _isUploadingContent = true; 
      _uploadProgress = 0.05; 
      _uploadLabel = 'Preparing upload...'; 
    });
    
    try {
      final String videoId = FirebaseFirestore.instance.collection('videos').doc().id;
      final String cleanVideoId = videoId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      final String storagePath = 'videos/${_currentUid}_${cleanVideoId}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      
      setState(() { 
        _uploadLabel = 'Uploading to Supabase...'; 
        _uploadProgress = 0.1; 
      });
      
      final bytes = await file.readAsBytes();
      
      await _supabase.storage.from('videos').uploadBinary(
        storagePath, 
        bytes,
        fileOptions: const FileOptions(
          contentType: 'video/mp4', 
          upsert: false,
        ),
      );
      
      setState(() { 
        _uploadProgress = 0.85; 
        _uploadLabel = 'Generating CDN URL...'; 
      });
      
      final String videoUrl = _supabase.storage.from('videos').getPublicUrl(storagePath);
      
      setState(() { 
        _uploadProgress = 0.92; 
        _uploadLabel = 'Saving to database...'; 
      });
      
      await FirebaseFirestore.instance.collection('videos').doc(videoId).set({
        'videoId': videoId, 
        'userId': _currentUid, 
        'videoUrl': videoUrl,
        'thumbnailUrl': '', 
        'isPrivate': makePrivate, 
        'isPinned': false,
        'allowDuet': _allowDuet, 
        'allowStitch': _allowStitch, 
        'allowDownload': _allowDownload,
        'likeCount': 0, 
        'commentCount': 0, 
        'shareCount': 0, 
        'viewCount': 0,
        'fileSizeBytes': fileSize, 
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      await FirebaseFirestore.instance.collection('users').doc(_currentUid).update({
        'videoCount': FieldValue.increment(1)
      });
      
      setState(() { 
        _uploadProgress = 1.0; 
        _uploadLabel = 'Upload complete!'; 
      });
      
      await Future.delayed(const Duration(milliseconds: 400));
      await _loadAll();
      
      if (mounted) {
        _showSnack(
          makePrivate ? 'Saved to private vault!' : 'Published to your profile!', 
          isSuccess: true
        );
      }
    } catch (e) {
      print('❌ Upload error: $e');
      if (mounted) {
        String errorMsg = 'Upload failed. Please try again.';
        if (e.toString().contains('Connection reset')) {
          errorMsg = 'Connection lost. Please check your internet and try again.';
        }
        _showSnack(errorMsg, isSuccess: false);
      }
    } finally {
      if (mounted) setState(() { 
        _isUploadingContent = false; 
        _uploadProgress = 0.0; 
        _uploadLabel = ''; 
      });
    }
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // DELETE & PIN VIDEO
  // ─────────────────────────────────────────────────────────────────────────
  
  Future<void> _deleteVideo(String videoId) async {
    if (_currentUid.isEmpty) return;
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
    if (_currentUid.isEmpty) return;
    await FirebaseFirestore.instance.collection('videos').doc(videoId).update({'isPinned': !currentlyPinned});
    await _loadPinnedVideos();
    if (mounted) _showSnack(currentlyPinned ? 'Removed from pinned' : 'Pinned to profile!', isSuccess: true);
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // AVATAR & COVER
  // ─────────────────────────────────────────────────────────────────────────
  
  Future<void> _updateAvatar() async {
    if (!_isCurrentUser || _currentUid.isEmpty) {
      print('❌ _updateAvatar: User not authenticated');
      return;
    }
    
    HapticFeedback.mediumImpact();

    final XFile? img = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 400,
    );
    if (img == null) {
      print('ℹ️ _updateAvatar: No image selected');
      return;
    }

    setState(() {
      _isUploadingContent = true;
      _uploadLabel = 'Uploading photo...';
      _uploadProgress = 0.3;
    });

    try {
      final file = File(img.path);
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = 'avatar_${_currentUid.substring(0, 8)}_$timestamp.jpg';
      
      print('📤 Uploading avatar: $fileName');
      print('📁 File size: ${await file.length()} bytes');
      print('🔑 Supabase session: ${_supabase.auth.currentSession != null}');
      
      final bytes = await file.readAsBytes();
      
      await _supabase.storage
          .from('images')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      print('✅ Avatar upload successful');

      final String url = _supabase.storage
          .from('images')
          .getPublicUrl(fileName);

      print('✅ Public URL: $url');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .update({'profilePicUrl': url});

      print('✅ Firestore updated');

      await _loadUserData();
      if (mounted) _showSnack('Profile photo updated!', isSuccess: true);
    } catch (e, stackTrace) {
      print('❌❌❌ AVATAR ERROR: $e');
      print('❌❌❌ STACK TRACE: $stackTrace');
      if (mounted) _showSnack('Failed: $e', isSuccess: false);
    } finally {
      if (mounted) setState(() {
        _isUploadingContent = false;
        _uploadProgress = 0.0;
        _uploadLabel = '';
      });
    }
  }

  Future<void> _updateCover() async {
    if (!_isCurrentUser || _currentUid.isEmpty) {
      print('❌ _updateCover: User not authenticated');
      return;
    }
    
    HapticFeedback.mediumImpact();

    final XFile? img = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1080,
    );
    if (img == null) {
      print('ℹ️ _updateCover: No image selected');
      return;
    }

    setState(() {
      _isUploadingContent = true;
      _uploadLabel = 'Uploading cover...';
      _uploadProgress = 0.3;
    });

    try {
      final file = File(img.path);
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = 'cover_${_currentUid.substring(0, 8)}_$timestamp.jpg';
      
      print('📤 Uploading cover: $fileName');
      print('📁 File size: ${await file.length()} bytes');
      print('🔑 Supabase session: ${_supabase.auth.currentSession != null}');
      
      final bytes = await file.readAsBytes();
      
      await _supabase.storage
          .from('images')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      print('✅ Cover upload successful');

      final String url = _supabase.storage
          .from('images')
          .getPublicUrl(fileName);

      print('✅ Public URL: $url');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .update({'coverUrl': url});

      print('✅ Firestore cover updated');

      await _loadUserData();
      if (mounted) _showSnack('Cover updated!', isSuccess: true);
    } catch (e, stackTrace) {
      print('❌❌❌ COVER ERROR: $e');
      print('❌❌❌ STACK TRACE: $stackTrace');
      if (mounted) _showSnack('Failed: $e', isSuccess: false);
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
    if (_currentUid.isEmpty) return;
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
                            _themeOption(setSheet, selectedTheme, 'gold', 'Gold', NGColors.themeGold),
                            _themeOption(setSheet, selectedTheme, 'blue', 'Blue', NGColors.themeBlue),
                            _themeOption(setSheet, selectedTheme, 'purple', 'Purple', NGColors.themePurple),
                            _themeOption(setSheet, selectedTheme, 'green', 'Green', NGColors.themeGreen),
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
              value: _allowDuet, activeColor: NGColors.accent,
              onChanged: (val) async { setSheet(() => _allowDuet = val); await FirebaseFirestore.instance.collection('users').doc(_currentUid).update({'allowDuet': val}); },
            ),
            SwitchListTile(
              title: const Text('Allow Stitch', style: TextStyle(color: NGColors.textPrimary)),
              subtitle: const Text('Others can stitch your videos', style: TextStyle(color: NGColors.textMuted, fontSize: 12)),
              value: _allowStitch, activeColor: NGColors.accent,
              onChanged: (val) async { setSheet(() => _allowStitch = val); await FirebaseFirestore.instance.collection('users').doc(_currentUid).update({'allowStitch': val}); },
            ),
            SwitchListTile(
              title: const Text('Allow Download', style: TextStyle(color: NGColors.textPrimary)),
              subtitle: const Text('Others can download your videos', style: TextStyle(color: NGColors.textMuted, fontSize: 12)),
              value: _allowDownload, activeColor: NGColors.accent,
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
            leading: const Icon(Icons.push_pin, color: NGColors.premium),
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
            _analyticsRow('Profile Views', '${_userData?['profileViews'] ?? 0}'),
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
  // SOCIAL LINKS
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
      print('Error opening social link: $e');
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
  // LOGOUT
  // ─────────────────────────────────────────────────────────────────────────
  
  Future<void> _showLogoutDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NGColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Logout?',
          style: TextStyle(
            color: NGColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(
            color: NGColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: NGColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: NGColors.error),
            ),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          context.go('/login');
        }
      } catch (e) {
        if (mounted) {
          _showSnack('Failed to logout: $e', isSuccess: false);
        }
      }
    }
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // MAIN BUILD
  // ─────────────────────────────────────────────────────────────────────────
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: NGColors.background, 
        body: Center(
          child: CircularProgressIndicator(color: NGColors.accent),
        ),
      );
    }
    
    if (_hasError) {
      return Scaffold(
        backgroundColor: NGColors.background,
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.wifi_off_rounded, color: NGColors.textMuted, size: 64),
          const SizedBox(height: 16),
          const Text('Failed to load profile', style: TextStyle(color: NGColors.textSecondary, fontSize: 15)),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: NGColors.accent),
            onPressed: _loadAll,
            child: const Text('Retry', style: TextStyle(color: NGColors.textPrimary)),
          ),
        ])),
      );
    }
    
    if (_isBlocked && !_isCurrentUser) {
      return Scaffold(
        backgroundColor: NGColors.background,
        appBar: AppBar(
          backgroundColor: NGColors.background, 
          title: const Text('Profile Unavailable', style: TextStyle(color: NGColors.textPrimary)),
        ),
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.block, color: NGColors.textMuted, size: 64),
          const SizedBox(height: 16),
          const Text('You have blocked this user', style: TextStyle(color: NGColors.textSecondary, fontSize: 15)),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: NGColors.accent),
            onPressed: _toggleBlock,
            child: const Text('Unblock', style: TextStyle(color: NGColors.textPrimary)),
          ),
        ])),
      );
    }
    
    return Scaffold(
      backgroundColor: NGColors.background,
      body: Stack(
        children: [
          RefreshIndicator(
            color: NGColors.accent,
            backgroundColor: NGColors.surface,
            onRefresh: _loadAll,
            child: NestedScrollView(
              controller: _scrollController,
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    expandedHeight: 200,
                    backgroundColor: NGColors.background,
                    pinned: true,
                    actions: [
                      if (_isCurrentUser && _currentUid.isNotEmpty) ...[
                        IconButton(
                          icon: Icon(Icons.account_balance_wallet_outlined, color: NGColors.accent),
                          tooltip: '$_walletCurrency ${_formatBalance(_walletBalance)}',
                          onPressed: () => context.push('/wallet'),
                        ),
                      ],
                      if (_isCurrentUser) IconButton(
                        icon: const Icon(Icons.settings, color: NGColors.textSecondary),
                        onPressed: _showSettingsSheet,
                      ),
                      if (_isCurrentUser) IconButton(
                        icon: Icon(Icons.analytics_outlined, color: NGColors.accent),
                        onPressed: _showAnalytics,
                      ),
                      if (_isCurrentUser)
                        IconButton(
                          icon: Icon(
                            _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                            color: NGColors.textSecondary,
                          ),
                          onPressed: _toggleTheme,
                        ),
                      if (_isCurrentUser)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: NGColors.textPrimary),
                          color: NGColors.surface,
                          onSelected: (val) {
                            if (val == 'share') {
                              Share.share('Check out ${_userData?['displayName'] ?? 'this profile'} on NigerGram!\nhttps://nigergram.app/profile/$_targetUserId');
                            } else if (val == 'block') {
                              _toggleBlock();
                            } else if (val == 'report') {
                              _reportProfile();
                            } else if (val == 'blocked') {
                              _showBlockedUsers();
                            } else if (val == 'viewers') {
                              _showProfileViewers();
                            } else if (val == 'logout') {
                              _showLogoutDialog();
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'share', child: Row(children: [Icon(Icons.share, color: NGColors.textPrimary, size: 18), SizedBox(width: 8), Text('Share Profile', style: TextStyle(color: NGColors.textPrimary))])),
                            if (!_isCurrentUser) ...[
                              PopupMenuItem(value: 'block', child: Row(children: [Icon(Icons.block, color: NGColors.error, size: 18), SizedBox(width: 8), Text(_isBlocked ? 'Unblock' : 'Block', style: TextStyle(color: NGColors.error))])),
                              const PopupMenuItem(value: 'report', child: Row(children: [Icon(Icons.flag, color: NGColors.warning, size: 18), SizedBox(width: 8), Text('Report', style: TextStyle(color: NGColors.warning))])),
                            ],
                            if (_isCurrentUser) ...[
                              const PopupMenuItem(value: 'blocked', child: Row(children: [Icon(Icons.block, color: NGColors.error, size: 18), SizedBox(width: 8), Text('Blocked Users', style: TextStyle(color: NGColors.textPrimary))])),
                              const PopupMenuItem(value: 'viewers', child: Row(children: [Icon(Icons.visibility, color: NGColors.accent, size: 18), SizedBox(width: 8), Text('Profile Views', style: TextStyle(color: NGColors.textPrimary))])),
                              const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout, color: NGColors.error, size: 18), SizedBox(width: 8), Text('Logout', style: TextStyle(color: NGColors.error))])),
                            ],
                          ],
                        ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: GestureDetector(
                        onTap: _updateCover,
                        child: Stack(fit: StackFit.expand, children: [
                          _userData?['coverUrl'] != null && _userData!['coverUrl'].toString().isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: _userData!['coverUrl'],
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(color: NGColors.surface),
                                  errorWidget: (_, __, ___) => Container(color: NGColors.surface),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [_accentColor.withOpacity(0.3), NGColors.surface],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.black54, Colors.transparent, NGColors.background],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                          if (_isCurrentUser) 
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: NGColors.textPrimary,
                                  size: 16,
                                ),
                              ),
                            ),
                        ]),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Stack(
                            children: [
                              GestureDetector(
                                onTap: _hasActiveStory ? () => context.push('/stories/$_targetUserId') : _updateAvatar,
                                child: AnimatedBuilder(
                                  animation: Listenable.merge([_storyPulseController, _storyRotateController]),
                                  builder: (context, child) => Transform.scale(
                                    scale: _hasActiveStory ? _storyPulseAnimation.value : 1.0,
                                    child: CustomPaint(
                                      painter: _hasActiveStory ? _StoryRingPainter(
                                        colors: [_accentColor, NGColors.premium, NGColors.themePurple],
                                        rotation: _storyRotateAnimation.value,
                                      ) : null,
                                      child: Padding(
                                        padding: EdgeInsets.all(_hasActiveStory ? 4.0 : 0),
                                        child: child,
                                      ),
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 46,
                                        backgroundColor: NGColors.background,
                                        child: CircleAvatar(
                                          radius: 43,
                                          backgroundColor: NGColors.surfaceLight,
                                          backgroundImage: _userData?['profilePicUrl'] != null && _userData!['profilePicUrl'].toString().isNotEmpty
                                              ? CachedNetworkImageProvider(_userData!['profilePicUrl'])
                                              : null,
                                          child: _userData?['profilePicUrl'] == null || _userData!['profilePicUrl'].toString().isEmpty
                                              ? const Icon(Icons.person_outline, size: 36, color: NGColors.textMuted)
                                              : null,
                                        ),
                                      ),
                                      if (_isCurrentUser)
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: CircleAvatar(
                                            radius: 14,
                                            backgroundColor: NGColors.accent,
                                            child: const Icon(Icons.camera_alt, color: NGColors.textPrimary, size: 14),
                                          ),
                                        ),
                                      if (!_isCurrentUser && _isOnline)
                                        Positioned(
                                          bottom: 2,
                                          right: 2,
                                          child: Container(
                                            width: 14,
                                            height: 14,
                                            decoration: BoxDecoration(
                                              color: NGColors.online,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: NGColors.background,
                                                width: 2.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          if (_isCurrentUser)
                            OutlinedButton(
                              onPressed: _showEditSheet,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: NGColors.accent),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: const Text(
                                'Edit Profile',
                                style: TextStyle(
                                  color: NGColors.accent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          else
                            Column(
                              children: [
                                ElevatedButton(
                                  onPressed: _toggleFollow,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isFollowing ? NGColors.surfaceLight : NGColors.accent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                  ),
                                  child: _isFollowLoading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            color: NGColors.textPrimary,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          _isFollowing ? 'Following' : 'Follow',
                                          style: const TextStyle(
                                            color: NGColors.textPrimary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                                if (_mutualFollowers > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      'Followed by ${_mutualFollowers} people you follow',
                                      style: TextStyle(
                                        color: NGColors.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                        ]),
                        const SizedBox(height: 16),
                        Row(children: [
                          Flexible(
                            child: Text(
                              _userData?['displayName'] ?? 'NigerGram Creator',
                              style: const TextStyle(
                                color: NGColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_userData?['isVerified'] == true) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded, color: NGColors.verified, size: 18),
                          ],
                          if (!_isCurrentUser && _lastActiveText.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                _lastActiveText,
                                style: TextStyle(
                                  color: NGColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ]),
                        const SizedBox(height: 4),
                        Text(
                          '@${_userData?['username'] ?? 'user'}',
                          style: TextStyle(
                            color: _accentColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_userData?['bio'] != null && _userData!['bio'].toString().isNotEmpty)
                          Text(
                            _userData!['bio'],
                            style: const TextStyle(
                              color: NGColors.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        if (_bioLinks.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _bioLinks.map((link) {
                              return GestureDetector(
                                onTap: () async {
                                  try {
                                    final url = link['url'] ?? '';
                                    if (url.isNotEmpty) {
                                      final uri = Uri.parse(url);
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                                      }
                                    }
                                  } catch (_) {
                                    _showSnack('Cannot open link', isSuccess: false);
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
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _achievements.map((a) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: NGColors.surfaceLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _accentColor.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(a['icon'] ?? '🏆', style: const TextStyle(fontSize: 12)),
                                  const SizedBox(width: 4),
                                  Text(
                                    a['title'] ?? '',
                                    style: const TextStyle(
                                      color: NGColors.textPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )).toList(),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(children: [
                          _statNode('${_userData?['videoCount'] ?? 0}', 'Videos'),
                          _statSpacer(),
                          _statNode('${_userData?['following'] ?? 0}', 'Following'),
                          _statSpacer(),
                          _statNode('${_userData?['followers'] ?? 0}', 'Followers'),
                          _statSpacer(),
                          _statNode('${_userData?['likes'] ?? 0}', 'Likes'),
                          _statSpacer(),
                          _statNode('${_userData?['profileViews'] ?? 0}', 'Views'),
                        ]),
                        const SizedBox(height: 20),
                        if (_featuredVideo != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: NGColors.surfaceLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: NGColors.accent.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: NGColors.surface,
                                  ),
                                  child: _featuredVideo!['thumbnailUrl'] != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: CachedNetworkImage(
                                            imageUrl: _featuredVideo!['thumbnailUrl'],
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : const Icon(Icons.play_circle_outline, size: 40, color: NGColors.textMuted),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '⭐ Featured Video',
                                        style: TextStyle(
                                          color: NGColors.accent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _featuredVideo!['description'] ?? 'Featured video',
                                        style: const TextStyle(
                                          color: NGColors.textPrimary,
                                          fontSize: 13,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_featuredVideo!['viewCount'] ?? 0} views',
                                        style: TextStyle(
                                          color: NGColors.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_isCurrentUser)
                                  IconButton(
                                    icon: const Icon(Icons.close, color: NGColors.textMuted, size: 16),
                                    onPressed: () async {
                                      await FirebaseFirestore.instance
                                          .collection('videos')
                                          .doc(_featuredVideo!['videoId'])
                                          .update({'isFeatured': false});
                                      await _loadFeaturedVideo();
                                    },
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_pinnedVideos.isNotEmpty) ...[
                          Row(children: [
                            const Icon(Icons.push_pin, color: NGColors.premium, size: 16),
                            const SizedBox(width: 4),
                            const Text(
                              'Pinned',
                              style: TextStyle(
                                color: NGColors.premium,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 180,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _pinnedVideos.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, idx) {
                                final v = _pinnedVideos[idx];
                                return GestureDetector(
                                  onTap: () => context.push('/video/${v['videoId']}'),
                                  onLongPress: () => _isCurrentUser ? _showVideoOptions(v) : null,
                                  child: Container(
                                    width: 120,
                                    decoration: BoxDecoration(
                                      color: NGColors.surfaceLight,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                          child: v['thumbnailUrl'] != null && v['thumbnailUrl'].toString().isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl: v['thumbnailUrl'],
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                )
                                              : const Center(
                                                  child: Icon(
                                                    Icons.play_circle_outline,
                                                    color: NGColors.textMuted,
                                                    size: 32,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: Row(children: [
                                          const Icon(Icons.play_arrow_rounded, color: NGColors.textPrimary, size: 12),
                                          const SizedBox(width: 2),
                                          Text(
                                            '${v['viewCount'] ?? 0}',
                                            style: const TextStyle(
                                              color: NGColors.textPrimary,
                                              fontSize: 10,
                                            ),
                                          ),
                                          const Spacer(),
                                          const Icon(Icons.push_pin, color: NGColors.premium, size: 10),
                                        ]),
                                      ),
                                    ]),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ]),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverTabBarDelegate(
                      TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        indicatorColor: _accentColor,
                        labelColor: NGColors.textPrimary,
                        unselectedLabelColor: NGColors.textMuted,
                        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        tabs: [
                          const Tab(text: 'Videos'),
                          const Tab(text: 'Pinned'),
                          if (_isCurrentUser) const Tab(text: 'Private'),
                          const Tab(text: 'Q&A'),
                          if (_isCurrentUser) const Tab(text: 'Drafts'),
                          const Tab(text: 'Likes'),
                        ],
                      ),
                    ),
                  ),
                ];
              },
              body: _isTabLoading
                  ? const Center(child: CircularProgressIndicator(color: NGColors.accent))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildGrid(_userVideos, 'videos'),
                        _buildGrid(_pinnedVideos, 'pinned'),
                        if (_isCurrentUser) _buildGrid(_privateVideos, 'private'),
                        _buildQATab(),
                        if (_isCurrentUser) _buildDraftsTab(),
                        _buildGrid(_likedVideos, 'likes'),
                      ],
                    ),
            ),
          ),
          if (_isUploadingContent) _buildUploadOverlay(),
        ],
      ),
      floatingActionButton: _isCurrentUser
          ? Padding(
              padding: const EdgeInsets.only(bottom: 80.0),
              child: FloatingActionButton(
                backgroundColor: NGColors.accent,
                child: const Icon(Icons.add, color: NGColors.textPrimary, size: 28),
                onPressed: _showUploadSheet,
              ),
            )
          : null,
    );
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // GRID BUILDER — FIXED (replaced CustomScrollView with GridView.builder)
  // ─────────────────────────────────────────────────────────────────────────
  
  Widget _buildGrid(List<Map<String, dynamic>> items, String tabName) {
    if (items.isEmpty) {
      return RefreshIndicator(
        color: NGColors.accent,
        onRefresh: _refreshCurrentTab,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tabName == 'private'
                          ? Icons.lock_outline
                          : tabName == 'pinned'
                              ? Icons.push_pin
                              : tabName == 'likes'
                                  ? Icons.favorite_border
                                  : Icons.videocam_outlined,
                      color: NGColors.textMuted,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tabName == 'private'
                          ? 'No private videos'
                          : tabName == 'pinned'
                              ? 'No pinned videos'
                              : tabName == 'likes'
                                  ? 'No liked videos'
                                  : 'No videos yet',
                      style: const TextStyle(
                        color: NGColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: NGColors.accent,
      onRefresh: _refreshCurrentTab,
      child: GridView.builder(
        key: PageStorageKey(tabName),
        padding: const EdgeInsets.all(1),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 9 / 14,
          crossAxisSpacing: 1,
          mainAxisSpacing: 1,
        ),
        itemCount: items.length,
        itemBuilder: (context, idx) {
          final item = items[idx];
          return GestureDetector(
            onTap: () => context.push('/video/${item['videoId']}'),
            onLongPress: _isCurrentUser && item['userId'] == _currentUid
                ? () => _showVideoOptions(item)
                : null,
            child: Container(
              color: NGColors.surface,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item['thumbnailUrl'] != null && item['thumbnailUrl'].toString().isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item['thumbnailUrl'],
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: NGColors.surfaceLight),
                          errorWidget: (_, __, ___) => const Center(
                            child: Icon(
                              Icons.play_circle_outline,
                              color: NGColors.textMuted,
                              size: 28,
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.play_circle_outline,
                            color: NGColors.textMuted,
                            size: 28,
                          ),
                        ),
                  if (item['isPrivate'] == true)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Icon(
                        Icons.lock,
                        color: _accentColor.withOpacity(0.7),
                        size: 12,
                      ),
                    ),
                  if (item['isPinned'] == true)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: const Icon(
                        Icons.push_pin,
                        color: NGColors.premium,
                        size: 12,
                      ),
                    ),
                  Positioned(
                    left: 4,
                    bottom: 4,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          color: NGColors.textPrimary,
                          size: 14,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${item['viewCount'] ?? 0}',
                          style: const TextStyle(
                            color: NGColors.textPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // Q&A TAB
  // ─────────────────────────────────────────────────────────────────────────
  
  Widget _buildQATab() {
    if (_qaItems.isEmpty) {
      return RefreshIndicator(
        color: NGColors.accent,
        onRefresh: _refreshCurrentTab,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.question_answer_outlined,
                      color: NGColors.textMuted,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No questions yet',
                      style: TextStyle(
                        color: NGColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    if (!_isCurrentUser) ...[
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: NGColors.accent,
                        ),
                        onPressed: _askQuestion,
                        child: const Text(
                          'Ask a Question',
                          style: TextStyle(color: NGColors.textPrimary),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: NGColors.accent,
      onRefresh: _refreshCurrentTab,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _qaItems.length + (_isCurrentUser ? 0 : 1),
        itemBuilder: (context, idx) {
          if (!_isCurrentUser && idx == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: NGColors.accent,
                ),
                onPressed: _askQuestion,
                icon: const Icon(Icons.help_outline, color: NGColors.textPrimary),
                label: const Text(
                  'Ask a Question',
                  style: TextStyle(color: NGColors.textPrimary),
                ),
              ),
            );
          }
          final item = _qaItems[_isCurrentUser ? idx : idx - 1];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NGColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['question'] ?? '',
                  style: const TextStyle(
                    color: NGColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item['answer'] != null) ...[
                  const SizedBox(height: 8),
                  const Divider(color: NGColors.divider),
                  const SizedBox(height: 8),
                  Text(
                    item['answer'],
                    style: const TextStyle(
                      color: NGColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
  
  Future<void> _askQuestion() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NGColors.surface,
        title: const Text(
          'Ask a Question',
          style: TextStyle(color: NGColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: NGColors.textPrimary),
          decoration: _inputDeco('Your question...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: NGColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(
              'Send',
              style: TextStyle(color: _accentColor),
            ),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_targetUserId)
          .collection('qa')
          .add({
            'question': result.trim(),
            'askedBy': _currentUid,
            'timestamp': FieldValue.serverTimestamp(),
            'answer': null,
          });
      await _loadQAItems();
      if (mounted) _showSnack('Question sent!', isSuccess: true);
    }
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // DRAFTS TAB
  // ─────────────────────────────────────────────────────────────────────────
  
  Widget _buildDraftsTab() {
    if (_draftVideos.isEmpty) {
      return RefreshIndicator(
        color: NGColors.accent,
        onRefresh: _refreshCurrentTab,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.drafts_outlined, color: NGColors.textMuted, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'No drafts',
                      style: TextStyle(
                        color: NGColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Unfinished uploads will appear here',
                      style: TextStyle(
                        color: NGColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: NGColors.accent,
      onRefresh: _refreshCurrentTab,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _draftVideos.length,
        itemBuilder: (context, idx) {
          final draft = _draftVideos[idx];
          return ListTile(
            leading: const Icon(Icons.videocam, color: NGColors.textSecondary),
            title: Text(
              draft['title'] ?? 'Untitled Draft',
              style: const TextStyle(color: NGColors.textPrimary),
            ),
            subtitle: Text(
              '${draft['progress'] ?? 0}% uploaded',
              style: const TextStyle(color: NGColors.textMuted),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.upload, color: NGColors.success),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: NGColors.error),
                  onPressed: () {},
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // UPLOAD OVERLAY
  // ─────────────────────────────────────────────────────────────────────────
  
  Widget _buildUploadOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                value: _uploadProgress,
                color: NGColors.accent,
                strokeWidth: 4,
              ),
              const SizedBox(height: 24),
              Text(
                _uploadLabel,
                style: const TextStyle(
                  color: NGColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _uploadProgress,
                  color: NGColors.accent,
                  backgroundColor: NGColors.divider,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(_uploadProgress * 100).toInt()}%',
                style: const TextStyle(
                  color: NGColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // STAT HELPERS
  // ─────────────────────────────────────────────────────────────────────────
  
  Widget _statNode(String val, String title) => Row(
        children: [
          Text(
            val,
            style: const TextStyle(
              color: NGColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            title,
            style: const TextStyle(
              color: NGColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      );
  
  Widget _statSpacer() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: Text('|', style: TextStyle(color: NGColors.divider)),
      );
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
    final gradient = SweepGradient(
      startAngle: rotation,
      endAngle: rotation + 2 * math.pi,
      colors: colors,
    );
    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
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
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: NGColors.background, child: tabBar);
  }
  @override bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
