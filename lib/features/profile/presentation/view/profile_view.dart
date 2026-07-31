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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/app_auth.dart';

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
    return widget.userId ?? AppAuth.uid;
  }
  
  String get _currentUid {
    return AppAuth.uid;
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
